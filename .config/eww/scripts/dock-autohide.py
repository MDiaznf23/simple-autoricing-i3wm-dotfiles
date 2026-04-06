#!/usr/bin/env python3
"""
dock-autohide.py — Dock autohide via i3 IPC events + X11 cursor polling
- i3 window/workspace events: event-driven via IPC langsung
- inotify config-dotfiles: event-driven via ctypes
- Mouse position: polling minimal (hanya saat diperlukan)
"""

import ctypes
import json
import os
import select
import socket
import struct
import subprocess
import sys
import time
import threading
from pathlib import Path

# ─── Konfigurasi ──────────────────────────────────────────────────────────────

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
DOTFILES_CONFIG = CONFIG_DIR / "i3/config-dotfiles"
THRESHOLD = 5
HIDE_DELAY = 1.0
POLL_INTERVAL = 0.2

# ─── i3 IPC ───────────────────────────────────────────────────────────────────

MAGIC = b"i3-ipc"
HDR = struct.Struct("=6sII")
HDR_SIZE = HDR.size

MSG_SUBSCRIBE = 2
MSG_GET_TREE = 4
MSG_GET_WORKSPACES = 1
EVENT_WINDOW = 0x80000003
EVENT_WORKSPACE = 0x80000000


def _get_socket_path() -> str:
    result = subprocess.run(["i3", "--get-socketpath"], capture_output=True, text=True)
    return result.stdout.strip()


def _send(sock: socket.socket, msg_type: int, payload: str = ""):
    data = payload.encode()
    sock.sendall(HDR.pack(MAGIC, len(data), msg_type) + data)


def _recv(sock: socket.socket) -> tuple[int, dict]:
    raw = b""
    while len(raw) < HDR_SIZE:
        raw += sock.recv(HDR_SIZE - len(raw))
    _, length, msg_type = HDR.unpack(raw[:HDR_SIZE])
    body = b""
    while len(body) < length:
        body += sock.recv(length - len(body))
    return msg_type, json.loads(body)


def _count_windows(node: dict) -> int:
    count = 0
    if node.get("window") is not None:
        cls = node.get("window_properties", {}).get("class", "")
        if "eww" not in cls.lower():
            count += 1
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        count += _count_windows(child)
    return count


def get_focused_workspace_name(sock: socket.socket) -> str:
    _send(sock, MSG_GET_WORKSPACES)
    _, workspaces = _recv(sock)
    for ws in workspaces:
        if ws.get("focused"):
            return ws.get("name", "")
    return ""


def _find_workspace(node: dict, name: str) -> dict | None:
    if node.get("type") == "workspace" and node.get("name") == name:
        return node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        found = _find_workspace(child, name)
        if found:
            return found
    return None


def workspace_has_window(sock: socket.socket) -> bool:
    ws_name = get_focused_workspace_name(sock)
    if not ws_name:
        return False
    _send(sock, MSG_GET_TREE)
    _, tree = _recv(sock)
    ws_node = _find_workspace(tree, ws_name)
    if not ws_node:
        return False
    return _count_windows(ws_node) > 0


# ─── inotify via ctypes ───────────────────────────────────────────────────────

libc = ctypes.CDLL("libc.so.6", use_errno=True)
IN_CLOSE_WRITE = 0x00000008
IN_MOVED_TO = 0x00000080
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


def _read_inotify(fd) -> list[str]:
    raw = os.read(fd, 4096)
    names = []
    offset = 0
    while offset < len(raw):
        wd, mask, cookie, length = _INOT_HDR.unpack_from(raw, offset)
        offset += _INOT_HDR_SIZE
        if length:
            name = (
                raw[offset : offset + length].rstrip(b"\x00").decode(errors="replace")
            )
            names.append(name)
        offset += length
    return names


# ─── X11 cursor position ──────────────────────────────────────────────────────


