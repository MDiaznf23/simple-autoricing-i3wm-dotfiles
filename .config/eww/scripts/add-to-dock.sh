#!/bin/bash
NAME="$1"
APPS_JSON="$HOME/.config/eww/apps.json"
DOTFILES="$HOME/.config/i3/config-dotfiles"

MAX=$(grep "^MAX_DOCK_APPS=" "$DOTFILES" | cut -d'=' -f2)
MAX=${MAX:-10}  # fallback 10 kalau tidak ada

CURRENT=$(jq 'length' "$APPS_JSON")
if [ "$CURRENT" -ge "$MAX" ]; then
  notify-send "Dock" "Max $MAX apps in dock" --icon=dialog-warning
  exit 0
fi

# Guard duplikat
if jq -e --arg name "$NAME" 'any(.[]; .name == $name)' "$APPS_JSON" > /dev/null 2>&1; then
  exit 0
fi

TMP=$(mktemp)
jq --arg name "$NAME" '. += [{"name": $name}]' "$APPS_JSON" > "$TMP" && mv "$TMP" "$APPS_JSON"

