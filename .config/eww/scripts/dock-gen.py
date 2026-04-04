#!/usr/bin/env python3
"""
dock-gen.py — Generate eww-dock.json dari apps.json
Usage:
    python3 dock-gen.py          # daemon, watch apps.json + config-dotfiles
    python3 dock-gen.py --once   # generate sekali lalu keluar
"""

import ctypes
import json
import os
import re
import select
import struct
import sys
import time
from configparser import ConfigParser, MissingSectionHeaderError
from pathlib import Path

# ─── Konfigurasi ──────────────────────────────────────────────────────────────

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))

OUTPUT_FILE = CACHE_DIR / "eww-dock.json"
APPS_JSON = CONFIG_DIR / "eww/apps.json"  # <── sesuaikan path-mu
DOTFILES_CONFIG = CONFIG_DIR / "i3/config-dotfiles"

FALLBACK_ICON = "/usr/share/pixmaps/archlinux-logo.png"
DEBOUNCE_SECS = 1.0

APP_DIRS = [
    Path("/usr/share/applications"),
    Path("/usr/local/share/applications"),
    Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    / "applications",
]

# ─── Dotfiles & Icon ──────────────────────────────────────────────────────────


def load_dotfiles_config() -> dict:
    result = {}
    if not DOTFILES_CONFIG.exists():
        print(f"[dock-gen] config-dotfiles tidak ditemukan, pakai hicolor.", flush=True)
        return result
    for line in DOTFILES_CONFIG.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        result[key.strip()] = val.strip()
    return result


def build_icon_search_dirs(theme: str) -> list[Path]:
    home = Path.home()
    local_icons = home / ".local/share/icons"
    dirs = []
    for variant in [theme, f"{theme}-light", f"{theme}-dark"]:
        for subdir in ["scalable/apps", "48x48/apps"]:
            dirs.append(local_icons / variant / subdir)
            dirs.append(Path(f"/usr/share/icons/{variant}/{subdir}"))
    dirs += [
        Path("/usr/share/icons/hicolor/scalable/apps"),
        Path("/usr/share/icons/hicolor/48x48/apps"),
        Path("/usr/share/pixmaps"),
    ]
    return dirs


def resolve_icon(icon_name: str, search_dirs: list[Path]) -> str:
    if icon_name.startswith("/") and Path(icon_name).exists():
        return icon_name
    for d in search_dirs:
        for ext in [".svg", ".png"]:
            p = d / f"{icon_name}{ext}"
            if p.exists():
                return str(p)
    return FALLBACK_ICON


# ─── Desktop entry lookup ─────────────────────────────────────────────────────


def _parse_desktop(path: Path) -> dict | None:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    cfg = ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read_string(text)
    except MissingSectionHeaderError:
        return None
    if not cfg.has_section("Desktop Entry"):
        return None
    entry = cfg["Desktop Entry"]
    if entry.get("Type") != "Application":
        return None
    if entry.get("NoDisplay", "false").lower() == "true":
        return None
    exec_cmd = re.sub(r" %[a-zA-Z]", "", entry.get("Exec", "")).strip()
    if not exec_cmd:
        return None
    return {
        "name": entry.get("Name", path.stem).strip(),
        "exec": exec_cmd,
        "icon": entry.get("Icon", "application-x-executable").strip(),
    }


def find_desktop_entry(app_id: str) -> dict | None:
    # Cari by Desktop File ID — cara paling robust
    for app_dir in APP_DIRS:
        if not app_dir.is_dir():
            continue
        p = app_dir / f"{app_id}.desktop"
        if p.exists():
            result = _parse_desktop(p)
            if result:
                return result

    # Fallback: scan semua, cocokkan Name= (untuk data lama)
    for app_dir in APP_DIRS:
        if not app_dir.is_dir():
            continue
        for desktop_file in sorted(app_dir.glob("*.desktop")):
            result = _parse_desktop(desktop_file)
            if result and result["name"].lower() == app_id.lower():
                return result

    return None


