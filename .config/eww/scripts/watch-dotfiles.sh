#!/bin/bash
KEY="$1"

# Output nilai awal
grep -m1 "^${KEY}=" ~/.config/i3/config-dotfiles | cut -d'=' -f2

# Watch perubahan, output nilai baru setiap kali file berubah
while inotifywait -e close_write ~/.config/i3/config-dotfiles 2>/dev/null; do
  grep -m1 "^${KEY}=" ~/.config/i3/config-dotfiles | cut -d'=' -f2
done
