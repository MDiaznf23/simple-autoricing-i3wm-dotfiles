#!/bin/bash
ID="$1"
APPS_JSON="$HOME/.config/eww/apps.json"

TMP=$(mktemp)
jq --arg id "$ID" '[.[] | select(.name != $id)]' "$APPS_JSON" > "$TMP" && mv "$TMP" "$APPS_JSON"

BEFORE=$(md5sum "$HOME/.cache/eww-dock.json" | cut -d' ' -f1)

# Tunggu sampai file berubah, max 5 detik
for i in $(seq 1 10); do
  sleep 0.5
  AFTER=$(md5sum "$HOME/.cache/eww-dock.json" | cut -d' ' -f1)
  if [ "$BEFORE" != "$AFTER" ]; then
    break
  fi
done

eww close dock-window && sleep 1.0 && eww open dock-window && eww close dock-window && sleep 1.0 && eww open dock-window
