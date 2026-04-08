#!/bin/bash
# Autostart script for i3

# 1. System Settings 
setxkbmap -layout "us,ru" -option "grp:win_space_toggle" &

# 2. Notification Daemon (harus duluan sebelum yang lain)
pgrep -x dunst > /dev/null || dunst &
sleep 0.3

# 3. Wallpaper
~/.fehbg &

# 4. Compositor 
killall -q picom compton xcompmgr
while pgrep -x picom >/dev/null || pgrep -x compton >/dev/null || pgrep -x xcompmgr >/dev/null; do
    sleep 0.1
done

if command -v picom &> /dev/null; then
    picom &
elif command -v compton &> /dev/null; then
    compton &
fi

# 6. Settings Daemon
pgrep -x xsettingsd > /dev/null || xsettingsd &

# 7. Widgets (Eww)
killall eww 2>/dev/null
eww daemon
while ! eww ping &>/dev/null; do sleep 0.1; done
eww open bar

# 8. Monitor Scripts
pkill -f fullscreen-monitor
python3 ~/.config/eww/scripts/fullscreen-monitor.py &

pkill -f dock-autohide
python3 ~/.config/eww/scripts/dock-autohide.py &
