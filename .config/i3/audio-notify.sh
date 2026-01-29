#!/bin/bash

# Fungsi ambil nama device
get_sink_desc() {
    def_sink=$(pactl get-default-sink)
    pactl list sinks | grep -A 20 "Name: $def_sink" | grep -m 1 "Description:" | cut -d ":" -f2 | xargs
}

# Inisialisasi state awal
last_sink=$(pactl get-default-sink)

echo "Audio monitor started. Current sink: $last_sink" >&2

# Subscribe ke semua event change, tidak hanya sink/card
pactl subscribe | grep --line-buffered "change" | while read -r line; do
    
    echo "Event detected: $line" >&2
    
    # Sleep untuk tunggu WirePlumber selesai
    sleep 1.5
    
    current_sink=$(pactl get-default-sink)
    
    # Debug logging
    echo "Current sink: $current_sink | Last sink: $last_sink" >&2

    # Cek apakah device default berubah
    if [ "$current_sink" != "$last_sink" ] && [ -n "$current_sink" ]; then
        pretty_name=$(get_sink_desc)
        
        echo "Sink changed! New: $pretty_name" >&2
        
        # Kirim notifikasi
        notify-send -u low -r 9991 -i audio-volume-high \
            "Audio Output Changed" \
            "Active: $pretty_name"
        
        # Update state
        last_sink="$current_sink"
    fi
done
