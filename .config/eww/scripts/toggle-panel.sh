#!/bin/bash

PANEL=$1

# Close panel lain dulu (bukan yang diminta)
[ "$PANEL" != "wifi_window" ] && eww close wifi_window 2>/dev/null
[ "$PANEL" != "bluetooth_window" ] && eww close bluetooth_window 2>/dev/null
[ "$PANEL" != "audio_window" ] && eww close audio_window 2>/dev/null
[ "$PANEL" != "control_center_window" ] && eww close control_center_window 2>/dev/null

# Daemon handling
if [ "$PANEL" = "wifi_window" ]; then
    pkill -f wifi_daemon.sh 2>/dev/null
    if ! eww active-windows | grep -q wifi_window; then
        eww update wifi_networks="$(~/.config/eww/scripts/scan_wifi.sh)"
        ~/.config/eww/scripts/wifi_daemon.sh &
    fi
fi

if [ "$PANEL" = "bluetooth_window" ]; then
    pkill -f bluetooth_daemon.sh 2>/dev/null
    if ! eww active-windows | grep -q bluetooth_window; then
        ~/.config/eww/scripts/bluetooth_daemon.sh &
    fi
fi

# Toggle panel yang diminta (buka kalau tutup, tutup kalau buka)
eww open --toggle $PANEL
