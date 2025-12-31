#!/bin/bash

CACHE_DIR="$HOME/.cache/eww"
LOGO_FILE="$CACHE_DIR/distro-logo.png"

# Buat folder cache kalau belum ada
mkdir -p "$CACHE_DIR"

# Cek kalau logo sudah ada, skip download
if [ -f "$LOGO_FILE" ]; then
    echo "$LOGO_FILE"
    exit 0
fi

# Deteksi distro
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="$ID"
else
    DISTRO_ID="linux"
fi

# Download logo dari distrowatch
curl -sL "https://distrowatch.com/images/yvzhuwbpy/${DISTRO_ID}.png" -o "$LOGO_FILE" 2>/dev/null

# Kalau gagal atau file kosong, pakai logo Tux sebagai fallback
if [ ! -s "$LOGO_FILE" ]; then
    curl -sL "https://upload.wikimedia.org/wikipedia/commons/3/35/Tux.svg" -o "$LOGO_FILE" 2>/dev/null
fi

echo "$LOGO_FILE"
