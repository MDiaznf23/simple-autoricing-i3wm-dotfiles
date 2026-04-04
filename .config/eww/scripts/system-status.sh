#!/bin/bash

# === WiFi Status ===
# Auto-detect active wireless interface (handles wlan0, wlp2s0, wlpXsY, etc.)
wifi_interface=""
for iface in /sys/class/net/*/; do
    iface_name=$(basename "$iface")
    # Skip loopback and non-wireless interfaces
    if [ -d "/sys/class/net/$iface_name/wireless" ]; then
        wifi_interface="$iface_name"
        break
    fi
done

if [ -n "$wifi_interface" ]; then
    wifi_state=$(cat /sys/class/net/$wifi_interface/operstate 2>/dev/null)
else
    wifi_state="down"
fi

if [ "$wifi_state" = "up" ]; then
    wifi_signal=$(nmcli -t -f SIGNAL dev wifi | head -n1 2>/dev/null)
    if [ -z "$wifi_signal" ] || ! [[ "$wifi_signal" =~ ^[0-9]+$ ]]; then
        wifi_signal=$(awk 'NR==3 {print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null)
    fi
    if [ -z "$wifi_signal" ] || ! [[ "$wifi_signal" =~ ^[0-9]+$ ]]; then
        wifi_signal=100
    fi

    if [ "$wifi_signal" -le 20 ]; then
        wifi_icon="󰤯 "
    elif [ "$wifi_signal" -le 40 ]; then
        wifi_icon="󰤟 "
    elif [ "$wifi_signal" -le 60 ]; then
        wifi_icon="󰤢 "
    elif [ "$wifi_signal" -le 80 ]; then
        wifi_icon="󰤥 "
    else
        wifi_icon="󰤨 "
    fi

    rx_bytes_1=$(cat /sys/class/net/$wifi_interface/statistics/rx_bytes 2>/dev/null || echo 0)
    tx_bytes_1=$(cat /sys/class/net/$wifi_interface/statistics/tx_bytes 2>/dev/null || echo 0)
    sleep 1
    rx_bytes_2=$(cat /sys/class/net/$wifi_interface/statistics/rx_bytes 2>/dev/null || echo 0)
    tx_bytes_2=$(cat /sys/class/net/$wifi_interface/statistics/tx_bytes 2>/dev/null || echo 0)

    rx_rate=$((rx_bytes_2 - rx_bytes_1))
    tx_rate=$((tx_bytes_2 - tx_bytes_1))

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

    wifi_desc="↓$(format_speed $rx_rate) ↑$(format_speed $tx_rate)"
    wifi_connected="true"
else
    wifi_icon="󰤮 "
    wifi_desc="Disconnected"
    wifi_connected="false"
fi

# === Battery ===
# Auto-detect battery node (BAT0, BAT1, BAT2, BATT, etc.)
bat_path=""
for bat in /sys/class/power_supply/BAT* /sys/class/power_supply/BATT* /sys/class/power_supply/battery*; do
    if [ -f "$bat/capacity" ]; then
        bat_path="$bat"
        break
    fi
done

# Auto-detect AC adapter node — gunakan nama eksplisit seperti anacron:
# AC (paling umum di Ubuntu/Debian), ADP0-ADP2 (Arch, dll), ACAD
# Hindari glob AC* karena bisa mencocokkan direktori non-adapter
ac_path=""
for ac in /sys/class/power_supply/AC \
          /sys/class/power_supply/AC0 \
          /sys/class/power_supply/ADP0 \
          /sys/class/power_supply/ADP1 \
          /sys/class/power_supply/ADP2 \
          /sys/class/power_supply/ACAD; do
    if [ -f "$ac/online" ]; then
        ac_path="$ac"
        break
    fi
done
# Fallback: scan semua entry, cek type == "Mains" (standar kernel untuk AC adapter)
if [ -z "$ac_path" ]; then
    for entry in /sys/class/power_supply/*/; do
        [ -f "${entry}type" ] || continue
        if [ "$(cat "${entry}type" 2>/dev/null)" = "Mains" ] && [ -f "${entry}online" ]; then
            ac_path="${entry%/}"
            break
        fi
    done
fi

if [ -n "$bat_path" ]; then
    bat_capacity=$(cat "$bat_path/capacity" 2>/dev/null)
    bat_status=$(cat "$bat_path/status" 2>/dev/null)
