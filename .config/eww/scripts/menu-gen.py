#!/usr/bin/env python3
"""
menu-gen.py — Event-driven start menu JSON generator untuk EWW / Openbox
- Zero dependency: hanya stdlib + inotify via ctypes (built-in Linux kernel)
- Tidak polling: regenerate HANYA saat ada file .desktop baru/diubah/dihapus
- Single process: tidak ada fork, tidak ada subprocess

Usage:
    python3 menu-gen.py            # jalankan sebagai daemon
    python3 menu-gen.py --once     # generate sekali lalu keluar
"""

import ctypes
import errno
import json
import os
import select
import struct
import sys
import time
from configparser import ConfigParser, MissingSectionHeaderError
from io import StringIO
import re
from pathlib import Path

# ─── Konfigurasi ──────────────────────────────────────────────────────────────

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
OUTPUT_FILE = CACHE_DIR / "eww-menu.json"

APP_DIRS = [
    Path("/usr/share/applications"),
    Path("/usr/local/share/applications"),
    Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    / "applications",
]

# Urutan tampilan kategori di menu
CATEGORY_ORDER = [
    "Internet",
    "Multimedia",
    "Office",
    "Graphics",
    "Development",
    "Games",
    "System",
    "Settings",
    "Education",
    "Utilities",
    "Other",
]

CATEGORY_ICONS = {
    "Internet": "network-wireless",
    "Multimedia": "applications-multimedia",
    "Office": "applications-office",
    "Graphics": "applications-graphics",
    "Development": "applications-development",
    "Games": "applications-games",
    "System": "applications-system",
    "Settings": "preferences-system",
    "Education": "applications-science",
    "Utilities": "applications-utilities",
    "Other": "applications-other",
}

# Mapping keyword Categories= → nama kategori di menu
CATEGORY_RULES = [
    ("Internet", ["Network", "WebBrowser", "Email", "InstantMessaging", "Chat"]),
    ("Multimedia", ["AudioVideo", "Audio", "Video", "Music", "Player", "Recorder"]),
    (
        "Office",
        [
            "Office",
            "WordProcessor",
            "Spreadsheet",
            "Presentation",
            "Calendar",
            "ContactManagement",
        ],
    ),
    ("Graphics", ["Graphics", "Photography", "Viewer", "2DGraphics", "3DGraphics"]),
    (
        "Development",
        ["Development", "IDE", "Debugger", "RevisionControl", "WebDevelopment"],
    ),
    ("Games", ["Game", "Emulator", "ArcadeGame", "BoardGame", "CardGame"]),
    (
        "System",
        ["System", "TerminalEmulator", "FileManager", "Monitor", "PackageManager"],
    ),
    ("Settings", ["Settings", "Preferences", "DesktopSettings", "HardwareSettings"]),
    ("Education", ["Science", "Education", "Math", "Astronomy", "Chemistry"]),
    ("Utilities", ["Utility", "Archiving", "Accessibility", "Clock", "Calculator"]),
]

# Debounce: tunggu N detik setelah event terakhir sebelum regenerate
# Berguna saat package manager install banyak .desktop sekaligus
DEBOUNCE_SECS = 2.0

# ─── inotify via ctypes (zero dependency) ────────────────────────────────────

libc = ctypes.CDLL("libc.so.6", use_errno=True)

IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_CLOSE_WRITE = 0x00000008  # file selesai ditulis (install selesai)
IN_MOVED_FROM = 0x00000040
IN_MOVED_TO = 0x00000080

# struct inotify_event: wd(i32) mask(u32) cookie(u32) len(u32) name(char[len])
_EVENT_HEADER = struct.Struct("iIII")
_EVENT_HEADER_SIZE = _EVENT_HEADER.size  # 16 bytes

WATCH_MASK = IN_CREATE | IN_DELETE | IN_CLOSE_WRITE | IN_MOVED_FROM | IN_MOVED_TO


def _inotify_init():
    fd = libc.inotify_init()
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init gagal")
    return fd


def _inotify_add_watch(fd, path, mask):
    wd = libc.inotify_add_watch(fd, path.encode(), mask)
    if wd < 0:
        raise OSError(ctypes.get_errno(), f"inotify_add_watch gagal: {path}")
    return wd


def _read_events(fd):
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


DOTFILES_CONFIG = (
    Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    / "i3/config-dotfiles"
)


def load_dotfiles_config() -> dict:
    result = {}
    if not DOTFILES_CONFIG.exists():
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


FALLBACK_ICON = "/usr/share/pixmaps/archlinux-logo.png"
ICON_SEARCH_DIRS = build_icon_search_dirs(
    load_dotfiles_config().get("ICON_THEME", "hicolor")
)

_icon_cache: dict[str, str] = {}
_current_theme: str = ""


def resolve_icon(icon_name: str) -> str:
    if icon_name in _icon_cache:
        return _icon_cache[icon_name]
    for d in ICON_SEARCH_DIRS:
        for ext in [".svg", ".png"]:
            p = d / f"{icon_name}{ext}"
            if p.exists():
                _icon_cache[icon_name] = str(p)
                return str(p)
    _icon_cache[icon_name] = FALLBACK_ICON
    return FALLBACK_ICON


# ─── Parsing .desktop ─────────────────────────────────────────────────────────


def _classify_category(cats_str: str) -> str:
    """Tentukan kategori menu dari string Categories= pada file .desktop."""
    cats = set(cats_str.replace(";", " ").split())
    for menu_cat, keywords in CATEGORY_RULES:
        if cats & set(keywords):
            return menu_cat
    return "Other"


