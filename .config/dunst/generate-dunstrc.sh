#!/bin/bash
source ~/.cache/wal/colors.sh

cat > ~/.config/dunst/dunstrc << EOF
[global]
    script = ~/.config/polybar/scripts/dunst-update.sh
    icon_theme = Adwaita
    enable_recursive_icon_lookup = true
    font = Monospace 10
    markup = full
    format = "<b>%s</b>\n%b"
    
    origin = top-right
    offset = 15x52
    
    frame_width = 0
    separator_height = 2
    separator_color = "$color1"
    
    corner_radius = 8
    padding = 12
    horizontal_padding = 12
    
    width = (280, 350)
    
    transparency = 0
    gap_size = 6
    
    icon_position = left
    max_icon_size = 48

[urgency_low]
    background = "${background}CC"
    foreground = "$foreground"
    highlight = "$color1"
    timeout = 5

[urgency_normal]
    background = "${background}CC"
    foreground = "$foreground"
    highlight = "$color2"
    timeout = 10

[urgency_critical]
    background = "${color1}CC"
    foreground = "$background"
    highlight = "$background"
    timeout = 0
EOF

killall dunst
