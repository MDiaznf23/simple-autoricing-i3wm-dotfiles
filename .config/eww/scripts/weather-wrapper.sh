
#!/bin/bash
# Wrapper script untuk weather agar output JSON friendly untuk Eww
WEATHER_SCRIPT="$HOME/.config/polybar/scripts/weather.sh"

case "$1" in
    temp)
        # Ambil temperature dari weather.sh
        FULL_OUTPUT=$($WEATHER_SCRIPT)
        # Hapus semua polybar formatting, lalu ambil angka temperature
        echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | grep -oP '\d+°[CF]' | head -1 || echo "N/A"
        ;;
    
    icon)
        # Ambil icon cuaca dari output weather.sh
        FULL_OUTPUT=$($WEATHER_SCRIPT)
        # Hapus semua polybar formatting codes dulu
        CLEAN_OUTPUT=$(echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g')
        # Ambil karakter pertama (icon) dan HAPUS SPASI TRAILING
        echo "$CLEAN_OUTPUT" | awk '{print $1}' | xargs || echo ""
        ;;
    
    desc)
        # Ambil deskripsi cuaca
        FULL_OUTPUT=$($WEATHER_SCRIPT)
        # Hapus polybar formatting, lalu ambil text deskripsi
        echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | sed 's/[|].*//g' | awk '{$1=""; print $0}' | sed 's/[0-9]*°[CF]//g' | xargs || echo "N/A"
        ;;
    
    full)
        # Output penuh tanpa polybar formatting
        $WEATHER_SCRIPT | sed 's/%{[^}]*}//g'
        ;;
    
    city)
        # Ambil nama kota dari weather.sh
        grep "^CITY_NAME=" "$WEATHER_SCRIPT" | cut -d"'" -f2 || echo "Unknown"
        ;;
    
    *)
        # Default: kembalikan temperature
        FULL_OUTPUT=$($WEATHER_SCRIPT)
        echo "$FULL_OUTPUT" | sed 's/%{[^}]*}//g' | grep -oP '\d+°[CF]' | head -1 || echo "N/A"
        ;;
esac

