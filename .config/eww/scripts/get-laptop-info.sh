#!/bin/bash

# Script untuk mendapatkan informasi laptop + logo dari API
# Simpan di: ~/.config/eww/scripts/get-laptop-info.sh

# Fungsi untuk mendeteksi brand laptop
get_brand() {
    local vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]')
    
    case "$vendor" in
        *lenovo*) echo "lenovo" ;;
        *asus*) echo "asus" ;;
        *dell*) echo "dell" ;;
        *hp*|*hewlett*) echo "hp" ;;
        *acer*) echo "acer" ;;
        *msi*) echo "msi" ;;
        *apple*) echo "apple" ;;
        *samsung*) echo "samsung" ;;
        *toshiba*) echo "toshiba" ;;
        *sony*) echo "sony" ;;
        *razer*) echo "razer" ;;
        *gigabyte*) echo "gigabyte" ;;
        *framework*) echo "framework" ;;
        *) echo "unknown" ;;
    esac
}

# Fungsi untuk download dan cache logo
get_logo_path() {
    local brand=$1
    local domain=""
    
    # Map brand ke domain company
    case "$brand" in
        lenovo) domain="lenovo.com" ;;
        asus) domain="asus.com" ;;
        dell) domain="dell.com" ;;
        hp) domain="hp.com" ;;
        acer) domain="acer.com" ;;
        msi) domain="msi.com" ;;
        apple) domain="apple.com" ;;
        samsung) domain="samsung.com" ;;
        toshiba) domain="toshiba.com" ;;
        sony) domain="sony.com" ;;
        razer) domain="razer.com" ;;
        gigabyte) domain="gigabyte.com" ;;
        framework) domain="frame.work" ;;
        *) domain="" ;;
    esac
    
    if [ -z "$domain" ]; then
        echo ""
        return
    fi
    
    # Path untuk cache logo
    local cache_dir="${HOME}/.cache/eww/logos"
    mkdir -p "$cache_dir"
    local logo_file="${cache_dir}/${brand}.png"
    
    # Download logo kalau belum ada (cache)
    if [ ! -f "$logo_file" ]; then
        local logo_url="https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https%3A%2F%2F${domain}&size=128"
        curl -s -o "$logo_file" "$logo_url" 2>/dev/null
        
        # Cek apakah download berhasil
        if [ ! -s "$logo_file" ]; then
            rm -f "$logo_file"
            echo ""
            return
        fi
    fi
    
    echo "$logo_file"
}

# Fungsi untuk mendapatkan model laptop
get_model() {
    local model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if [ -z "$model" ] || [ "$model" = "System Product Name" ]; then
        model=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
    fi
    echo "${model:-Unknown}"
}

# Fungsi untuk mendapatkan info CPU
get_cpu() {
    local cpu=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
    cpu=$(echo "$cpu" | sed -e 's/(R)//g' -e 's/(TM)//g' -e 's/CPU //g' -e 's/  */ /g')
    echo "${cpu:-Unknown}"
}

# Fungsi untuk mendapatkan info GPU
get_gpu() {
    local gpu=$(lspci | grep -i 'vga\|3d\|display' | cut -d':' -f3 | head -n1 | xargs)
    gpu=$(echo "$gpu" | sed -e 's/Corporation //g' -e 's/\[.*\]//g' -e 's/  */ /g')
    echo "${gpu:-Unknown}"
}

# Fungsi untuk mendapatkan info RAM
get_ram() {
    local total_ram=$(free -h | awk '/^Mem:/ {print $2}')
    local ram_type=""
    
    if [ -r /sys/devices/system/memory/meminfo ]; then
        ram_type=$(cat /sys/devices/system/memory/meminfo 2>/dev/null | grep -i "type" | head -n1 | awk '{print $2}')
    fi
    
    if [ -z "$ram_type" ]; then
        ram_type=$(lshw -short -C memory 2>/dev/null | grep -i "system memory" | awk '{print $2}' | head -n1)
    fi
    
    if [ -z "$ram_type" ]; then
        echo "${total_ram:-Unknown}"
    else
        echo "${total_ram} ${ram_type}"
    fi
}

# Fungsi untuk mendapatkan info Disk
get_disk() {
    local disk=$(df -h / | awk 'NR==2 {print $2}')
    local disk_type="SSD"
    
    if [ -b "/dev/sda" ]; then
        local rotational=$(cat /sys/block/sda/queue/rotational 2>/dev/null)
        [ "$rotational" = "1" ] && disk_type="HDD"
    elif [ -b "/dev/nvme0n1" ]; then
        disk_type="NVMe"
    fi
    
    echo "${disk} ${disk_type}"
}

# Escape string untuk JSON
json_escape() {
    echo "$1" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g'
}

# Ambil semua informasi
BRAND=$(get_brand)
LOGO_PATH=$(get_logo_path "$BRAND")
MODEL=$(json_escape "$(get_model)")
CPU=$(json_escape "$(get_cpu)")
GPU=$(json_escape "$(get_gpu)")
RAM=$(json_escape "$(get_ram)")
DISK=$(json_escape "$(get_disk)")

# Output dalam format JSON
cat << EOF
{
  "brand": "$BRAND",
  "logo_path": "$LOGO_PATH",
  "model": "$MODEL",
  "cpu": "$CPU",
  "gpu": "$GPU",
  "ram": "$RAM",
  "disk": "$DISK"
}
EOF
