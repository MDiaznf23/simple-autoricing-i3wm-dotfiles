#!/bin/bash

# --- FUNGSI COVER ART ---
get_cover() {
    local player="$1"
    local art_url="$2"
    local music_file="$3"
    
    local cover_cache="/tmp/mpd_cover.jpg"
    local default_cover="$HOME/.config/eww/assets/default-cover.jpg"

    # 1. Cek artUrl (Spotify/Firefox)
    # Hapus file:// prefix
    clean_url=$(echo "$art_url" | sed 's|^file://||')
    
    if [ -n "$clean_url" ] && [ -s "$clean_url" ]; then
        echo "$clean_url"
        return
    fi

    # 2. Cek Local File (MPD)
    clean_file=$(echo "$music_file" | sed 's|^file://||')
    
    if [ -z "$clean_file" ]; then
        echo "$default_cover"
        return
    fi

    music_dir=$(dirname "$clean_file")

    # 3. Cari cover.jpg/folder.jpg
    local_cover=$(find "$music_dir" -maxdepth 1 \( -iname "cover.jpg" -o -iname "folder.jpg" \) 2>/dev/null | head -n1)
    if [ -n "$local_cover" ]; then
        echo "$local_cover"
        return
    fi

    # 4. Extract embedded cover (FFMPEG) - Hanya jalan kalau file berubah
    # Kita cek dulu apakah cache sudah sesuai dengan file musik ini (opsional, tapi biar simpel kita overwrite saja demi akurasi)
    if ffmpeg -i "$clean_file" -an -vcodec copy "$cover_cache" -y -loglevel quiet; then
        if [ -s "$cover_cache" ]; then
            echo "$cover_cache"
            return
        fi
    fi

    echo "$default_cover"
}

# --- LOOP LISTENER UTAMA ---
# Kita minta playerctl memberikan semua data sekaligus dalam format raw text yang dipisah |
# Format: PLAYER | STATUS | TITLE | ARTIST | ART_URL | FILE_PATH

playerctl metadata --format '{{playerName}}|{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{xesam:url}}' -F 2>/dev/null | while read -r line; do
    
    # Jika tidak ada player aktif, line mungkin kosong atau error
    if [ -z "$line" ]; then
        echo '{"title": "No Media", "artist": "Offline", "status": "Stopped", "player": "", "cover": ""}'
        continue
    fi

    # Parsing variabel dari string yang dipisah "|"
    # IFS (Internal Field Separator) digunakan untuk memecah string
    IFS='|' read -r player status title artist art_url file_path <<< "$line"

    # Jalankan fungsi get_cover hanya saat event terjadi (HEMAT CPU)
    cover_path=$(get_cover "$player" "$art_url" "$file_path")

    # Escape double quotes untuk JSON agar tidak error jika judul lagu ada tanda "
    title=$(echo "$title" | sed 's/"/\\"/g')
    artist=$(echo "$artist" | sed 's/"/\\"/g')

    # Output JSON final
    echo "{\"player\": \"$player\", \"status\": \"$status\", \"title\": \"$title\", \"artist\": \"$artist\", \"cover\": \"$cover_path\"}"

done
