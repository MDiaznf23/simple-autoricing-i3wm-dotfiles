#!/bin/bash

# Fungsi untuk mengambil volume saat ini
get_vol() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep 'Volume:' | head -n1 | awk '{print $5}' | tr -d '%'
}

# Simpan volume terakhir
last_vol=$(get_vol)
echo "$last_vol"

# Background polling setiap 0.5 detik sebagai safety net
(
    while true; do
        sleep 0.5
        current=$(get_vol)
        if [ "$current" != "$last_vol" ]; then
            echo "$current"
            last_vol="$current"
        fi
    done
) &
polling_pid=$!

# Main listener dari pactl subscribe
pactl subscribe 2>/dev/null | grep --line-buffered "Event 'change' on sink" | while read -r _; do
    current_vol=$(get_vol)
    if [ "$current_vol" != "$last_vol" ]; then
        echo "$current_vol"
        last_vol="$current_vol"
    fi
done

# Cleanup jika listener mati
kill $polling_pid 2>/dev/null
