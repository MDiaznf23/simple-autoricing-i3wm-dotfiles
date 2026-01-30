#!/bin/bash

# Minimum brightness (dalam persen dari max_brightness)
MIN_PERCENT=1

# Dapatkan nilai maksimum dan minimum
max=$(brightnessctl max)
min=$(( max * MIN_PERCENT / 100 ))

# Pastikan minimum tidak kurang dari 1
[ $min -lt 1 ] && min=1

case "$1" in
    up)
        brightnessctl set +1%
        ;;
    down)
        current=$(brightnessctl get)
        # Hitung nilai baru (turun 5%)
        decrease=$(( max * 5 / 100 ))
        new=$(( current - decrease ))
        
        # Jika nilai baru di bawah minimum, set ke minimum
        if [ $new -lt $min ]; then
            brightnessctl set $min
        else
            brightnessctl set 1%-
        fi
        ;;
    set)
        # Terima nilai dari slider (dalam persen)
        value="$2"
        
        # Validasi input
        if [ -z "$value" ]; then
            echo "Error: No value provided"
            exit 1
        fi
        
        # Konversi persen ke nilai absolut
        target=$(( max * value / 100 ))
        
        # Pastikan tidak di bawah minimum
        if [ $target -lt $min ]; then
            target=$min
        fi
        
        # Set brightness
        brightnessctl set $target
        ;;
    *)
        echo "Usage: $0 {up|down|set <percent>}"
        exit 1
        ;;
esac
