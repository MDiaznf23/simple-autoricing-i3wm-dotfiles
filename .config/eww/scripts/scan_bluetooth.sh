#!/bin/bash

# Pastikan bluetooth aktif
if ! bluetoothctl show | grep -q "Powered: yes"; then
    echo "[]"
    exit 0
fi

# Scan devices (timeout 3 detik) - KURANGI dari 5 detik
timeout 3 bluetoothctl scan on &>/dev/null &
SCAN_PID=$!
sleep 3
kill $SCAN_PID 2>/dev/null
bluetoothctl scan off &>/dev/null  # Stop scan

# Function untuk escape JSON string dengan benar
json_escape() {
    # Encode ke base64 untuk avoid semua masalah encoding
    echo -n "$1" | base64 -w0
}

# Function untuk create JSON value dengan proper escaping
json_value() {
    local key="$1"
    local value="$2"
    printf '"%s":"%s"' "$key" "$(json_escape "$value")"
}

# Array untuk menyimpan JSON
devices_json="["
first=true

while read -r line; do
    mac=$(echo "$line" | awk '{print $2}')
    name=$(echo "$line" | cut -d' ' -f3-)
    
    # Skip jika nama kosong
    [ -z "$name" ] && continue
    
    # Check connected
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
        connected="true"
    else
        connected="false"
    fi
    
    # Check paired
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        paired="true"
    else
        paired="false"
    fi
    
    # Get device type - GUNAKAN TEXT BIASA, bukan emoji
    dev_type=$(bluetoothctl info "$mac" 2>/dev/null | grep "Icon:" | awk '{print $2}')
    case "$dev_type" in
        *phone*|*mobile*) type_icon="phone";;
        *audio*|*headset*|*headphone*) type_icon="headphone";;
        *computer*) type_icon="computer";;
        *keyboard*) type_icon="keyboard";;
        *mouse*) type_icon="mouse";;
        *) type_icon="device";;
    esac
    
    # Escape name untuk JSON dengan proper method
    name_escaped=$(echo -n "$name" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g')
    
    # Build JSON - SIMPLE format tanpa icon emoji
    if [ "$first" = false ]; then
        devices_json+=","
    fi
    devices_json+="{\"name\":\"$name_escaped\",\"mac\":\"$mac\",\"connected\":$connected,\"paired\":$paired,\"type\":\"$type_icon\"}"
    first=false
done < <(bluetoothctl devices 2>/dev/null | head -20)  # Limit 20 devices

devices_json+="]"

# Output JSON
echo "$devices_json"