# ─── Build dock JSON ──────────────────────────────────────────────────────────


def build_dock() -> list:
    dotfiles = load_dotfiles_config()
    theme = dotfiles.get("ICON_THEME", "hicolor")
    search_dirs = build_icon_search_dirs(theme)
    print(f"[dock-gen] Icon theme: {theme}", flush=True)

    if not APPS_JSON.exists():
        print(f"[dock-gen] apps.json tidak ditemukan: {APPS_JSON}", flush=True)
        return []

    try:
        raw = json.loads(APPS_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"[dock-gen] apps.json invalid JSON: {e}", flush=True)
        return []

    result = []
    for item in raw:
        app_id = item.get("name", "").strip()
        if not app_id:
            continue

        entry = find_desktop_entry(app_id)
        if entry:
            name = entry["name"]
            exec_cmd = entry["exec"]
            icon = resolve_icon(entry["icon"], search_dirs)
        else:
            print(f"[dock-gen] .desktop tidak ditemukan untuk: {app_id}", flush=True)
            name = app_id
            exec_cmd = app_id
            icon = resolve_icon(app_id, search_dirs)

        result.append(
            {
                "id": app_id,  # Desktop File ID dari apps.json
                "name": name,
                "exec": exec_cmd,
                "icon": icon,
            }
        )

    return result


def write_output(dock: list):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUTPUT_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(dock, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.rename(OUTPUT_FILE)
    print(f"[dock-gen] Regenerated → {OUTPUT_FILE} | {len(dock)} apps", flush=True)


# ─── inotify via ctypes ───────────────────────────────────────────────────────

libc = ctypes.CDLL("libc.so.6", use_errno=True)

IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
WATCH_MASK = IN_CLOSE_WRITE | IN_MOVED_TO

_EVENT_HEADER = struct.Struct("iIII")
_EVENT_HEADER_SIZE = _EVENT_HEADER.size  # 16 bytes


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


def _read_events(fd) -> list[str]:
    raw = os.read(fd, 4096)
    names = []
    offset = 0
    while offset < len(raw):
        wd, mask, cookie, length = _EVENT_HEADER.unpack_from(raw, offset)
        offset += _EVENT_HEADER_SIZE
        if length:
            name = (
                raw[offset : offset + length].rstrip(b"\x00").decode(errors="replace")
            )
            names.append(name)
        offset += length
    return names


# ─── Entry point ──────────────────────────────────────────────────────────────


def generate_once():
    write_output(build_dock())


def run_daemon():
    ifd = _inotify_init()

    # Watch direktori yang mengandung apps.json dan config-dotfiles
    watch_dirs = {}
    for path in [APPS_JSON, DOTFILES_CONFIG]:
        d = path.parent
        if d.is_dir() and d not in watch_dirs:
            _inotify_add_watch(ifd, str(d), WATCH_MASK)
            watch_dirs[d] = True
            print(f"[dock-gen] Watching: {d}", flush=True)

    generate_once()
    print("[dock-gen] Daemon aktif. Menunggu event...", flush=True)

    TRIGGER_FILES = {APPS_JSON.name, DOTFILES_CONFIG.name}
    pending = False
    deadline = 0.0

    while True:
        timeout = max(0.0, deadline - time.monotonic()) if pending else None
        readable, _, _ = select.select([ifd], [], [], timeout)

        if readable:
            names = _read_events(ifd)
            if any(n in TRIGGER_FILES for n in names):
                pending = True
                deadline = time.monotonic() + DEBOUNCE_SECS
                print(
                    f"[dock-gen] Event: {names} — debounce {DEBOUNCE_SECS}s...",
                    flush=True,
                )
        elif pending:
            generate_once()
            pending = False


if __name__ == "__main__":
    if "--once" in sys.argv:
        generate_once()
    else:
        try:
            run_daemon()
        except KeyboardInterrupt:
            print("\n[dock-gen] Dihentikan.", flush=True)
