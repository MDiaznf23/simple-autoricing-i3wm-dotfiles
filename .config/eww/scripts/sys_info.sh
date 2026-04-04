#!/bin/bash

# --- FUNGSI SUHU CPU ---
get_cpu_temp() {
    # Metode 1: hwmon dengan label CPU (paling akurat)
    # Prioritas: Package id > Core > Tctl/Tccd (AMD)
    for file in /sys/class/hwmon/hwmon*/temp*_input; do
        [ -f "$file" ] || continue
        label_file="${file%_input}_label"
        [ -f "$label_file" ] || continue
        label=$(cat "$label_file" 2>/dev/null)
        if [[ "$label" =~ ^(Package\ id|Core\ 0|Tctl|Tccd) ]]; then
            val=$(cat "$file" 2>/dev/null)
            if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ]; then
                echo $((val / 1000))
                return
            fi
        fi
    done

    # Metode 2: thermal_zone dengan type x86_pkg_temp (Intel) atau cpu-thermal (ARM/generic)
    for zone in /sys/class/thermal/thermal_zone*/; do
        [ -d "$zone" ] || continue
        type=$(cat "${zone}type" 2>/dev/null)
        if [[ "$type" == "x86_pkg_temp" || "$type" == "cpu-thermal" || "$type" == "cpu_thermal" ]]; then
            val=$(cat "${zone}temp" 2>/dev/null)
            if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -gt 0 ]; then
                [ "$val" -gt 1000 ] && echo $((val / 1000)) || echo "$val"
                return
            fi
        fi
    done

    # Metode 3: Fallback ke sensors (butuh lm-sensors terinstall)
    temp=$(sensors 2>/dev/null \
        | grep -E "^(Package id 0|Tctl):" \
        | head -1 \
        | grep -oP '[+-]\K[0-9]+(?=\.[0-9])')
    if [[ "$temp" =~ ^[0-9]+$ ]]; then
        echo "$temp"
        return
    fi

    echo "0"
}

# --- FUNGSI CPU USAGE (pakai array, lebih robust dari read -r fields) ---
get_cpu_usage() {
    # Baca sebagai array untuk menghindari masalah field splitting pada rest fields
    # Layout: index 0="cpu", 1=user, 2=nice, 3=system, 4=idle,
    #         5=iowait, 6=irq, 7=softirq, 8=steal, 9=guest, 10=guest_nice
    local cpu1 cpu2

    cpu1=($(grep '^cpu ' /proc/stat))
    sleep 0.5
    cpu2=($(grep '^cpu ' /proc/stat))

    local total1=0 total2=0 idle1=${cpu1[4]} idle2=${cpu2[4]}

    for i in "${!cpu1[@]}"; do
        [ $i -eq 0 ] && continue  # skip label "cpu"
        total1=$((total1 + cpu1[i]))
        total2=$((total2 + cpu2[i]))
    done

    local diff_total=$((total2 - total1))
    local diff_idle=$((idle2 - idle1))

    if [ "$diff_total" -gt 0 ]; then
        echo $(( 100 * (diff_total - diff_idle) / diff_total ))
    else
        echo "0"
    fi
}

# --- EXECUTION ---

# 1. CPU usage dan suhu
cpu_usage=$(get_cpu_usage)
cpu_temp=$(get_cpu_temp)

# Validasi
[[ "$cpu_usage" =~ ^[0-9]+$ ]] || cpu_usage=0
[[ "$cpu_temp"  =~ ^[0-9]+$ ]] || cpu_temp=0

# 2. RAM — pakai -k (kilobytes murni) untuk hindari perbedaan suffix antar sistem
read -r mem_total_int mem_used_int <<< $(free -k | awk '/^Mem/ {print $2, $3}')

if [[ "$mem_total_int" =~ ^[0-9]+$ ]] && [ "$mem_total_int" -gt 0 ]; then
    mem_perc=$(( 100 * mem_used_int / mem_total_int ))
    if [ "$mem_total_int" -ge 1048576 ]; then
        mem_total_str="$(awk "BEGIN {printf \"%.1fG\", $mem_total_int/1048576}")"
        mem_used_str="$(awk  "BEGIN {printf \"%.1fG\", $mem_used_int/1048576}")"
    else
        mem_total_str="$(awk "BEGIN {printf \"%.0fM\", $mem_total_int/1024}")"
        mem_used_str="$(awk  "BEGIN {printf \"%.0fM\", $mem_used_int/1024}")"
    fi
else
    mem_perc=0; mem_total_str="N/A"; mem_used_str="N/A"
fi

# 3. DISK
read -r disk_total disk_used disk_perc <<< $(df -h / | awk 'NR==2 {gsub(/%/,"",$5); print $2, $3, $5}')
[[ "$disk_perc" =~ ^[0-9]+$ ]] || disk_perc=0

# --- OUTPUT JSON ---
echo "{\"cpu_usage\":$cpu_usage,\"cpu_temp\":$cpu_temp,\"mem_used\":\"$mem_used_str\",\"mem_total\":\"$mem_total_str\",\"mem_perc\":$mem_perc,\"disk_used\":\"$disk_used\",\"disk_total\":\"$disk_total\",\"disk_perc\":$disk_perc}"
