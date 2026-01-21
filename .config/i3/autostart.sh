#!/bin/bash
# Autostart script for i3
# Set wallpaper
~/.fehbg &

# Kill all existing compositors first
killall -q picom compton xcompmgr
while pgrep -x picom >/dev/null || pgrep -x compton >/dev/null; do
    sleep 0.1
done

# Start compositor
if command -v picom &> /dev/null; then
    picom &
elif command -v compton &> /dev/null; then
    compton &
fi

# Start xsettingsd
pgrep -x xsettingsd > /dev/null || xsettingsd &

# Start eww dengan cara yang BENAR
killall -q eww
eww daemon &

# Tunggu sampai daemon benar-benar ready dengan eww ping
while ! eww ping &>/dev/null; do
    sleep 0.1
done

# Sekarang daemon sudah ready, buka bar
eww open bar &

# Kill existing fullscreen monitor
pkill -f fullscreen-monitor

# Start fullscreen monitor (tanpa handle eww daemon lagi)
~/.config/eww/scripts/fullscreen-monitor.sh &
