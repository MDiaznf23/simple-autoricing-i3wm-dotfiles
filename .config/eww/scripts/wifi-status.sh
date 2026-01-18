#!/bin/bash
# ~/.config/eww/scripts/system-status.sh

# === WiFi Status ===
wifi_interface="wlan0"
wifi_state=$(cat /sys/class/net/$wifi_interface/operstate 2>/dev/null)

if [ "$wifi_state" = "up" ]; then
    # Get signal strength
    wifi_signal=$(nmcli -t -f SIGNAL dev wifi | head -n1 2>/dev/null)
    
    if [ -z "$wifi_signal" ] || ! [[ "$wifi_signal" =~ ^[0-9]+$ ]]; then
        wifi_signal=$(awk 'NR==3 {print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null)
    fi
    
    if [ -z "$wifi_signal" ] || ! [[ "$wifi_signal" =~ ^[0-9]+$ ]]; then
        wifi_signal=100
    fi
    
    # Set icon based on signal strength
    if [ "$wifi_signal" -le 20 ]; then
        wifi_icon="󰤯"
    elif [ "$wifi_signal" -le 40 ]; then
        wifi_icon="󰤟"
    elif [ "$wifi_signal" -le 60 ]; then
        wifi_icon="󰤢"
    elif [ "$wifi_signal" -le 80 ]; then
        wifi_icon="󰤥"
    else
        wifi_icon="󰤨"
    fi
    
    # Calculate network speed
    rx_bytes_1=$(cat /sys/class/net/$wifi_interface/statistics/rx_bytes)
    tx_bytes_1=$(cat /sys/class/net/$wifi_interface/statistics/tx_bytes)
    
    sleep 1
    
    rx_bytes_2=$(cat /sys/class/net/$wifi_interface/statistics/rx_bytes)
    tx_bytes_2=$(cat /sys/class/net/$wifi_interface/statistics/tx_bytes)
    
    rx_rate=$((rx_bytes_2 - rx_bytes_1))
    tx_rate=$((tx_bytes_2 - tx_bytes_1))
    
    # Format speed
    format_speed() {
        local bytes=$1
        if [ $bytes -lt 1024 ]; then
            echo "${bytes}B/s"
        elif [ $bytes -lt 1048576 ]; then
            echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}")K/s"
        else
            echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1048576}")M/s"
        fi
    }
    
    downspeed=$(format_speed $rx_rate)
    upspeed=$(format_speed $tx_rate)
    
    wifi_display="$wifi_icon  ↓$downspeed ↑$upspeed"
else
    wifi_display="󰤮 Disconnected"
fi

# === Brightness ===
brightness=$(cat /sys/class/backlight/acpi_video0/brightness 2>/dev/null)
max_brightness=$(cat /sys/class/backlight/acpi_video0/max_brightness 2>/dev/null)

if [ -n "$brightness" ] && [ -n "$max_brightness" ] && [ "$max_brightness" -gt 0 ]; then
    bright_pct=$((brightness * 100 / max_brightness))
else
    bright_pct=0
fi

if [ "$bright_pct" -le 25 ]; then
    bright_icon="󰃞 "
elif [ "$bright_pct" -le 50 ]; then
    bright_icon="󰃝 "
elif [ "$bright_pct" -le 75 ]; then
    bright_icon="󰃟 "
else
    bright_icon="󰃠 "
fi

# === Volume ===
muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -o 'yes')
vol_pct=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\d+(?=%)' | head -1)

# Pastikan vol_pct tidak kosong
if [ -z "$vol_pct" ] || ! [[ "$vol_pct" =~ ^[0-9]+$ ]]; then
    vol_pct=0
fi

if [ "$muted" = "yes" ]; then
    vol_icon="󰖁"
else
    if [ "$vol_pct" -le 30 ]; then
        vol_icon=""
    elif [ "$vol_pct" -le 70 ]; then
        vol_icon=""
    else
        vol_icon=" "
    fi
fi

# === Output JSON format untuk EWW ===
cat << EOF
{
  "wifi": "$wifi_display",
  "brightness": "$bright_icon",
  "volume": "$vol_icon"
}
EOF
