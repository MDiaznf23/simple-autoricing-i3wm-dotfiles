#!/bin/bash
dirs=(
  "$HOME/.local/share/icons"
  "/usr/share/icons"
)

themes=()
for dir in "${dirs[@]}"; do
  [ -d "$dir" ] || continue
  for theme_dir in "$dir"/*/; do
    index="$theme_dir/index.theme"
    [ -f "$index" ] || continue
    # Skip cursor themes
    grep -q "Directories=" "$index" || continue
    grep -qi "cursors" "$theme_dir" && continue
    name=$(grep -m1 "^Name=" "$index" | cut -d'=' -f2 | tr -d '[:space:]')
    dirname=$(basename "$theme_dir")
    [ -n "$name" ] && themes+=("$dirname")
  done
done

# Deduplikasi dan sort, output JSON array
printf '%s\n' "${themes[@]}" | sort -u | jq -R . | jq -sc .
