#!/bin/bash

# --- FUNGSI PINTAR UNTUK SUHU ---
get_cpu_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        val=$(cat /sys/class/thermal/thermal_zone0/temp)
        if [ "$val" -gt 1000 ]; then
            echo $((val / 1000))
            return
        fi
    fi

    for file in /sys/class/hwmon/hwmon*/temp*_input; do
        if [ -f "$file" ]; then
            label_file="${file%_input}_label"
            if [ -f "$label_file" ]; then
                label=$(cat "$label_file")
                if [[ "$label" =~ "Core" || "$label" =~ "Package" || "$label" =~ "Tctl" ]]; then
                    val=$(cat "$file")
                    echo $((val / 1000))
                    return
                fi
            fi
        fi
    done

    # Metode 3: Fallback ke command 'sensors' 
    temp=$(sensors 2>/dev/null | grep -E "Package id 0|Core 0|Tctl" | head -1 | awk '{print $2}' | tr -d '+°C' | cut -d. -f1)
    
    if [ -n "$temp" ]; then
        echo "$temp"
    else
        echo "0"
    fi
}

# --- EXECUTION ---

# 1. Ambil Suhu pakai fungsi di atas
cpu_temp=$(get_cpu_temp)

# 2. CPU Usage (Top method)
cpu_usage=$(top -bn1 | grep 'Cpu(s)' | awk '{print 100 - $8}' | cut -d. -f1)

# 3. RAM (Read once)
# Output free: total used free ...
read -r mem_total_str mem_used_str <<< $(free -h | awk '/^Mem/ {print $2, $3}' | sed 's/i//g')
# Hitung persen pakai integer murni
read -r mem_total_int mem_used_int <<< $(free | awk '/^Mem/ {print $2, $3}')
if [ "$mem_total_int" -gt 0 ]; then
    mem_perc=$(( 100 * mem_used_int / mem_total_int ))
else
    mem_perc=0
fi

# 4. DISK (Read once)
read -r disk_total disk_used disk_perc <<< $(df -h / | awk 'NR==2 {print $2, $3, $5}' | tr -d '%')

# --- OUTPUT JSON FINAL ---
echo "{
    \"cpu_usage\": \"$cpu_usage\",
    \"cpu_temp\": \"$cpu_temp\",
    \"mem_used\": \"$mem_used_str\",
    \"mem_total\": \"$mem_total_str\",
    \"mem_perc\": \"$mem_perc\",
    \"disk_used\": \"$disk_used\",
    \"disk_total\": \"$disk_total\",
    \"disk_perc\": \"$disk_perc\"
}"
