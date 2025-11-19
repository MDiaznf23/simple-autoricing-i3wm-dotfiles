#!/bin/bash

# Kill proses lama dengan benar
pkill -x xsettingsd
pkill -x conky
killall -q polybar

# Tunggu proses benar-benar mati
sleep 0.8

# Generate rofi image
magick ~/.config/wpg/.current -resize 800x -quality 100 ~/.config/wpg/.current-rofi.jpg &

# Generate dunstrc
bash ~/.config/dunst/generate-dunstrc.sh &

# Tunggu sebentar biar file warna ke-generate dulu
sleep 0.3

# Start xsettingsd (hanya jika belum running)
pgrep -x xsettingsd > /dev/null || xsettingsd &

# Start polybar
polybar example 2>&1 | tee -a /tmp/polybar.log >/dev/null &

# Reload eww
eww reload &

# Reload i3 config
i3-msg reload &

# Start conky jika ada config
~/.config/conky/conky-wal.sh &

exit 0