def parse_desktop_file(path: Path) -> dict | None:
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
    if entry.get("Hidden", "false").lower() == "true":
        return None

    name = entry.get("Name", "").strip()
    exec_cmd = entry.get("Exec", "").strip()

    if not name or not exec_cmd:
        return None

    exec_cmd = re.sub(r" %[a-zA-Z]", "", exec_cmd).strip()

    icon = entry.get("Icon", "application-x-executable").strip()
    cats = entry.get("Categories", "")
    category = _classify_category(cats)
    desc = entry.get("Comment", "").strip()

    # Hitung Desktop File ID dari path
    for app_dir in APP_DIRS:
        try:
            rel = path.relative_to(app_dir)
            desktop_id = str(rel).replace("/", "-").removesuffix(".desktop")
            break
        except ValueError:
            continue
    else:
        desktop_id = path.stem

    return {
        "id": desktop_id,
        "name": name,
        "exec": exec_cmd,
        "icon": resolve_icon(icon),
        "category": category,
        "desc": desc,
    }


# ─── Build JSON ───────────────────────────────────────────────────────────────


def build_menu() -> dict:
    global ICON_SEARCH_DIRS, _icon_cache, _current_theme

    dotfiles = load_dotfiles_config()
    theme = dotfiles.get("ICON_THEME", "hicolor")

    if theme != _current_theme:
        ICON_SEARCH_DIRS = build_icon_search_dirs(theme)
        _icon_cache = {}
        _current_theme = theme
        print(f"[menu-gen] Icon theme berubah: {theme}", file=sys.stderr, flush=True)

    seen: set[tuple] = set()
    categories: dict[str, list] = {cat: [] for cat in CATEGORY_ORDER}

    for app_dir in APP_DIRS:
        if not app_dir.is_dir():
            continue
        for desktop_file in app_dir.glob("*.desktop"):
            app = parse_desktop_file(desktop_file)
            if app is None:
                continue
            key = (app["name"], app["exec"])
            if key in seen:
                continue
            seen.add(key)
            cat = app["category"]
            categories[cat].append(
                {
                    "id": app["id"],
                    "name": app["name"],
                    "exec": app["exec"],
                    "icon": app["icon"],
                    "desc": app["desc"],
                }
            )

    for cat in categories:
        categories[cat].sort(key=lambda a: a["name"].lower())

    result = {
        "categories": [
            {
                "category": cat,
                "icon": CATEGORY_ICONS[cat],
                "apps": categories[cat],
            }
            for cat in CATEGORY_ORDER
            if categories[cat]
        ]
    }
    return result


def write_output(menu: dict):
    """Tulis JSON ke file cache secara atomic dan notify eww via stdout."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUTPUT_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(menu, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.rename(OUTPUT_FILE)

    total_apps = sum(len(c["apps"]) for c in menu["categories"])
    print(
        f"[menu-gen] Regenerated → {OUTPUT_FILE} "
        f"| {len(menu['categories'])} categories, {total_apps} apps",
        file=sys.stderr,
        flush=True,
    )
    # Satu-satunya output ke stdout — ditangkap deflisten eww
    print(json.dumps(menu, ensure_ascii=False), flush=True)


# ─── Main: generate sekali ───────────────────────────────────────────────────


def generate_once():
    write_output(build_menu())


# ─── Main: daemon event-driven ───────────────────────────────────────────────


def run_daemon():
    ifd = _inotify_init()

    wd_to_dir: dict[int, Path] = {}
    for app_dir in APP_DIRS:
        if app_dir.is_dir():
            wd = _inotify_add_watch(ifd, str(app_dir), WATCH_MASK)
            wd_to_dir[wd] = app_dir
            print(f"[menu-gen] Watching: {app_dir}", file=sys.stderr, flush=True)

    dotfiles_dir = DOTFILES_CONFIG.parent
    if dotfiles_dir.is_dir():
        _inotify_add_watch(ifd, str(dotfiles_dir), IN_CLOSE_WRITE | IN_MOVED_TO)
        print(f"[menu-gen] Watching: {dotfiles_dir}", flush=True)

    if not wd_to_dir:
        print(
            "[menu-gen] Tidak ada direktori app yang ditemukan, keluar.",
            file=sys.stderr,
            flush=True,
        )
        return

    generate_once()
    print("[menu-gen] Daemon aktif. Menunggu event...", file=sys.stderr, flush=True)

    pending_regen = False
    deadline: float = 0.0

    while True:
        if pending_regen:
            timeout = max(0.0, deadline - time.monotonic())
        else:
            timeout = None

        readable, _, _ = select.select([ifd], [], [], timeout)

        if readable:
            changed_files = _read_events(ifd)
            relevant = [
                f
                for f in changed_files
                if f.endswith(".desktop") or f == DOTFILES_CONFIG.name
            ]
            if relevant:
                pending_regen = True
                deadline = time.monotonic() + DEBOUNCE_SECS
                print(
                    f"[menu-gen] Event terdeteksi: {relevant} "
                    f"— debounce {DEBOUNCE_SECS}s...",
                    file=sys.stderr,
                    flush=True,
                )
        else:
            if pending_regen:
                generate_once()
                pending_regen = False


# ─── Entry point ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    if "--once" in sys.argv:
        generate_once()
    else:
        try:
            run_daemon()
        except KeyboardInterrupt:
            print("\n[menu-gen] Dihentikan.", file=sys.stderr, flush=True)
