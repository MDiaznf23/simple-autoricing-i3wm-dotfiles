#!/bin/bash
# ~/.config/eww/scripts/xwindow-clickable.sh

format_title() {
    local title="$1"
    if [ -z "$title" ]; then
        echo "Desktop"
    else
        if [ ${#title} -gt 25 ]; then
            echo "${title:0:25}..."
        else
            echo "$title"
        fi
    fi
}

xprop -spy -root _NET_ACTIVE_WINDOW | while read -r line; do
    window_id=$(echo "$line" | awk '{print $NF}' | tr -d ',')
    
    if [ "$window_id" = "0x0" ]; then
        format_title ""
        continue
    fi
    
    if [ ! -z "$WATCH_PID" ]; then
        kill "$WATCH_PID" 2>/dev/null
    fi

    # Cek apakah window adalah eww
    wm_class=$(xprop -id "$window_id" WM_CLASS 2>/dev/null)
    if echo "$wm_class" | grep -qi "eww"; then
        echo "Desktop"
        continue
    fi
    
    title=$(xdotool getwindowname "$window_id" 2>/dev/null)
    format_title "$title"
    
    xprop -spy -id "$window_id" _NET_WM_NAME WM_NAME 2>/dev/null | while read -r prop; do
        title=$(xdotool getwindowname "$window_id" 2>/dev/null)
        format_title "$title"
    done &
    WATCH_PID=$!
done
