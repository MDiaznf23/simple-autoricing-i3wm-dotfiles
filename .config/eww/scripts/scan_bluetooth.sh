#!/bin/bash

# Pastikan bluetooth aktif
if ! bluetoothctl show | grep -q "Powered: yes"; then
    echo "[]"
    exit 0
fi

# Scan devices (timeout 3 detik)
timeout 3 bluetoothctl scan on &>/dev/null &
SCAN_PID=$!
sleep 3
kill $SCAN_PID 2>/dev/null
bluetoothctl scan off &>/dev/null

# Function untuk cek connected status (cek Device1 OR MediaControl1)
check_connected() {
    local mac="$1"
    local mac_formatted=$(echo "$mac" | tr ':' '_')

    # Cek Device1.Connected dulu
    local dev_conn=$(busctl get-property org.bluez /org/bluez/hci0/dev_$mac_formatted \
        org.bluez.Device1 Connected 2>/dev/null | awk '{print $2}')

    # Kalau true di Device level, langsung return
    if [ "$dev_conn" = "true" ]; then
        echo "true"
        return
    fi

    # Kalau false, cek MediaControl1.Connected (untuk audio devices)
    local media_conn=$(busctl get-property org.bluez /org/bluez/hci0/dev_$mac_formatted \
        org.bluez.MediaControl1 Connected 2>/dev/null | awk '{print $2}')

    if [ "$media_conn" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Array untuk menyimpan JSON
devices_json="["
first=true

while read -r line; do
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)

    # Skip jika nama kosong
    [ -z "$name" ] && continue

    # Check connected - GUNAKAN FUNCTION BARU
    connected=$(check_connected "$mac")

    # Check paired
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        paired="true"
    else
        paired="false"
    fi

    # Get device type
    dev_type=$(bluetoothctl info "$mac" 2>/dev/null | grep "Icon:" | awk '{print $2}')
    case "$dev_type" in
        *phone*|*mobile*) type_icon="phone";;
        *audio*|*headset*|*headphone*) type_icon="headphone";;
        *computer*) type_icon="computer";;
        *keyboard*) type_icon="keyboard";;
        *mouse*) type_icon="mouse";;
        *) type_icon="device";;
    esac

    # Escape name untuk JSON
    name_escaped=$(echo -n "$name" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g')

    # Build JSON
    if [ "$first" = false ]; then
        devices_json+=","
    fi
    devices_json+="{\"name\":\"$name_escaped\",\"mac\":\"$mac\",\"connected\":$connected,\"paired\":$paired,\"type\":\"$type_icon\"}"
    first=false
done < <(bluetoothctl devices 2>/dev/null | head -20)

devices_json+="]"

# Output JSON
echo "$devices_json"
