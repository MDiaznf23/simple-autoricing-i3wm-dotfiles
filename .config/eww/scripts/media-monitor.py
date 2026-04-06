#!/usr/bin/env python3
"""
media-monitor.py — MPRIS2 media monitor via D-Bus langsung
- Event-driven: zero polling
- Manual player switching via Unix socket
- Auto-switch ke player yang Playing
"""

import dbus
import time
import dbus.mainloop.glib
import json
import sys
import os
import socket
import threading
from pathlib import Path
from gi.repository import GLib

# ─── Konfigurasi ──────────────────────────────────────────────────────────────

DEFAULT_COVER = str(Path.home() / ".config/eww/assets/default-cover.jpg")
MPRIS_PREFIX = "org.mpris.MediaPlayer2."
SOCKET_PATH = "/tmp/eww-media-monitor.sock"

# ─── Helpers ──────────────────────────────────────────────────────────────────


def get_cover(art_url: str, file_path: str) -> str:
    if art_url:
        clean = art_url.replace("file://", "")
        if clean and Path(clean).exists():
            return clean
    if file_path:
        clean = file_path.replace("file://", "")
        music_dir = Path(clean).parent
        for name in ["cover.jpg", "folder.jpg"]:
            p = music_dir / name
            if p.exists():
                return str(p)
        for p in music_dir.glob("*.png"):
            return str(p)
    return DEFAULT_COVER


def build_json(player: str, props: dict) -> str:
    metadata = props.get("Metadata", {})
    status = str(props.get("PlaybackStatus", "Stopped"))
    title = str(metadata.get("xesam:title", "")) or "No Title"
    artist_list = metadata.get("xesam:artist", [])
    artist = str(artist_list[0]) if artist_list else "Unknown"
    art_url = str(metadata.get("mpris:artUrl", ""))
    file_path = str(metadata.get("xesam:url", ""))
    position = int(props.get("Position", 0))
    length = int(metadata.get("mpris:length", 0))
    cover = get_cover(art_url, file_path)

    return json.dumps(
        {
            "player": player,
            "status": status,
            "title": title,
            "artist": artist,
            "cover": cover,
            "position": position,
            "length": length,
        },
        ensure_ascii=False,
    )


def no_media():
    print(
        json.dumps(
            {
                "title": "No Media",
                "artist": "Offline",
                "status": "Stopped",
                "player": "",
                "cover": "",
                "position": 0,
                "length": 0,
                "players": [],
            }
        ),
        flush=True,
    )


# ─── MPRIS2 Monitor ───────────────────────────────────────────────────────────


