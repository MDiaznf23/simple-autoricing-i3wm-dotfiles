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

# Track active window and monitor its title changes
xprop -spy -root _NET_ACTIVE_WINDOW | while read -r line; do
    # Get window ID from the root property
    window_id=$(echo "$line" | awk '{print $NF}' | tr -d ',')
    
    # Skip if no valid window
    if [ "$window_id" = "0x0" ]; then
        format_title ""
        continue
    fi
    
    # Kill previous xprop spy if exists
    if [ ! -z "$WATCH_PID" ]; then
        kill "$WATCH_PID" 2>/dev/null
    fi
    
    # Get initial title
    title=$(xdotool getwindowname "$window_id" 2>/dev/null)
    format_title "$title"
    
    # Watch for WM_NAME changes on this specific window
    xprop -spy -id "$window_id" _NET_WM_NAME WM_NAME 2>/dev/null | while read -r prop; do
        title=$(xdotool getwindowname "$window_id" 2>/dev/null)
        format_title "$title"
    done &
    WATCH_PID=$!
done
