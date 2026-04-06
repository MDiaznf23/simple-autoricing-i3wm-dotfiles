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

FALLBACK_ICON = (
    "/usr/share/icons/Adwaita/scalable/mimetypes/application-x-executable.svg"
)
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
        print(
            f"[dock-gen] config-dotfiles tidak ditemukan, pakai hicolor.",
            file=sys.stderr,
            flush=True,
        )
        return result
    for line in DOTFILES_CONFIG.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        result[key.strip()] = val.strip()
    return result


def _icon_base_dirs() -> list[Path]:
    home = Path.home()
    dirs = [home / ".local/share/icons", home / ".icons"]
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
    if visited is None:
        visited = set()
    if theme in visited:
        return []
    visited.add(theme)

    result: list[Path] = []
    theme_root = None
    for base in _icon_base_dirs():
        candidate = base / theme
        if (candidate / "index.theme").exists():
            theme_root = candidate
            break
    if theme_root is None:
        return []

    result.extend(_parse_theme_dirs(theme_root))

    cfg = ConfigParser(interpolation=None, strict=False)
    try:
        cfg.read_string(
            (theme_root / "index.theme").read_text(encoding="utf-8", errors="replace")
        )
        for parent in [
            s.strip()
            for s in cfg["Icon Theme"].get("Inherits", "").split(",")
            if s.strip()
        ]:
            result.extend(_collect_theme_search_dirs(parent, visited))
    except Exception:
        pass
    return result


def build_icon_search_dirs(theme: str) -> list[Path]:
    dirs: list[Path] = []
    seen: set[Path] = set()
    for d in _collect_theme_search_dirs(theme, set()):
        if d not in seen:
            seen.add(d)
            dirs.append(d)
    for d in _collect_theme_search_dirs("hicolor", set()):
        if d not in seen:
            seen.add(d)
            dirs.append(d)
    pixmaps = Path("/usr/share/pixmaps")
    if pixmaps not in seen:
        dirs.append(pixmaps)
    return dirs


def resolve_icon(icon_name: str, search_dirs: list[Path]) -> str:
    if icon_name.startswith("/") and Path(icon_name).exists():
        return icon_name

    def _find_exact(name: str) -> str | None:
        for d in search_dirs:
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

    def _fallback_chain(name: str) -> list[str]:
        names = [name]
        # Strip reverse-DNS (titik): "org.kde.foo" → "kde.foo" → "foo"
        parts = name.split(".")
        for i in range(1, len(parts)):
            names.append(".".join(parts[i:]))
        # Strip dash suffix dari elemen terakhir: "foo-bar-baz" → "foo-bar" → "foo"
        last = names[-1]
        dash_parts = last.split("-")
        for i in range(len(dash_parts) - 1, 0, -1):
            names.append("-".join(dash_parts[:i]))
        # Deduplicate, jaga urutan
        seen: set[str] = set()
        result = []
        for n in names:
            if n and n not in seen:
                seen.add(n)
                result.append(n)
        return result

    for candidate in _fallback_chain(icon_name):
        hit = _find_exact(candidate)
        if hit:
            return hit

    return FALLBACK_ICON


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


def _classify_category(cats_str: str) -> str:
    cats = set(cats_str.replace(";", " ").split())
    for menu_cat, keywords in CATEGORY_RULES:
        if cats & set(keywords):
            return menu_cat
    return "Other"


def resolve_icon_with_category_fallback(
    icon_name: str, category: str, search_dirs: list
) -> str:
    result = resolve_icon(icon_name, search_dirs)
    if result != FALLBACK_ICON:
        return result
    generic = CATEGORY_GENERIC_ICONS.get(category, "application-x-executable")
    return resolve_icon(generic, search_dirs)


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
        "categories": entry.get("Categories", "").strip(),
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
        print(
            f"[dock-gen] apps.json tidak ditemukan: {APPS_JSON}",
            file=sys.stderr,
            flush=True,
        )
        return []

    try:
        raw = json.loads(APPS_JSON.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"[dock-gen] apps.json invalid JSON: {e}", file=sys.stderr, flush=True)
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
            category = _classify_category(entry.get("categories", ""))
            icon = resolve_icon_with_category_fallback(
                entry["icon"], category, search_dirs
            )
        else:
            print(
                f"[dock-gen] .desktop tidak ditemukan untuk: {app_id}",
                file=sys.stderr,
                flush=True,
            )
            name = app_id
            exec_cmd = app_id
            icon = resolve_icon_with_category_fallback(app_id, "Other", search_dirs)

        result.append(
            {
                "id": app_id,
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
    print(
        f"[dock-gen] Regenerated → {OUTPUT_FILE} | {len(dock)} apps",
        file=sys.stderr,
        flush=True,
    )
    # Output JSON ke stdout — ditangkap deflisten eww
    print(json.dumps(dock, ensure_ascii=False), flush=True)


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
            print(f"[dock-gen] Watching: {d}", file=sys.stderr, flush=True)

    generate_once()
    print("[dock-gen] Daemon aktif. Menunggu event...", file=sys.stderr, flush=True)

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
                    file=sys.stderr,
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
            print("\n[dock-gen] Dihentikan.", file=sys.stderr, flush=True)