class MPRISMonitor:
    def __init__(self, bus: dbus.SessionBus):
        self.bus = bus
        self.players: dict[str, dict] = {}  # full_name → props
        self.active_player: str = ""
        self.manual_player: str = ""  # set saat user pilih manual

        self._scan_existing()

        bus.add_signal_receiver(
            self._on_name_owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
            bus_name="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
        )

    # ── Scan player yang sudah jalan ──────────────────────────────────────────

    def _scan_existing(self):
        try:
            dbus_obj = self.bus.get_object(
                "org.freedesktop.DBus", "/org/freedesktop/DBus"
            )
            names = dbus_obj.ListNames(dbus_interface="org.freedesktop.DBus")
            for name in names:
                if str(name).startswith(MPRIS_PREFIX):
                    self._add_player(str(name))
        except Exception as e:
            print(f"[media-monitor] Scan error: {e}", file=sys.stderr)

        if not self.players:
            no_media()

    # ── Add / remove player ───────────────────────────────────────────────────

    def _add_player(self, name: str):
        try:
            obj = self.bus.get_object(name, "/org/mpris/MediaPlayer2")
            props_iface = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            props = props_iface.GetAll("org.mpris.MediaPlayer2.Player")
            self.players[name] = dict(props)

            self.bus.add_signal_receiver(
                lambda iface, changed, inv, sender=name: self._on_properties_changed(
                    sender, iface, changed, inv
                ),
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name=name,
                path="/org/mpris/MediaPlayer2",
            )

            self.bus.add_signal_receiver(
                lambda position, sender=name: self._on_seeked(sender, position),
                signal_name="Seeked",
                dbus_interface="org.mpris.MediaPlayer2.Player",
                bus_name=name,
                path="/org/mpris/MediaPlayer2",
            )

            print(f"[media-monitor] Player masuk: {name}", file=sys.stderr, flush=True)
            self._update_active()
        except Exception as e:
            print(f"[media-monitor] Gagal add {name}: {e}", file=sys.stderr)

    def _on_seeked(self, player: str, position: int):
        """Dipanggil saat user seek — posisi loncat, harus reset timestamp."""
        if player not in self.players:
            return
        # Update posisi di cache supaya _emit pakai nilai yang benar
        self.players[player]["Position"] = position
        if player == self.active_player:
            self._emit(player)

    def _remove_player(self, name: str):
        if name in self.players:
            del self.players[name]
            print(f"[media-monitor] Player keluar: {name}", file=sys.stderr, flush=True)

            # Kalau yang dihapus adalah manual selection, reset
            if self.manual_player == name:
                self.manual_player = ""

            self._update_active()

    def _on_name_owner_changed(self, name, old_owner, new_owner):
        name = str(name)
        if not name.startswith(MPRIS_PREFIX):
            return
        if new_owner:
            self._add_player(name)
        else:
            self._remove_player(name)

    # ── Properties changed ────────────────────────────────────────────────────

    def _on_properties_changed(
        self, player: str, iface: str, changed: dict, invalidated
    ):
        if iface != "org.mpris.MediaPlayer2.Player":
            return
        if player not in self.players:
            return

        self.players[player].update(changed)

        # Kalau ada player lain mulai Playing, auto-switch
        # kecuali user sudah pilih manual
        if not self.manual_player:
            status = str(changed.get("PlaybackStatus", ""))
            if status == "Playing" and player != self.active_player:
                self.active_player = player

        if player == self.active_player:
            self._emit(player)

    # ── Update active player ──────────────────────────────────────────────────

    def _update_active(self):
        if not self.players:
            self.active_player = ""
            self.manual_player = ""
            no_media()
            return

        # Kalau manual player masih ada, pakai itu
        if self.manual_player and self.manual_player in self.players:
            self.active_player = self.manual_player
            self._emit(self.active_player)
            return

        # Reset manual karena player sudah tidak ada
        self.manual_player = ""

        # Prioritas: yang Playing
        for name, props in self.players.items():
            if str(props.get("PlaybackStatus", "")) == "Playing":
                self.active_player = name
                self._emit(name)
                return

        # Fallback: player pertama
        name = next(iter(self.players))
        self.active_player = name
        self._emit(name)

    # ── Manual switch dari socket ─────────────────────────────────────────────

    def switch_player(self, short_name: str):
        """Dipanggil dari socket thread saat user pilih player di eww."""
        full_name = MPRIS_PREFIX + short_name
        if full_name not in self.players:
            print(
                f"[media-monitor] Player tidak ditemukan: {full_name}", file=sys.stderr
            )
            return

        self.manual_player = full_name
        self.active_player = full_name
        print(
            f"[media-monitor] Manual switch → {full_name}", file=sys.stderr, flush=True
        )

        # Emit dari GLib main thread supaya thread-safe
        GLib.idle_add(self._emit, full_name)

    # ── Emit JSON ke stdout ───────────────────────────────────────────────────

    def _emit(self, name: str):
        if name not in self.players:
            return

        props = self.players[name]

        # Query posisi real-time dari D-Bus (hanya saat event, bukan polling)
        try:
            obj = self.bus.get_object(name, "/org/mpris/MediaPlayer2")
            props_iface = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            position = int(props_iface.Get("org.mpris.MediaPlayer2.Player", "Position"))
        except Exception:
            position = int(props.get("Position", 0))

        # Catat monotonic timestamp saat posisi ini diambil

        position_ts = int(time.time() * 1_000_000)

        data = json.loads(build_json(name.replace(MPRIS_PREFIX, ""), props))
        data["position"] = position
        data["position_ts"] = position_ts

        data["players"] = [
            {
                "player": n.replace(MPRIS_PREFIX, ""),
                "status": str(self.players[n].get("PlaybackStatus", "Stopped")),
            }
            for n in self.players
        ]

        print(json.dumps(data, ensure_ascii=False), flush=True)

        try:
            Path("/tmp/eww_active_player").write_text(
                name.replace(MPRIS_PREFIX, ""), encoding="utf-8"
            )
            Path("/tmp/eww_position_ts").write_text(str(position_ts), encoding="utf-8")
            Path("/tmp/eww_position_base").write_text(str(position), encoding="utf-8")
        except OSError:
            pass


# ─── Unix Socket Server ───────────────────────────────────────────────────────


def start_socket_server(monitor: MPRISMonitor):
    """
    Listen di Unix socket untuk perintah dari eww.
    Format perintah: 'switch:<player_short_name>'
    """
    if Path(SOCKET_PATH).exists():
        os.remove(SOCKET_PATH)

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)
    os.chmod(SOCKET_PATH, 0o600)

    print(f"[media-monitor] Socket aktif: {SOCKET_PATH}", file=sys.stderr, flush=True)

    def _listen():
        while True:
            try:
                conn, _ = server.accept()
                data = conn.recv(256).decode().strip()
                conn.close()

                if data.startswith("switch:"):
                    player_name = data[7:].strip()
                    monitor.switch_player(player_name)
                elif data == "reset":
                    monitor.manual_player = ""
                    GLib.idle_add(monitor._update_active)

            except Exception as e:
                print(f"[media-monitor] Socket error: {e}", file=sys.stderr)

    t = threading.Thread(target=_listen, daemon=True)
    t.start()


# ─── Entry point ──────────────────────────────────────────────────────────────


def run():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    monitor = MPRISMonitor(bus)

    start_socket_server(monitor)

    print(
        "[media-monitor] Aktif, menunggu MPRIS2 events...", file=sys.stderr, flush=True
    )

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[media-monitor] Dihentikan.", file=sys.stderr)
        if Path(SOCKET_PATH).exists():
            os.remove(SOCKET_PATH)


if __name__ == "__main__":
    run()