else
    bat_capacity=""
    bat_status=""
fi

if [ -n "$ac_path" ]; then
    ac_online=$(cat "$ac_path/online" 2>/dev/null)
else
    ac_online=""
fi

if [ -z "$bat_capacity" ] || ! [[ "$bat_capacity" =~ ^[0-9]+$ ]]; then
    bat_capacity=0
fi

if [ "$bat_status" = "Charging" ] || [ "$ac_online" = "1" ]; then
    bat_charging="true"
    if [ "$bat_capacity" -le 10 ]; then bat_icon="󰢟"
    elif [ "$bat_capacity" -le 20 ]; then bat_icon="󰢜"
    elif [ "$bat_capacity" -le 30 ]; then bat_icon="󰂆"
    elif [ "$bat_capacity" -le 40 ]; then bat_icon="󰂇"
    elif [ "$bat_capacity" -le 50 ]; then bat_icon="󰂈"
    elif [ "$bat_capacity" -le 60 ]; then bat_icon="󰢝"
    elif [ "$bat_capacity" -le 70 ]; then bat_icon="󰂉"
    elif [ "$bat_capacity" -le 80 ]; then bat_icon="󰢞"
    elif [ "$bat_capacity" -le 90 ]; then bat_icon="󰂊"
    else bat_icon="󰂅"
    fi
else
    bat_charging="false"
    if [ "$bat_capacity" -le 10 ]; then bat_icon="󰂎"
    elif [ "$bat_capacity" -le 20 ]; then bat_icon="󰁺"
    elif [ "$bat_capacity" -le 30 ]; then bat_icon="󰁻"
    elif [ "$bat_capacity" -le 40 ]; then bat_icon="󰁼"
    elif [ "$bat_capacity" -le 50 ]; then bat_icon="󰁽"
    elif [ "$bat_capacity" -le 60 ]; then bat_icon="󰁾"
    elif [ "$bat_capacity" -le 70 ]; then bat_icon="󰁿"
    elif [ "$bat_capacity" -le 80 ]; then bat_icon="󰂀"
    elif [ "$bat_capacity" -le 90 ]; then bat_icon="󰂁"
    else bat_icon="󰂂"
    fi
fi

bat_desc="${bat_capacity}%"

# === Brightness ===
brightness=$(brightnessctl get 2>/dev/null)
max_brightness=$(brightnessctl max 2>/dev/null)

if [ -n "$brightness" ] && [ -n "$max_brightness" ] && [ "$max_brightness" -gt 0 ]; then
    bright_pct=$((brightness * 100 / max_brightness))
else
    bright_pct=0
fi

if [ "$bright_pct" -le 25 ]; then bright_icon="󰃞"
elif [ "$bright_pct" -le 50 ]; then bright_icon="󰃝"
elif [ "$bright_pct" -le 75 ]; then bright_icon="󰃟"
else bright_icon="󰃠"
fi

bright_desc="${bright_pct}%"

# === Volume ===
muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -o 'yes')
vol_pct=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -Po '\d+(?=%)' | head -1)

if [ -z "$vol_pct" ] || ! [[ "$vol_pct" =~ ^[0-9]+$ ]]; then
    vol_pct=0
fi

if [ "$muted" = "yes" ]; then
    vol_icon="󰖁"
    vol_muted="true"
else
    vol_muted="false"
    if [ "$vol_pct" -le 30 ]; then vol_icon=""
    elif [ "$vol_pct" -le 70 ]; then vol_icon=""
    else vol_icon=" "
    fi
fi

vol_desc="${vol_pct}%"

# === Output JSON single-line ===
echo "{\"wifi_icon\":\"$wifi_icon\",\"wifi_desc\":\"$wifi_desc\",\"wifi_connected\":$wifi_connected,\"bat_icon\":\"$bat_icon\",\"bat_desc\":\"$bat_desc\",\"bat_capacity\":$bat_capacity,\"bat_charging\":$bat_charging,\"bright_icon\":\"$bright_icon\",\"bright_desc\":\"$bright_desc\",\"bright_pct\":$bright_pct,\"vol_icon\":\"$vol_icon\",\"vol_desc\":\"$vol_desc\",\"vol_pct\":$vol_pct,\"vol_muted\":$vol_muted}"
