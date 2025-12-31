#!/bin/bash

# Lokasi file config i3
CONFIG="$HOME/.config/i3/config"
# Lokasi file tema rofi yang baru dibuat
THEME="$HOME/.config/rofi/keybinds.rasi"

# Mengambil keybinding
grep "^bindsym" "$CONFIG" | \
sed 's/bindsym //g' | \
sed 's/$mod/Super/g' | \
sed 's/--no-startup-id //g' | \
sed 's/--release //g' | \
sed 's/exec //g' | \
awk '{
    # Mengambil tombol (kolom 1)
    key=$1
    # Menghapus kolom 1 dari baris, sisanya adalah command
    $1=""
    # Print dengan format rapi: 
    # %-20s artinya kolom kiri (tombol) diberi jatah 20 karakter rata kiri
    # $0 adalah sisa baris (command)
    printf "%-25s  %s\n", key, $0
}' | \
rofi -dmenu -i -p " " -theme "$THEME"
