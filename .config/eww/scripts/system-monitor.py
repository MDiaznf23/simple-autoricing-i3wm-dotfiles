#!/usr/bin/env python3
"""
system-monitor.py — System status monitor via D-Bus events
- Battery + WiFi: UPower + NetworkManager D-Bus signals
- Volume: PulseAudio/PipeWire D-Bus signals
- Brightness: inotify /sys/class/backlight
- Network speed: sampling via threading (bukan blocking sleep)
Zero polling untuk semua kecuali network speed sampling
"""

import ctypes
import dbus
import dbus.mainloop.glib
import json
import os
import struct
import sys
import threading
import time
from pathlib import Path
from gi.repository import GLib

# ─── Konfigurasi ──────────────────────────────────────────────────────────────

SPEED_INTERVAL = 2.0  # detik antar sample network speed

# ─── Icon helpers ─────────────────────────────────────────────────────────────


def wifi_icon(signal: int) -> str:
    if signal <= 20:
        return "󰤯 "
    if signal <= 40:
        return "󰤟 "
    if signal <= 60:
        return "󰤢 "
    if signal <= 80:
        return "󰤥 "
    return "󰤨 "


def bat_icon_charging(pct: int) -> str:
    icons = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂅"]
    return icons[min(pct // 10, 9)]


def bat_icon_discharging(pct: int) -> str:
    icons = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂"]
    return icons[min(pct // 10, 9)]


def bright_icon(pct: int) -> str:
    if pct <= 25:
        return "󰃞"
    if pct <= 50:
        return "󰃝"
    if pct <= 75:
        return "󰃟"
    return "󰃠"


def vol_icon(pct: int, muted: bool) -> str:
    if muted:
        return "󰖁"
    if pct <= 30:
        return ""
    if pct <= 70:
        return ""
    return " "


def format_speed(bps: float) -> str:
    if bps < 1024:
        return f"{int(bps)}B/s"
    if bps < 1048576:
        return f"{bps/1024:.1f}K/s"
    return f"{bps/1048576:.1f}M/s"


# ─── inotify via ctypes ───────────────────────────────────────────────────────

libc = ctypes.CDLL("libc.so.6", use_errno=True)
IN_CLOSE_WRITE = 0x00000008
IN_MODIFY = 0x00000002
_INOT_HDR = struct.Struct("iIII")
_INOT_HDR_SIZE = _INOT_HDR.size


def _inotify_init():
    fd = libc.inotify_init()
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init gagal")
    return fd


def _inotify_add_watch(fd, path: str, mask: int):
    wd = libc.inotify_add_watch(fd, path.encode(), mask)
    if wd < 0:
        raise OSError(ctypes.get_errno(), f"inotify_add_watch gagal: {path}")
    return wd


# ─── State ────────────────────────────────────────────────────────────────────


class SystemState:
    def __init__(self):
        # WiFi
        self.wifi_connected = False
        self.wifi_signal = 0
        self.wifi_interface = self._detect_wifi()
        self.rx_bytes = 0
        self.tx_bytes = 0
        self.rx_rate = 0.0
        self.tx_rate = 0.0

        # Battery
        self.bat_capacity = 0
        self.bat_charging = False

        # Brightness
        self.bright_pct = 0
        self.bright_path = self._detect_backlight()

        # Volume
        self.vol_pct = 0
        self.vol_muted = False

    def _detect_wifi(self) -> str:
        for iface in Path("/sys/class/net").iterdir():
            if (iface / "wireless").is_dir():
                return iface.name
        return ""

    def _detect_backlight(self) -> Path | None:
        for p in Path("/sys/class/backlight").iterdir():
            if (p / "brightness").exists():
                return p
        return None

    def read_brightness(self):
        if not self.bright_path:
            return
        try:
            cur = int((self.bright_path / "brightness").read_text())
            max_b = int((self.bright_path / "max_brightness").read_text())
            self.bright_pct = int(cur * 100 / max_b) if max_b > 0 else 0
        except (OSError, ValueError):
            self.bright_pct = 0

    def read_network_bytes(self) -> tuple[int, int]:
        if not self.wifi_interface:
            return 0, 0
        try:
            rx = int(
                Path(
                    f"/sys/class/net/{self.wifi_interface}/statistics/rx_bytes"
                ).read_text()
            )
            tx = int(
                Path(
                    f"/sys/class/net/{self.wifi_interface}/statistics/tx_bytes"
                ).read_text()
            )
            return rx, tx
        except (OSError, ValueError):
            return 0, 0

    def to_json(self) -> str:
        wi = wifi_icon(self.wifi_signal) if self.wifi_connected else "󰤮 "
        wi_desc = (
            f"↓{format_speed(self.rx_rate)} ↑{format_speed(self.tx_rate)}"
            if self.wifi_connected
            else "Disconnected"
        )
        bi = (
            bat_icon_charging(self.bat_capacity)
            if self.bat_charging
            else bat_icon_discharging(self.bat_capacity)
        )
        bri = bright_icon(self.bright_pct)
        vi = vol_icon(self.vol_pct, self.vol_muted)

        return json.dumps(
            {
                "wifi_icon": wi,
                "wifi_desc": wi_desc,
                "wifi_connected": self.wifi_connected,
                "bat_icon": bi,
                "bat_desc": f"{self.bat_capacity}%",
                "bat_capacity": self.bat_capacity,
                "bat_charging": self.bat_charging,
                "bright_icon": bri,
                "bright_desc": f"{self.bright_pct}%",
                "bright_pct": self.bright_pct,
                "vol_icon": vi,
                "vol_desc": f"{self.vol_pct}%",
                "vol_pct": self.vol_pct,
                "vol_muted": self.vol_muted,
            },
            ensure_ascii=False,
        )


# ─── Monitor ──────────────────────────────────────────────────────────────────


class SystemMonitor:
    def __init__(self, bus_system: dbus.SystemBus, bus_session: dbus.SessionBus):
        self.state = SystemState()
        self.system_bus = bus_system
        self.session_bus = bus_session
        self._lock = threading.Lock()

        self._setup_upower()
        self._setup_networkmanager()
        self._setup_pulseaudio()
        self._setup_brightness_inotify()
        self._setup_network_speed_thread()

        # Baca state awal
        self._init_battery()
        self._init_wifi()
        self._init_volume()
        self.state.read_brightness()
        rx, tx = self.state.read_network_bytes()
        self.state.rx_bytes = rx
        self.state.tx_bytes = tx

        self._emit()

    # ── UPower (battery) ──────────────────────────────────────────────────────

    def _setup_upower(self):
        try:
            self.system_bus.add_signal_receiver(
                self._on_upower_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name="org.freedesktop.UPower",
            )
            print("[system-monitor] UPower subscribed", file=sys.stderr, flush=True)
        except Exception as e:
            print(f"[system-monitor] UPower error: {e}", file=sys.stderr)

    def _init_battery(self):
        try:
            upower = self.system_bus.get_object(
                "org.freedesktop.UPower", "/org/freedesktop/UPower"
            )
            upower_iface = dbus.Interface(upower, "org.freedesktop.UPower")
            devices = upower_iface.EnumerateDevices()
            for dev_path in devices:
                dev = self.system_bus.get_object("org.freedesktop.UPower", dev_path)
                props = dbus.Interface(dev, "org.freedesktop.DBus.Properties")
                p = props.GetAll("org.freedesktop.UPower.Device")
                # Type 2 = battery
                if int(p.get("Type", 0)) == 2:
                    self.state.bat_capacity = int(p.get("Percentage", 0))
                    # State: 1=charging, 2=discharging, 4=fully-charged
                    state = int(p.get("State", 0))
                    self.state.bat_charging = state in (1, 4)
                    break
        except Exception as e:
            print(f"[system-monitor] Init battery error: {e}", file=sys.stderr)

    def _on_upower_changed(self, iface, changed, invalidated):
        if "Percentage" in changed or "State" in changed:
            self._init_battery()
            with self._lock:
                self._emit()

    # ── NetworkManager (wifi) ─────────────────────────────────────────────────

    def _setup_networkmanager(self):
        try:
            self.system_bus.add_signal_receiver(
                self._on_nm_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name="org.freedesktop.NetworkManager",
            )
            print(
                "[system-monitor] NetworkManager subscribed",
                file=sys.stderr,
                flush=True,
            )
        except Exception as e:
            print(f"[system-monitor] NetworkManager error: {e}", file=sys.stderr)

    def _init_wifi(self):
        try:
            nm = self.system_bus.get_object(
                "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager"
            )
            props = dbus.Interface(nm, "org.freedesktop.DBus.Properties")
            p = props.GetAll("org.freedesktop.NetworkManager")
            # State 70 = NM_STATE_CONNECTED_GLOBAL
            state = int(p.get("State", 0))
            self.state.wifi_connected = state == 70

            if self.state.wifi_connected:
                self._read_wifi_signal()
        except Exception as e:
            print(f"[system-monitor] Init wifi error: {e}", file=sys.stderr)

    def _read_wifi_signal(self):
        try:
            nm = self.system_bus.get_object(
                "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager"
            )
            props = dbus.Interface(nm, "org.freedesktop.DBus.Properties")
            ac_path = str(
                props.Get("org.freedesktop.NetworkManager", "PrimaryConnection")
            )
            if ac_path == "/":
                return
            ac = self.system_bus.get_object("org.freedesktop.NetworkManager", ac_path)
            ac_props = dbus.Interface(ac, "org.freedesktop.DBus.Properties")
            dev_paths = ac_props.Get(
                "org.freedesktop.NetworkManager.Connection.Active", "Devices"
            )
            for dev_path in dev_paths:
                dev = self.system_bus.get_object(
                    "org.freedesktop.NetworkManager", str(dev_path)
                )
                dev_props = dbus.Interface(dev, "org.freedesktop.DBus.Properties")
                ap_path = str(
                    dev_props.Get(
                        "org.freedesktop.NetworkManager.Device.Wireless",
                        "ActiveAccessPoint",
                    )
                )
                if ap_path == "/":
                    continue
                ap = self.system_bus.get_object(
                    "org.freedesktop.NetworkManager", ap_path
                )
                ap_props = dbus.Interface(ap, "org.freedesktop.DBus.Properties")
                self.state.wifi_signal = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "Strength"
                    )
                )
                break
        except Exception as e:
            print(f"[system-monitor] WiFi signal error: {e}", file=sys.stderr)

    def _on_nm_changed(self, iface, changed, invalidated):
        if (
            "State" in changed
            or "ActiveAccessPoint" in changed
            or "Strength" in changed
        ):
            self._init_wifi()
            with self._lock:
                self._emit()

    # ── PulseAudio/PipeWire (volume) ──────────────────────────────────────────

    def _setup_pulseaudio(self):
        try:
            # PulseAudio expose Core via session bus
            pa = self.session_bus.get_object("org.PulseAudio1", "/org/pulseaudio/core1")
            core = dbus.Interface(pa, "org.PulseAudio.Core1")
            # Subscribe ke FallbackSink changes
            core.ListenForSignal("org.PulseAudio.Core1.Device.VolumeUpdated", [])
            core.ListenForSignal("org.PulseAudio.Core1.Device.MuteUpdated", [])
            core.ListenForSignal("org.PulseAudio.Core1.FallbackSinkUpdated", [])

            self.session_bus.add_signal_receiver(
                self._on_volume_changed,
                signal_name="VolumeUpdated",
                dbus_interface="org.PulseAudio.Core1.Device",
            )
            self.session_bus.add_signal_receiver(
                self._on_mute_changed,
                signal_name="MuteUpdated",
                dbus_interface="org.PulseAudio.Core1.Device",
            )

            self._pa_core = core
            self._init_volume_pa()
            print("[system-monitor] PulseAudio subscribed", file=sys.stderr, flush=True)
        except Exception as e:
            print(
                f"[system-monitor] PulseAudio D-Bus error: {e}, fallback ke pactl polling",
                file=sys.stderr,
            )
            self._pa_core = None
            self._setup_volume_polling_fallback()

    def _init_volume_pa(self):
        try:
            sink_path = str(self._pa_core.Get("org.PulseAudio.Core1", "FallbackSink"))
            sink = self.session_bus.get_object("org.PulseAudio1", sink_path)
            sink_props = dbus.Interface(sink, "org.freedesktop.DBus.Properties")
            p = sink_props.GetAll("org.PulseAudio.Core1.Device")

            volumes = list(p.get("Volume", [65536]))
            self.state.vol_pct = int(sum(volumes) / len(volumes) * 100 / 65536)
            self.state.vol_muted = bool(p.get("Mute", False))
        except Exception as e:
            print(f"[system-monitor] Init volume error: {e}", file=sys.stderr)

    def _on_volume_changed(self, volumes):
        self.state.vol_pct = int(sum(volumes) / len(volumes) * 100 / 65536)
        with self._lock:
            self._emit()

    def _on_mute_changed(self, muted):
        self.state.vol_muted = bool(muted)
        with self._lock:
            self._emit()

    def _setup_volume_polling_fallback(self):
        """Fallback: pactl polling tiap 2s kalau PulseAudio D-Bus tidak tersedia."""

        def _poll():
            import subprocess

            while True:
                try:
                    muted = subprocess.run(
                        ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                        capture_output=True,
                        text=True,
                    ).stdout.strip()
                    vol = subprocess.run(
                        ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                        capture_output=True,
                        text=True,
                    ).stdout
                    import re

                    m = re.search(r"(\d+)%", vol)
                    self.state.vol_pct = int(m.group(1)) if m else 0
                    self.state.vol_muted = "yes" in muted
                    with self._lock:
                        self._emit()
                except Exception:
                    pass
                time.sleep(2)

        t = threading.Thread(target=_poll, daemon=True)
        t.start()

    def _init_volume(self):
        if self._pa_core:
            self._init_volume_pa()
        # kalau fallback, thread sudah handle

    # ── Brightness via inotify ────────────────────────────────────────────────

    def _setup_brightness_inotify(self):
        if not self.state.bright_path:
            return
        try:
            ifd = _inotify_init()
            _inotify_add_watch(
                ifd, str(self.state.bright_path), IN_CLOSE_WRITE | IN_MODIFY
            )
            print(
                f"[system-monitor] Brightness inotify: {self.state.bright_path}",
                file=sys.stderr,
                flush=True,
            )

            def _watch():
                import select

                while True:
                    select.select([ifd], [], [])
                    os.read(ifd, 4096)  # consume event
                    self.state.read_brightness()
                    with self._lock:
                        self._emit()

            t = threading.Thread(target=_watch, daemon=True)
            t.start()
        except Exception as e:
            print(f"[system-monitor] Brightness inotify error: {e}", file=sys.stderr)

    # ── Network speed sampling (non-blocking) ─────────────────────────────────

    def _setup_network_speed_thread(self):
        def _sample():
            while True:
                time.sleep(SPEED_INTERVAL)
                rx1, tx1 = self.state.read_network_bytes()
                time.sleep(1.0)
                rx2, tx2 = self.state.read_network_bytes()
                self.state.rx_rate = (rx2 - rx1) / 1.0
                self.state.tx_rate = (tx2 - tx1) / 1.0
                with self._lock:
                    self._emit()

        t = threading.Thread(target=_sample, daemon=True)
        t.start()

    # ── Emit ──────────────────────────────────────────────────────────────────

    def _emit(self):
        print(self.state.to_json(), flush=True)


# ─── Entry point ──────────────────────────────────────────────────────────────


def run():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    system_bus = dbus.SystemBus()
    session_bus = dbus.SessionBus()

    monitor = SystemMonitor(system_bus, session_bus)

    print("[system-monitor] Aktif.", file=sys.stderr, flush=True)

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        print("\n[system-monitor] Dihentikan.", file=sys.stderr)


if __name__ == "__main__":
    run()
