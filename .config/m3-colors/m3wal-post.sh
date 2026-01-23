#!/bin/bash

# Kill proses lama dengan benar
pkill -x xsettingsd

# Tunggu proses benar-benar mati
sleep 0.8

# Generate rofi image
magick ~/.config/m3-colors/current_wallpaper -resize 800x -quality 100 ~/.config/m3-colors/current-rofi.jpg &

# Generate dunstrc
bash ~/.config/dunst/generate-dunstrc.sh &

# Tunggu sebentar biar file warna ke-generate dulu
sleep 0.3

# Start xsettingsd (hanya jika belum running)
pgrep -x xsettingsd > /dev/null || xsettingsd &

# Tambahkan ini di wallpaper generator script setelah generate custom.lua
nvim --headless -c "lua require('base46').compile()" -c "qa"

# Reload eww
eww reload &

# Reload i3 config
i3-msg reload &

exit 0

