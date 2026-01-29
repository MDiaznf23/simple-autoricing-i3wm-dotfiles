#!/bin/bash

# Function untuk get brightness percentage
get_brightness() {
    brightnessctl get | awk -v max=$(brightnessctl max) '{print int($1*100/max)}'
}

# Output brightness pertama kali
get_brightness

# Monitor perubahan file brightness dengan inotifywait
inotifywait -m -e modify /sys/class/backlight/*/brightness 2>/dev/null | while read -r; do
    get_brightness
done
