#!/bin/bash

# Fungsi untuk cek apakah ada window aplikasi yang fullscreen
is_fullscreen() {
    fullscreen_count=$(i3-msg -t get_tree 2>/dev/null | jq '[.. | select(.window? != null and .fullscreen_mode? == 1)] | length' 2>/dev/null)
    
    if [ "$fullscreen_count" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# Loop terus menerus
prev_state="not_fullscreen"

while true; do
    if is_fullscreen; then
        current_state="fullscreen"
        if [ "$prev_state" != "fullscreen" ]; then
            eww close bar 2>/dev/null
            prev_state="fullscreen"
        fi
    else
        current_state="not_fullscreen"
        if [ "$prev_state" != "not_fullscreen" ]; then
            eww open bar 2>/dev/null
            prev_state="not_fullscreen"
        fi
    fi
    
    sleep 0.3
done
