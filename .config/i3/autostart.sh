#!/bin/bash
# Autostart script for i3

# 1. System Settings 
# Mengatur layout keyboard setiap restart memastikan setting tetap aktif
setxkbmap -layout "us,ru" -option "grp:win_space_toggle" &

# 2. Wallpaper
~/.fehbg &

# 3. Compositor 
# Kill all existing compositors first
killall -q picom compton xcompmgr
while pgrep -x picom >/dev/null || pgrep -x compton >/dev/null; do
    sleep 0.1
done

if command -v picom &> /dev/null; then
    picom &
elif command -v compton &> /dev/null; then
    compton &
fi

# 4. Settings Daemon
pgrep -x xsettingsd > /dev/null || xsettingsd &

# 5. Widgets (Eww)
killall -q eww
eww daemon &

while ! eww ping &>/dev/null; do
    sleep 0.1
done

eww open bar &

pgrep -x dunst > /dev/null || dunst &

# 6. Monitor Scripts
pkill -f fullscreen-monitor
~/.config/eww/scripts/fullscreen-monitor.sh &

