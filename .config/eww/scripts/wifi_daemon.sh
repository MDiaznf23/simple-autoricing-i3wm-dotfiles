#!/bin/bash

DEVICE=$(nmcli -t -f DEVICE,TYPE dev | grep ':wifi' | cut -d: -f1 | head -1)
DEVICE_PATH=$(nmcli -t -f GENERAL.UDI device show "$DEVICE" 2>/dev/null | grep -oP '/org/freedesktop/NetworkManager/Devices/\d+')

request_scan() {
    busctl --system call \
        org.freedesktop.NetworkManager \
        "$DEVICE_PATH" \
        org.freedesktop.NetworkManager.Device.Wireless \
        RequestScan "a{sv}" 0 2>/dev/null
}

update_list() {
    RESULT=$(~/.config/eww/scripts/scan_wifi.sh)
    eww update wifi_networks="$RESULT"
}

request_scan
sleep 1.5
update_list

while eww active-windows | grep -q wifi_window; do
    sleep 10
    request_scan
    sleep 1.5
    update_list
done
