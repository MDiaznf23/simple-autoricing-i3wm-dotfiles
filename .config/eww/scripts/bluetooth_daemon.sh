#!/bin/bash

ADAPTER="/org/bluez/hci0"

start_discovery() {
    busctl --system call org.bluez "$ADAPTER" \
        org.bluez.Adapter1 StartDiscovery 2>/dev/null
}

stop_discovery() {
    busctl --system call org.bluez "$ADAPTER" \
        org.bluez.Adapter1 StopDiscovery 2>/dev/null
}

update_list() {
    RESULT=$(~/.config/eww/scripts/scan_bluetooth.sh)
    eww update bluetooth_devices_listen="$RESULT"
}

trap 'stop_discovery; exit' EXIT INT TERM

start_discovery
update_list

while eww active-windows | grep -q bluetooth_window; do
    sleep 2
    update_list
done
