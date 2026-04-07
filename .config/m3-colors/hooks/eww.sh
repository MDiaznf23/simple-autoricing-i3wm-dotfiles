#!/bin/bash
eww_dir="$HOME/.config/eww"
cp "$eww_dir/eww-$M3_MODE.scss" "$eww_dir/eww.scss"

# Tentukan target theme
if [[ "$M3_MODE" == "dark" ]]; then
    target="light"
else
    target="dark"
fi

# Retry sampai value benar (maksimal 10x)
for i in $(seq 1 10); do
    eww update icon-theme="$target"
    sleep 0.3
    current=$(eww get icon-theme)
    if [[ "$current" == "$target" ]]; then
        break
    fi
done
