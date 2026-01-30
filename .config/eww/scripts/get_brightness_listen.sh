#!/bin/bash

# Script untuk eww deflisten brightness 

# Cache max brightness sekali di awal (tidak berubah-ubah)
MAX_BRIGHTNESS=$(brightnessctl max)

get_brightness() {
    brightnessctl get | awk -v max="$MAX_BRIGHTNESS" '{print int($1*100/max)}'
}

# Output brightness awal
brightness=$(get_brightness)
echo "$brightness"
last_brightness="$brightness"

# Throttle configuration
THROTTLE=${THROTTLE:-1}
counter=0

# Monitor brightness changes
inotifywait -m -q -e modify /sys/class/backlight/*/brightness 2>/dev/null | \
while read -r _; do
    ((counter++))
    if (( counter % THROTTLE == 0 )); then
        brightness=$(get_brightness)
        if [ "$brightness" != "$last_brightness" ]; then
            echo "$brightness"
            last_brightness="$brightness"
        fi
    fi
done
