#!/bin/bash

POPUP_NAME="volume-popup"
TIMEOUT=3
PID_FILE="/tmp/eww-volume-popup.pid"

# Fungsi untuk close popup
close_popup() {
    eww close "$POPUP_NAME" 2>/dev/null
    rm -f "$PID_FILE"
}

# Kill timer lama jika ada
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    kill "$old_pid" 2>/dev/null
fi

# Buka popup jika belum ada
if ! eww active-windows | grep -q "$POPUP_NAME"; then
    eww open "$POPUP_NAME"
fi

# Start timer baru di background
(
    sleep "$TIMEOUT"
    close_popup
) &

# Simpan PID timer baru
echo $! > "$PID_FILE"
