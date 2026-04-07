#!/bin/bash

MAC="$1"
ACTION="${2:-toggle}"

if [ -z "$MAC" ]; then
    exit 1
fi

case "$ACTION" in
    connect)
        bluetoothctl connect "$MAC"
        ;;
    disconnect)
        bluetoothctl disconnect "$MAC"
        ;;
    toggle)
        if bluetoothctl info "$MAC" | grep -q "Connected: yes"; then
            bluetoothctl disconnect "$MAC"
        else
            # Pair dulu jika belum paired
            if ! bluetoothctl info "$MAC" | grep -q "Paired: yes"; then
                bluetoothctl pair "$MAC"
                sleep 2
            fi
            bluetoothctl connect "$MAC"
        fi
        ;;
    pair)
        bluetoothctl pair "$MAC"
        ;;
    unpair)
        bluetoothctl remove "$MAC"
        ;;
esac

# Refresh list setelah action
sleep 1
eww update bluetooth_devices_listen="$(~/.config/eww/scripts/scan_bluetooth.sh)"
