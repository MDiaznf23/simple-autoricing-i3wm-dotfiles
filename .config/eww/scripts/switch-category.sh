#!/bin/bash
CATEGORY="${1:-Internet}"
APPS=$(~/.config/eww/scripts/filter-apps.sh "$CATEGORY")
eww update menu_active_cat="$CATEGORY"
eww update active_apps="$APPS"
