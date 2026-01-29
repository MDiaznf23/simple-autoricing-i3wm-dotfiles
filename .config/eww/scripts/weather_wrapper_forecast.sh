#!/bin/bash
# Wrapper script untuk weather forecast agar output JSON friendly untuk Eww
WEATHER_SCRIPT="$HOME/.config/eww/scripts/weather.sh"

# Cache file untuk menyimpan data forecast terakhir yang berhasil
CACHE_DIR="$HOME/.cache/eww-weather-forecast"
mkdir -p "$CACHE_DIR"

# Fungsi untuk mendapatkan data forecast
get_forecast_data() {
    CACHE_FILE="$CACHE_DIR/forecast_data"
    CACHE_DATE="$CACHE_DIR/last_update"
    TODAY=$(date +%Y-%m-%d)
    
    # Cek apakah cache masih hari ini
    if [ -f "$CACHE_DATE" ] && [ -f "$CACHE_FILE" ]; then
        CACHED_DATE=$(cat "$CACHE_DATE")
        if [ "$CACHED_DATE" = "$TODAY" ]; then
            # Gunakan cache jika masih hari yang sama
            cat "$CACHE_FILE"
            return
        fi
    fi
    
    # Ambil data baru dan simpan ke cache
    DATA=$($WEATHER_SCRIPT forecast 2>/dev/null)
    if [ -n "$DATA" ]; then
        echo "$DATA" | tee "$CACHE_FILE"
        echo "$TODAY" > "$CACHE_DATE"
    elif [ -f "$CACHE_FILE" ]; then
        # Jika gagal ambil baru, pakai cache lama
        cat "$CACHE_FILE"
    fi
}

case "$1" in
    day0|day1|day2|day3|day4)
        # Ambil forecast untuk hari tertentu (0=hari ini, 1=besok, dst)
        DAY_NUM="${1#day}"
        
        case "$2" in
            icon)
                CACHE_FILE="$CACHE_DIR/${1}_icon"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f3)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "󰖐"
                fi
                ;;
            desc)
                CACHE_FILE="$CACHE_DIR/${1}_desc"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f4)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "N/A"
                fi
                ;;
            max|high)
                CACHE_FILE="$CACHE_DIR/${1}_max"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f5)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "N/A"
                fi
                ;;
            min|low)
                CACHE_FILE="$CACHE_DIR/${1}_min"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f6)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "N/A"
                fi
                ;;
            rain)
                CACHE_FILE="$CACHE_DIR/${1}_rain"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f7)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "0mm"
                fi
                ;;
            wind)
                CACHE_FILE="$CACHE_DIR/${1}_wind"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f8)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "0"
                fi
                ;;
            day|name)
                CACHE_FILE="$CACHE_DIR/${1}_day"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f2)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "N/A"
                fi
                ;;
            full)
                get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}"
                ;;
            *)
                # Default: return icon
                CACHE_FILE="$CACHE_DIR/${1}_icon"
                DATA=$(get_forecast_data | grep "FORECAST_DAY_${DAY_NUM}" | cut -d'|' -f3)
                if [ -n "$DATA" ]; then
                    echo "$DATA" | tee "$CACHE_FILE"
                elif [ -f "$CACHE_FILE" ]; then
                    cat "$CACHE_FILE"
                else
                    echo "󰖐"
                fi
                ;;
        esac
        ;;
    
    all)
        # Tampilkan semua forecast
        get_forecast_data
        ;;
    
json)
    # Output dalam format JSON array untuk eww
    echo "["
    FIRST=true
    for i in {0..4}; do
        LINE=$(get_forecast_data | grep "FORECAST_DAY_${i}")
        if [ -n "$LINE" ]; then
            DAY=$(echo "$LINE" | cut -d'|' -f2 | cut -c1-3) 
            ICON=$(echo "$LINE" | cut -d'|' -f3)
            DESC=$(echo "$LINE" | cut -d'|' -f4)
            MAX=$(echo "$LINE" | cut -d'|' -f5)
            MIN=$(echo "$LINE" | cut -d'|' -f6)
            RAIN=$(echo "$LINE" | cut -d'|' -f7)
            WIND=$(echo "$LINE" | cut -d'|' -f8)
            
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ","
            fi
            
            echo "  {\"day\":\"$DAY\",\"icon\":\"$ICON\",\"desc\":\"$DESC\",\"max\":\"$MAX\",\"min\":\"$MIN\",\"rain\":\"$RAIN\",\"wind\":\"$WIND\"}"
        fi
    done
    echo "]"
    ;;
    
    refresh)
        # Clear cache dan refresh data
        rm -rf "$CACHE_DIR"
        mkdir -p "$CACHE_DIR"
        get_forecast_data > /dev/null
        echo "Cache refreshed"
        ;;
    
    *)
        echo "Usage: $0 {day0|day1|day2|day3|day4} {icon|desc|max|min|rain|wind|day|full}"
        echo "       $0 {all|json|refresh}"
        echo ""
        echo "Examples:"
        echo "  $0 day0 icon      # Icon today"
        echo "  $0 day1 max       # max temp tomorrow"
        echo "  $0 day2 desc      # Deskripsi cuaca lusa"
        echo "  $0 all            # all forecast data"
        echo "  $0 json           # Output JSON untuk eww"
        exit 1
        ;;
esac
