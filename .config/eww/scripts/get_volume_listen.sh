#!/bin/bash

# Fungsi untuk mengambil volume saat ini
get_vol() {
    pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep 'Volume:' | head -n1 | awk '{print $5}' | tr -d '%'
}

# 1. Print volume saat script pertama jalan (agar slider tidak 0 di awal)
get_vol

# 2. Jalan loop listener
# 'pactl subscribe' akan diam sampai ada event audio.
# Kita filter hanya event 'change' pada 'sink' (output device).
pactl subscribe | grep --line-buffered "Event 'change' on sink" | while read -r _; do
    get_vol
done
