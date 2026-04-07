#!/usr/bin/env python3
"""
system-monitor.py — System status monitor via D-Bus events
- Battery + WiFi: UPower + NetworkManager D-Bus signals
- Volume: PulseAudio/PipeWire D-Bus signals
- Brightness: inotify /sys/class/backlight
- Bluetooth: via bluez
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


def bt_icon(connected: bool) -> str:
    return "󰂱" if connected else "󰂯"


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
        self.wifi_ssid = ""
        self.wifi_security = ""
        self.wifi_powered = False

        # Battery model
        self.bat_model = "Unknown"
        self.bat_capacity = 0
        self.bat_charging = False

        # Bluetooth
        self.bt_devices = []
        self.bt_powered = False

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
                "wifi_ssid": self.wifi_ssid,
                "wifi_signal": self.wifi_signal,
                "wifi_security": self.wifi_security,
                "wifi_powered": self.wifi_powered,
                "bat_model": self.bat_model,
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
                "bt_devices": self.bt_devices,
                "bt_connected": len(self.bt_devices) > 0,
                "bt_powered": self.bt_powered,
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
        self._setup_bluetooth()
        self._init_bluetooth()
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
                if int(p.get("Type", 0)) == 2:
                    self.state.bat_capacity = int(p.get("Percentage", 0))
                    state = int(p.get("State", 0))
                    self.state.bat_charging = state in (1, 4)
                    # Model battery — kombinasi vendor + model
                    vendor = str(p.get("Vendor", "")).strip()
                    model = str(p.get("Model", "")).strip()
                    if vendor and model:
                        self.state.bat_model = f"{vendor} {model}"
                    elif model:
                        self.state.bat_model = model
                    elif vendor:
                        self.state.bat_model = vendor
                    else:
                        self.state.bat_model = "Unknown"
                    break
        except Exception as e:
            print(f"[system-monitor] Init battery error: {e}", file=sys.stderr)

    def _on_upower_changed(self, iface, changed, invalidated):
        if "Percentage" in changed or "State" in changed:
            self._init_battery()
            with self._lock:
                self._emit()

    # ── BlueZ (bluetooth) ─────────────────────────────────────────────────

    def _setup_bluetooth(self):
        try:
            self.system_bus.add_signal_receiver(
                self._on_bt_changed,
                signal_name="PropertiesChanged",
                dbus_interface="org.freedesktop.DBus.Properties",
                bus_name="org.bluez",
                path_keyword="path",
            )
            print("[system-monitor] BlueZ subscribed", file=sys.stderr, flush=True)
        except Exception as e:
            print(f"[system-monitor] BlueZ error: {e}", file=sys.stderr)

    def _init_bluetooth(self):
        try:
            om = dbus.Interface(
                self.system_bus.get_object("org.bluez", "/"),
                "org.freedesktop.DBus.ObjectManager",
            )
            objects = om.GetManagedObjects()

            # Cek adapter powered
            self.state.bt_powered = False
            for path, ifaces in objects.items():
                adapter = ifaces.get("org.bluez.Adapter1", {})
                if adapter:
                    self.state.bt_powered = bool(adapter.get("Powered", False))
                    break  # ambil hci0 saja

            connected = []
            for path, ifaces in objects.items():
                dev = ifaces.get("org.bluez.Device1", {})
                if dev.get("Connected", False):
                    connected.append(
                        {
                            "address": str(dev.get("Address", "")),
                            "name": str(dev.get("Alias") or dev.get("Name", "Unknown")),
                        }
                    )
            self.state.bt_devices = connected
        except Exception as e:
            print(f"[system-monitor] BlueZ init error: {e}", file=sys.stderr)

    def _on_bt_changed(self, iface, changed, invalidated, path=None):
        if "Connected" in changed or "Powered" in changed:
            self._init_bluetooth()
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
                "org.freedesktop.NetworkManager",
                "/org/freedesktop/NetworkManager",
            )
            nm_props = dbus.Interface(nm, "org.freedesktop.DBus.Properties")

            # Powered
            self.state.wifi_powered = bool(
                nm_props.Get("org.freedesktop.NetworkManager", "WirelessEnabled")
            )

            state = int(nm_props.Get("org.freedesktop.NetworkManager", "State"))
            self.state.wifi_connected = state == 70  # NM_STATE_CONNECTED_GLOBAL

            if not self.state.wifi_connected:
                self.state.wifi_signal = 0
                self.state.wifi_ssid = ""
                self.state.wifi_security = ""
                return

            devices = nm.GetDevices(dbus_interface="org.freedesktop.NetworkManager")
            for dev_path in devices:
                dev = self.system_bus.get_object(
                    "org.freedesktop.NetworkManager", dev_path
                )
                dev_props = dbus.Interface(dev, "org.freedesktop.DBus.Properties")
                dev_type = int(
                    dev_props.Get("org.freedesktop.NetworkManager.Device", "DeviceType")
                )
                if dev_type != 2:
                    continue
                dev_state = int(
                    dev_props.Get("org.freedesktop.NetworkManager.Device", "State")
                )
                if dev_state != 100:
                    continue
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
                ssid_bytes = ap_props.Get(
                    "org.freedesktop.NetworkManager.AccessPoint", "Ssid"
                )
                self.state.wifi_ssid = bytes(ssid_bytes).decode(
                    "utf-8", errors="replace"
                )
                self.state.wifi_signal = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "Strength"
                    )
                )
                flags = int(
                    ap_props.Get("org.freedesktop.NetworkManager.AccessPoint", "Flags")
                )
                wpa = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "WpaFlags"
                    )
                )
                rsn = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "RsnFlags"
                    )
                )
                if rsn > 0:
                    self.state.wifi_security = "WPA2"
                elif wpa > 0:
                    self.state.wifi_security = "WPA"
                elif flags & 0x1:
                    self.state.wifi_security = "WEP"
                else:
                    self.state.wifi_security = "Open"
                break
        except Exception as e:
            print(f"[system-monitor] WiFi signal error: {e}", file=sys.stderr)

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
                self.state.wifi_signal = 0
                self.state.wifi_ssid = ""
                self.state.wifi_security = ""
                return
            ac = self.system_bus.get_object("org.freedesktop.NetworkManager", ac_path)
            ac_props = dbus.Interface(ac, "org.freedesktop.DBus.Properties")

            # Ambil SSID dari connection ID
            self.state.wifi_ssid = str(
                ac_props.Get("org.freedesktop.NetworkManager.Connection.Active", "Id")
            )

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

                # Flags: 0x1=WEP, WpaFlags/RsnFlags > 0 = WPA/WPA2
                flags = int(
                    ap_props.Get("org.freedesktop.NetworkManager.AccessPoint", "Flags")
                )
                wpa = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "WpaFlags"
                    )
                )
                rsn = int(
                    ap_props.Get(
                        "org.freedesktop.NetworkManager.AccessPoint", "RsnFlags"
                    )
                )
                if rsn > 0:
                    self.state.wifi_security = "WPA2"
                elif wpa > 0:
                    self.state.wifi_security = "WPA"
                elif flags & 0x1:
                    self.state.wifi_security = "WEP"
                else:
                    self.state.wifi_security = "Open"
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
        """
        Pakai pactl subscribe — event-driven via PipeWire pulse compatibility.
        Jauh lebih responsif dari polling karena hanya trigger saat ada perubahan.
        """
        import subprocess

        def _read_volume():
            try:
                result = subprocess.run(
                    ["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                    capture_output=True,
                    text=True,
                )
                import re

                m = re.search(r"(\d+)%", result.stdout)
                return int(m.group(1)) if m else 0
            except Exception:
                return 0

        def _read_mute():
            try:
                result = subprocess.run(
                    ["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                    capture_output=True,
                    text=True,
                )
                return "yes" in result.stdout
            except Exception:
                return False

        def _watch():
            import subprocess

            self.state.vol_pct = _read_volume()
            self.state.vol_muted = _read_mute()
            with self._lock:
                self._emit()

            proc = subprocess.Popen(
                ["pactl", "subscribe"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )

            if proc.stdout is None:
                print(
                    "[system-monitor] pactl subscribe gagal",
                    file=sys.stderr,
                    flush=True,
                )
                return

            print(
                "[system-monitor] pactl subscribe aktif (PipeWire mode)",
                file=sys.stderr,
                flush=True,
            )

            for line in proc.stdout:
                if "sink" not in line and "server" not in line:
                    continue
                if "change" not in line and "new" not in line:
                    continue
                self.state.vol_pct = _read_volume()
                self.state.vol_muted = _read_mute()
                with self._lock:
                    self._emit()

        t = threading.Thread(target=_watch, daemon=True)
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
