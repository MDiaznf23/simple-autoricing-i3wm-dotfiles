#!/bin/bash
# ~/.config/polybar/scripts/xwindow-clickable.sh

# Get active window title
window_title=$(xdotool getactivewindow getwindowname 2>/dev/null)

# Truncate to max 50 characters
if [ -z "$window_title" ]; then
    echo "Desktop"
else
    # Truncate and add ellipsis if needed
    if [ ${#window_title} -gt 50 ]; then
        echo "${window_title:0:50}..."
    else
        echo "$window_title"
    fi
fi
