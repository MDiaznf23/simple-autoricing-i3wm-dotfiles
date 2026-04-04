#!/usr/bin/env bash
FILE="$HOME/.cache/eww-dock.json"
last_hash=""

while true; do
  if [ -f "$FILE" ]; then
    current_hash=$(md5sum "$FILE" | cut -d' ' -f1)
    if [ "$current_hash" != "$last_hash" ]; then
      cat "$FILE" | tr -d '\n'
      echo
      last_hash="$current_hash"
    fi
  fi
  sleep 1
done
