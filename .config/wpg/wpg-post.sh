#!/bin/bash
# Generate rofi image
magick ~/.config/wpg/.current -resize 800x -quality 100 ~/.config/wpg/.current-rofi.jpg &

# Restart polybar di background
(
  killall -q polybar
  sleep 0.5
  polybar example 2>&1 | tee -a /tmp/polybar.log >/dev/null &
) &

bash ~/.config/dunst/generate-dunstrc.sh &

# Reload eww setelah pywal generate warna baru
eww reload &

pgrep -x xsettingsd > /dev/null || xsettingsd &

# Reload i3 config
i3-msg reload &

exit 0
