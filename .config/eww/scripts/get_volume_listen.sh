#!/bin/bash

get_vol() {
    wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{printf "%.0f", $2 * 100}'
}

vol=$(get_vol)
echo "$vol"

while true; do
    new_vol=$(get_vol)
    if [ "$new_vol" != "$vol" ]; then
        echo "$new_vol"
        vol="$new_vol"
    fi
    sleep 0.1  # polling setiap 100ms - cukup responsif
done
