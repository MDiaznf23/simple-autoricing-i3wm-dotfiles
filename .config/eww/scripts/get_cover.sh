#!/bin/bash
# File cache untuk cover
COVER_CACHE="/tmp/mpd_cover.jpg"
DEFAULT_COVER="$HOME/.config/eww/assets/default-cover.jpg"

# Ambil info dari MPD
PLAYER=$(playerctl -l 2>/dev/null | grep -E '^mpd$|^firefox|^spotify' | head -n1)
if [ -z "$PLAYER" ]; then
    echo ""
    exit 0
fi

# Coba ambil artUrl dulu (untuk Spotify, Firefox)
ART_URL=$(playerctl -p "$PLAYER" metadata mpris:artUrl 2>/dev/null | sed 's|^file://||')
if [ -n "$ART_URL" ] && [ -s "$ART_URL" ]; then
    # Validasi apakah file image yang valid
    if file "$ART_URL" 2>/dev/null | grep -qiE 'image|jpeg|png|jpg'; then
        echo "$ART_URL"
        exit 0
    fi
fi

# Untuk MPD: ambil path file musik
MUSIC_FILE=$(playerctl -p "$PLAYER" metadata xesam:url 2>/dev/null | sed 's|file://||')
if [ -z "$MUSIC_FILE" ]; then
    echo "$DEFAULT_COVER"
    exit 0
fi

MUSIC_DIR=$(dirname "$MUSIC_FILE")

# Cari cover.jpg atau folder.jpg di folder musik
COVER=$(find "$MUSIC_DIR" -maxdepth 1 \( -iname "cover.jpg" -o -iname "folder.jpg" \) 2>/dev/null | head -n1)
if [ -n "$COVER" ]; then
    echo "$COVER"
    exit 0
fi

# Hapus cache lama
rm -f "$COVER_CACHE"

# Kalau ga ada, extract embedded cover pakai ffmpeg
if ffmpeg -i "$MUSIC_FILE" -an -vcodec copy "$COVER_CACHE" -y 2>/dev/null; then
    # Cek apakah file yang dibuat valid
    if [ -s "$COVER_CACHE" ] && file "$COVER_CACHE" 2>/dev/null | grep -qiE 'image|jpeg|png|jpg'; then
        echo "$COVER_CACHE"
        exit 0
    else
        rm -f "$COVER_CACHE"
    fi
fi

# Fallback ke default cover
echo "$DEFAULT_COVER"
