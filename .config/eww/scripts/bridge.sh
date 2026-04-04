#!/bin/bash
# ~/.config/eww/scripts/bridge.sh

export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Berikan notifikasi awal bahwa sistem siap
dunstify -r 999 -u low "🎙️ Voice Mode" "Listening..."
echo "DEBUG: Voice Mode dimulai. Mendengarkan..."

# Jalankan voicewm dengan unbuffered output
stdbuf -oL voicewm --verbose 2>&1 | while read -r line; do
    # Tetap tampilkan semua log asli dari voicewm ke terminal
    echo "RAW: $line"

    if [[ "$line" == *"Detected speech:"* ]]; then
        # Ambil teks dan hapus spasi berlebih
        text=$(echo "$line" | sed "s/.*Detected speech: '\(.*\)'/\1/" | xargs)
        
        if [[ -n "$text" ]]; then
            # Tampilkan log khusus untuk teks yang berhasil dideteksi
            echo "-----------------------------------"
            echo "MATCHED SPEECH: $text"
            echo "-----------------------------------"
            
            # Update notifikasi Dunst secara instan
            dunstify -r 999 -u low "🎙️ Detected" "$text"
        fi
    fi
done
