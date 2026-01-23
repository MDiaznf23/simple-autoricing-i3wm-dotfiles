#!/bin/bash

# Cari path backlight (biasanya intel_backlight atau amdgpu_bl0)
# Kita ambil yang pertama ditemukan
BL_DIR=$(ls -d /sys/class/backlight/* | head -n 1)

get_bright() {
    brightnessctl g 2>/dev/null | awk -v max=$(brightnessctl m 2>/dev/null) '{print int($1/max*100)}'
}

# 1. Print brightness awal
get_bright

# 2. Monitor perubahan pada file 'brightness' atau 'actual_brightness' di sistem
# Script ini akan diam (sleep) sampai file berubah
inotifywait -m -e close_write "$BL_DIR/brightness" 2>/dev/null | while read -r _; do
    get_bright
done
