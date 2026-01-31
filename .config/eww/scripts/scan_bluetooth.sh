#!/bin/bash

# Bluetooth Device List - Cache-Only Version (FAST & BATTERY FRIENDLY)

# Check if bluetooth is powered
if ! bluetoothctl show | grep -q "Powered: yes"; then
    echo "[]"
    exit 0
fi

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

# Array untuk JSON
devices_json="["
first=true

# Read devices dari cache (FAST - no scan!)
while read -r line; do
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)
    
    # Skip jika nama kosong
    [ -z "$name" ] && continue
    
    # OPTIMASI: Call bluetoothctl info SEKALI saja, simpan hasil
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    
    # Parse semua data dari info yang sudah di-cache
    connected=$(check_connected "$mac")  
    paired=$(echo "$info" | grep -q "Paired: yes" && echo "true" || echo "false")
    dev_type=$(echo "$info" | grep "Icon:" | awk '{print $2}')
    
    # Determine type icon (format sama dengan script asli)
    case "$dev_type" in
        *phone*|*mobile*) type_icon="phone";;
        *audio*|*headset*|*headphone*) type_icon="headphone";;
        *computer*) type_icon="computer";;
        *keyboard*) type_icon="keyboard";;
        *mouse*) type_icon="mouse";;
        *) type_icon="device";;
    esac
    
    # Escape name untuk JSON
    name_escaped=$(echo -n "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # Build JSON
    if [ "$first" = false ]; then
        devices_json+=","
    fi
    devices_json+="{\"name\":\"$name_escaped\",\"mac\":\"$mac\",\"connected\":$connected,\"paired\":$paired,\"type\":\"$type_icon\"}"
    first=false
    
done < <(bluetoothctl devices 2>/dev/null)

devices_json+="]"

echo "$devices_json"
