#!/bin/bash
ID="$1"
NAME="$2"

CHOICE=$(echo -e "Cancel\nRemove" | rofi \
  -dmenu \
  -p "" \
  -mesg "Remove \"$NAME\" from dock?" \
  -l 2 \
  -theme ~/.config/rofi/dock-confirm.rasi)

[ "$CHOICE" = "Remove" ] && ~/.config/eww/scripts/remove-from-dock.sh "$ID" &
