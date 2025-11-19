#!/bin/bash
# ~/.config/conky/conky-wal.sh

# Ambil warna dari wal
COLOR=$(sed -n "16p" ~/.cache/wal/colors | tr -d "#")

# Jalankan conky dengan warna dinamis
conky -c <(cat <<EOF
conky.config = {
    alignment = 'top_middle',
    gap_x = 0,
    gap_y = 100,
    
    own_window = true,
    own_window_type = 'override',
    own_window_class = 'Conky',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    
    double_buffer = true,
    use_xft = true,
    xftalpha = 0.9,
    
    font = 'JetBrainsMono Nerd Font:bold:size=40',
    update_interval = 1.0,
    
    default_color = '$COLOR',
    draw_shades = true,
    draw_borders = false,
    draw_outline = false,
    draw_graph_borders = false,

    minimum_width = 200,
    minimum_height = 200,
}

conky.text = [[
\${alignc}\${font JetBrainsMono Nerd Font:bold:size=55}\${time %H:%M}\${font}
\${voffset -40}\${alignc}\${font JetBrainsMono Nerd Font:normal:size=14}\${time %A, %B %d}\${font}
]]
EOF
)
