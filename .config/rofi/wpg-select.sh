#!/bin/bash

# --- Konfigurasi ---
WALLPAPER_DIR="$HOME/.config/wpg/wallpapers"
CACHE_DIR="$HOME/.cache/wpg-rofi-thumbs"
THEME_FILE="$HOME/.config/rofi/wallpaper-select.rasi" # Pastikan path ini benar

# Buat direktori cache jika belum ada
mkdir -p "$CACHE_DIR"

# Pindah ke direktori wallpaper agar find path relative bekerja dengan baik
cd "$WALLPAPER_DIR" || { echo "Directory not found"; exit 1; }

# --- Fungsi Generator Thumbnail ---
generate_thumb() {
    local img="$1"
    
    # Membuat hash nama file agar unik dan aman (md5sum)
    # Ini mencegah error jika nama file wallpaper mengandung spasi atau karakter aneh
    local hash_name=$(echo -n "$img" | md5sum | awk '{print $1}')
    local thumb="$CACHE_DIR/$hash_name.jpg"
    
    # Hanya generate jika file thumbnail belum ada atau ukurannya 0
    if [ ! -s "$thumb" ]; then
        # Menggunakan magick untuk resize, crop square (150x150), dan strip metadata agar ringan
        magick "$img" -resize 300x300^ -gravity center -extent 300x300 -quality 80 -strip "$thumb" 2>/dev/null
    fi
    echo "$thumb"
}
export -f generate_thumb
export CACHE_DIR

# --- Persiapan Data untuk Rofi ---
# Menggunakan Parallel processing sederhana untuk generate thumb lebih cepat
# Kita mencari file image asli atau symlink
find . -maxdepth 1 \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | sort -z | \
while IFS= read -r -d '' file; do
    # Hapus './' di depan nama file
    clean_name="${file#./}"
    
    # Generate thumb (proses ini bisa lambat jika pertama kali, jadi kita jalankan langsung di sini)
    # Jika ingin super cepat, bisa diparallelkan dengan xargs, tapi bash loop lebih aman untuk logic rofi
    thumb_path=$(generate_thumb "$clean_name")
    
    # Format string untuk Rofi:
    # NamaFile \0icon\x1f PathThumbnail
    echo -en "${clean_name}\0icon\x1f${thumb_path}\n"
done > "$CACHE_DIR/rofi_list_cache"

# --- Eksekusi Rofi ---
# Membaca list dari cache file yang baru dibuat
SELECTED=$(cat "$CACHE_DIR/rofi_list_cache" | rofi -dmenu -i \
    -p " " \
    -show-icons \
    -theme "$THEME_FILE")

# --- Eksekusi WPG ---
if [ -n "$SELECTED" ]; then
    # Jalankan WPG
    wpg -s "$WALLPAPER_DIR/$SELECTED"
fi
