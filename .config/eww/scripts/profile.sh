#!/bin/bash
# Script Information

# SETTINGS
IMAGE_URL="file:///home/$USER/.config/eww/assets/profile.jpg"

case "$1" in
    username)
        # Mendapatkan username
        echo "$USER"
        ;;
    
    wm)
        # Mendapatkan Window Manager yang sedang berjalan
        # Cek berbagai WM yang umum
        if pgrep -x "i3" > /dev/null; then
            echo "i3"
        elif pgrep -x "bspwm" > /dev/null; then
            echo "bspwm"
        elif pgrep -x "awesome" > /dev/null; then
            echo "awesome"
        elif pgrep -x "dwm" > /dev/null; then
            echo "dwm"
        elif pgrep -x "qtile" > /dev/null; then
            echo "qtile"
        elif pgrep -x "xmonad" > /dev/null; then
            echo "xmonad"
        elif pgrep -x "openbox" > /dev/null; then
            echo "openbox"
        elif pgrep -x "herbstluftwm" > /dev/null; then
            echo "herbstluftwm"
        elif [ "$XDG_CURRENT_DESKTOP" ]; then
            echo "$XDG_CURRENT_DESKTOP"
        else
            echo "Unknown"
        fi
        ;;
    
    uptime)
        # Mendapatkan uptime dalam format yang lebih readable
        uptime -p | sed 's/up //'
        ;;
    
    uptime-short)
        # Format uptime yang lebih singkat (contoh: 2h 30m)
        uptime -p | sed 's/up //' | sed 's/ hours/h/' | sed 's/ hour/h/' | sed 's/ minutes/m/' | sed 's/ minute/m/' | sed 's/,//'
        ;;
    
    image-url)
        # Output URL image profile
        echo "$IMAGE_URL"
        ;;
    
    *)
        echo "Usage: $0 {username|wm|uptime|uptime-short|image-url}"
        exit 1
        ;;
esac
