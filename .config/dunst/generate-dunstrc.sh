#!/bin/bash
# Load warna dari script colors.sh
source ~/.cache/m3-colors/colors.sh

# Pastikan direktori config ada
mkdir -p ~/.config/dunst

cat > ~/.config/dunst/dunstrc << EOF
[global]
    # --- DISPLAY & GEOMETRY ---
    monitor = 0
    follow = mouse
    # Format: (min_width, max_width), (min_height, max_height)
    width = (290, 310)
    height = (30, 60)
    
    origin = top-right
    offset = (15, 52)
    
    # Scale & Progress Bar
    notification_limit = 5
    progress_bar = true
    progress_bar_height = 4
    progress_bar_frame_width = 0
    progress_bar_min_width = 150
    progress_bar_max_width = 300

    # --- LOOK & FEEL (Material 3 Style) ---
    font = Noto Sans 10
    
    markup = full
    format = "<b>%s</b>\n<span font_desc='JetBrains Mono Nerd Font 9'>%b</span>"
    
    # Spacing
    padding = 10
    horizontal_padding = 10
    text_icon_padding = 10
    gap_size = 8
    
    # Borders & Radius
    frame_width = 2
    frame_color = "$outline"
    separator_color = "frame"
    corner_radius = 10

    # Icons
    icon_position = left
    min_icon_size = 48
    max_icon_size = 48
    enable_recursive_icon_lookup = true
    icon_theme = Adwaita

    # --- TEXT HANDLING ---
    ellipsize = end
    ignore_newline = no
    stack_duplicates = true
    show_indicators = yes

    # --- MOUSE INTERACTION ---
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[urgency_low]
    # Surface Dim untuk low urgency
    background = "$surface"
    foreground = "$on_surface_variant"
    frame_color = "$outline_variant"
    timeout = 4

[urgency_normal]
    # Surface Container High (Warna standar M3 untuk dialog/popup)
    background = "$surface"
    foreground = "$on_surface"
    frame_color = "$primary_container"
    timeout = 8

[urgency_critical]
    # Error Container (Merah M3) untuk critical
    background = "$error_container"
    foreground = "$on_error_container"
    frame_color = "$error"
    timeout = 0
EOF

# Restart dunst untuk menerapkan perubahan
killall dunst