def get_screen_height() -> int:
    result = subprocess.run(["xdpyinfo"], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        if "dimensions:" in line:
            dims = line.split()[1]
            return int(dims.split("x")[1])
    return 1080


def get_cursor_y() -> int | None:
    result = subprocess.run(
        ["xdotool", "getmouselocation"], capture_output=True, text=True
    )
    for part in result.stdout.split():
        if part.startswith("y:"):
            try:
                return int(part[2:])
            except ValueError:
                return None
    return None


# ─── Dotfiles config ──────────────────────────────────────────────────────────


def load_dock_enabled() -> bool:
    if not DOTFILES_CONFIG.exists():
        return True
    for line in DOTFILES_CONFIG.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("DOCK_ENABLED="):
            val = line.split("=", 1)[1].strip().lower()
            return val != "false"
    return True


# ─── Eww helpers ──────────────────────────────────────────────────────────────


def eww_open():
    subprocess.run(["eww", "open", "dock-window"], capture_output=True)


def eww_close():
    subprocess.run(["eww", "close", "dock-window"], capture_output=True)


# ─── Main ─────────────────────────────────────────────────────────────────────


def run():
    socket_path = _get_socket_path()
    screen_height = get_screen_height()

    # Socket untuk subscribe events
    event_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    event_sock.connect(socket_path)
    _send(event_sock, MSG_SUBSCRIBE, '["window", "workspace"]')
    _, resp = _recv(event_sock)
    if not resp.get("success"):
        print("[dock-autohide] Gagal subscribe ke i3 events", file=sys.stderr)
        sys.exit(1)

    # Socket terpisah untuk query (get_tree, get_workspaces)
    query_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    query_sock.connect(socket_path)

    # inotify untuk config-dotfiles
    ifd = _inotify_init()
    if DOTFILES_CONFIG.parent.is_dir():
        _inotify_add_watch(
            ifd, str(DOTFILES_CONFIG.parent), IN_CLOSE_WRITE | IN_MOVED_TO
        )

    dock_visible = False
    last_near = False
    has_window = workspace_has_window(query_sock)
    dock_enabled = load_dock_enabled()

    # State awal
    if dock_enabled and not has_window:
        eww_open()
        dock_visible = True

    print("[dock-autohide] Aktif.", file=sys.stderr, flush=True)

    last_poll = 0.0

    while True:
        # Cek i3 events dan inotify — non-blocking
        readable, _, _ = select.select([event_sock, ifd], [], [], POLL_INTERVAL)

        for fd in readable:
            if fd == event_sock:
                msg_type, event = _recv(event_sock)
                if msg_type in (EVENT_WINDOW, EVENT_WORKSPACE):
                    has_window = workspace_has_window(query_sock)
                    print(
                        f"[dock-autohide] i3 event → has_window={has_window}",
                        file=sys.stderr,
                        flush=True,
                    )

            elif fd == ifd:
                names = _read_inotify(ifd)
                if DOTFILES_CONFIG.name in names:
                    dock_enabled = load_dock_enabled()
                    print(
                        f"[dock-autohide] Config berubah → dock_enabled={dock_enabled}",
                        file=sys.stderr,
                        flush=True,
                    )
                    if not dock_enabled and dock_visible:
                        eww_close()
                        dock_visible = False
                        last_near = False

        if not dock_enabled:
            if dock_visible:
                eww_close()
                dock_visible = False
                last_near = False
            continue

        # Mouse position — polling minimal via select timeout
        cursor_y = get_cursor_y()
        near_bottom = cursor_y is not None and cursor_y >= screen_height - THRESHOLD

        if near_bottom:
            if not dock_visible:
                eww_open()
                dock_visible = True
            last_near = True

        elif last_near:
            time.sleep(HIDE_DELAY)
            cursor_y = get_cursor_y()
            still_near = cursor_y is not None and cursor_y >= screen_height - THRESHOLD
            if not still_near and has_window:
                eww_close()
                dock_visible = False
            last_near = False

        else:
            if has_window and dock_visible:
                eww_close()
                dock_visible = False
            elif not has_window and not dock_visible:
                eww_open()
                dock_visible = True


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\n[dock-autohide] Dihentikan.", file=sys.stderr)
