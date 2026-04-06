#!/usr/bin/env python3
"""
fullscreen-monitor.py — Monitor fullscreen via i3 IPC events
Zero polling: hanya trigger saat ada window event dari i3
"""

import json
import os
import socket
import struct
import subprocess
import sys
from pathlib import Path

# ─── i3 IPC ───────────────────────────────────────────────────────────────────

MAGIC = b"i3-ipc"
HDR = struct.Struct("=6sII")
HDR_SIZE = HDR.size  # 14 bytes

MSG_SUBSCRIBE = 2
MSG_GET_TREE = 4
EVENT_WINDOW = 0x80000003


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


def is_fullscreen(sock: socket.socket) -> bool:
    _send(sock, MSG_GET_TREE)
    _, tree = _recv(sock)
    return _count_fullscreen(tree) > 0


def _count_fullscreen(node: dict) -> int:
    count = 0
    if node.get("window") is not None and node.get("fullscreen_mode") == 1:
        count += 1
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        count += _count_fullscreen(child)
    return count


# ─── Main ─────────────────────────────────────────────────────────────────────


def run():
    socket_path = _get_socket_path()
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(socket_path)

    # Subscribe ke window events
    _send(sock, MSG_SUBSCRIBE, '["window"]')
    _, resp = _recv(sock)
    if not resp.get("success"):
        print("[fullscreen-monitor] Gagal subscribe ke i3 events", file=sys.stderr)
        sys.exit(1)

    print(
        "[fullscreen-monitor] Aktif, menunggu window events...",
        file=sys.stderr,
        flush=True,
    )

    # Cek state awal
    check_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    check_sock.connect(socket_path)

    prev_state = None

    while True:
        msg_type, event = _recv(sock)

        if msg_type != EVENT_WINDOW:
            continue

        # Hanya proses event yang relevan
        change = event.get("change", "")
        if change not in ("fullscreen_mode", "focus", "close", "new"):
            continue

        current = is_fullscreen(check_sock)

        if current == prev_state:
            continue

        prev_state = current

        if current:
            print(
                "[fullscreen-monitor] Fullscreen terdeteksi → tutup bar",
                file=sys.stderr,
                flush=True,
            )
            subprocess.run(["eww", "close", "bar"], capture_output=True)
        else:
            print(
                "[fullscreen-monitor] Kembali normal → buka bar",
                file=sys.stderr,
                flush=True,
            )
            subprocess.run(["eww", "open", "bar"], capture_output=True)


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\n[fullscreen-monitor] Dihentikan.", file=sys.stderr)
