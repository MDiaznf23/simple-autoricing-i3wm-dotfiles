#!/bin/bash
eww_dir="$HOME/.config/eww"
cp "$eww_dir/eww-$M3_MODE.scss" "$eww_dir/eww.scss"

# Tulis ke file, bukan eww update
if [[ "$M3_MODE" == "dark" ]]; then
    echo "light" > "$eww_dir/.icon-theme"
else
    echo "dark" > "$eww_dir/.icon-theme"
fi
