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


def _icon_base_dirs() -> list[Path]:
    """Kembalikan semua base direktori icons sesuai XDG spec."""
    home = Path.home()
    dirs = [home / ".local/share/icons", home / ".icons"]
    # Baca semua XDG_DATA_DIRS
    xdg_data_dirs = os.environ.get(
        "XDG_DATA_DIRS", "/usr/local/share:/usr/share"
    ).split(":")
    for d in xdg_data_dirs:
        dirs.append(Path(d) / "icons")
    dirs.append(Path("/usr/share/pixmaps"))
    return dirs


def _parse_theme_dirs(theme_root: Path) -> list[Path]:
    index = theme_root / "index.theme"
    if not index.exists():
        return []
    cfg = ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read_string(index.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return []
    if not cfg.has_section("Icon Theme"):
        return []

    raw_dirs = cfg["Icon Theme"].get("Directories", "")
    scaled_dirs = cfg["Icon Theme"].get("ScaledDirectories", "")
    subdirs = [
        s.strip() for s in (raw_dirs + "," + scaled_dirs).split(",") if s.strip()
    ]

    result: list[tuple[int, Path]] = []
    for sub in subdirs:
        # Ambil semua folder yang mengandung "apps" di path-nya, tanpa peduli context
        if not re.search(r"(?:^|/)apps(?:/|$)", sub, re.IGNORECASE):
            continue
        full = theme_root / sub
        if not full.is_dir():
            continue
        if "scalable" in sub.lower():
            key = 9999
        else:
            nums = re.findall(r"\d+", sub)
            key = int(nums[-1]) if nums else 0
        result.append((key, full))

    result.sort(key=lambda x: x[0], reverse=True)
    return [p for _, p in result]


def _collect_theme_search_dirs(
    theme: str, visited: set[str] | None = None
) -> list[Path]:
    """
    Kumpulkan semua direktori icon untuk `theme` secara rekursif
    mengikuti chain Inherits= di index.theme (XDG Icon Theme Spec).
    """
    if visited is None:
        visited = set()
    if theme in visited:
        return []
    visited.add(theme)

    base_dirs = _icon_base_dirs()
    result: list[Path] = []

    theme_root: Path | None = None
    for base in base_dirs:
        candidate = base / theme
        if (candidate / "index.theme").exists():
            theme_root = candidate
            break

    if theme_root is None:
        return []

    # Tambahkan direktori dari theme ini
    result.extend(_parse_theme_dirs(theme_root))

    # Ikuti Inherits= chain
    index = theme_root / "index.theme"
    cfg = ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read_string(index.read_text(encoding="utf-8", errors="replace"))
        inherits_raw = cfg["Icon Theme"].get("Inherits", "")
        for parent in [s.strip() for s in inherits_raw.split(",") if s.strip()]:
            result.extend(_collect_theme_search_dirs(parent, visited))
    except Exception:
        pass

    return result


def build_icon_search_dirs(theme: str) -> list[Path]:
    """
    Bangun daftar direktori pencarian icon sesuai XDG Icon Theme Specification:
    1. Semua dir dari theme aktif (rekursif via Inherits=)
    2. Fallback ke hicolor
    3. Fallback ke /usr/share/pixmaps
    """
    dirs: list[Path] = []
    seen: set[Path] = set()

    for d in _collect_theme_search_dirs(theme, set()):
        if d not in seen:
            seen.add(d)
            dirs.append(d)

    # Pastikan hicolor selalu ada sebagai fallback
    for d in _collect_theme_search_dirs("hicolor", set()):
        if d not in seen:
            seen.add(d)
            dirs.append(d)

    # Pixmaps terakhir
    pixmaps = Path("/usr/share/pixmaps")
    if pixmaps not in seen:
        dirs.append(pixmaps)

    print(
        f"[menu-gen] Icon search dirs untuk '{theme}': {len(dirs)} direktori",
        file=sys.stderr,
        flush=True,
    )
    return dirs


FALLBACK_ICON = (
    "/usr/share/icons/Adwaita/scalable/mimetypes/application-x-executable.svg"
)
ICON_SEARCH_DIRS = build_icon_search_dirs(
    load_dotfiles_config().get("ICON_THEME", "hicolor")
)

_icon_cache: dict[str, str] = {}
_current_theme: str = ""


def resolve_icon(icon_name: str) -> str:
    """
    Cari icon dengan name fallback chain sesuai XDG spec:
    - "org.gnome.Foo" → coba "org.gnome.Foo", "gnome.Foo", "Foo"
    - "foo-bar-baz"   → coba "foo-bar-baz", "foo-bar", "foo"
    - Path absolut    → langsung pakai
    """
    if icon_name in _icon_cache:
        return _icon_cache[icon_name]

    # Path absolut langsung pakai
    if icon_name.startswith("/") and Path(icon_name).exists():
        _icon_cache[icon_name] = icon_name
        return icon_name

    def _find_exact(name: str) -> str | None:
        for d in ICON_SEARCH_DIRS:
            if name.endswith((".svg", ".png", ".xpm")):
                p = d / name
                if p.exists():
                    return str(p)
            else:
                for ext in (".svg", ".png", ".xpm"):
                    p = d / f"{name}{ext}"
                    if p.exists():
                        return str(p)
        return None

    # Bangun fallback chain dari nama icon
    # "org.kde.foo-bar" → ["org.kde.foo-bar", "kde.foo-bar", "foo-bar", "foo"]
    def _fallback_chain(name: str) -> list[str]:
        names = [name]
        # Strip reverse-DNS prefix (titik)
        parts = name.split(".")
        for i in range(1, len(parts)):
            names.append(".".join(parts[i:]))
        # Strip dash suffix dari nama terakhir
        last = names[-1]
        dash_parts = last.split("-")
        for i in range(len(dash_parts) - 1, 0, -1):
            names.append("-".join(dash_parts[:i]))
        # Hapus duplikat sambil jaga urutan
        seen = set()
        result = []
        for n in names:
            if n not in seen and n:
                seen.add(n)
                result.append(n)
        return result

    for candidate in _fallback_chain(icon_name):
        hit = _find_exact(candidate)
        if hit:
            _icon_cache[icon_name] = hit
            return hit

    _icon_cache[icon_name] = FALLBACK_ICON
    return FALLBACK_ICON


CATEGORY_GENERIC_ICONS = {
    "Internet": "applications-internet",
    "Multimedia": "applications-multimedia",
    "Office": "applications-office",
    "Graphics": "applications-graphics",
    "Development": "applications-development",
    "Games": "applications-games",
    "System": "applications-system",
    "Settings": "preferences-system",
    "Education": "applications-science",
    "Utilities": "applications-utilities",
    "Other": "application-x-executable",
}


def resolve_icon_with_category_fallback(icon_name: str, category: str) -> str:
    result = resolve_icon(icon_name)
    if result != FALLBACK_ICON:
        return result
    generic = CATEGORY_GENERIC_ICONS.get(category, "application-x-executable")
    result = resolve_icon(generic)
    if result != FALLBACK_ICON:
        return result
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
        "icon": resolve_icon_with_category_fallback(icon, category),
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
