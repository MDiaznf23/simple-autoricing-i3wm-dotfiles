#!/bin/bash

# CACHE FILE PATH

CACHE_FILE="/tmp/eww_laptop_info_cache.json"
FALLBACK_LOGO="${HOME}/.config/eww/assets/brand.png"
LOGO_CACHE_DIR="${HOME}/.cache/eww/logos"

# --- 1. CEK CACHE UTAMA (FAST PATH) ---
if [ -s "$CACHE_FILE" ]; then
    cat "$CACHE_FILE"
    exit 0
fi

# --- 2. JIKA CACHE KOSONG, JALANKAN DETEKSI (HEAVY PATH) ---
# Bagian ini hanya jalan 1x setelah laptop nyala.

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

get_logo_path() {
    local brand=$1
    local domain=""
    mkdir -p "$LOGO_CACHE_DIR"
    local logo_file="${LOGO_CACHE_DIR}/${brand}.png"

    # Cek cache logo
    if [ -f "$logo_file" ] && [ -s "$logo_file" ]; then
        echo "$logo_file"
        return
    fi

    # Mapping domain
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

    # Download Async (Background)
    if [ -n "$domain" ]; then
        (
            logo_url="https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=https%3A%2F%2F${domain}&size=128"
            curl -s -m 10 -o "$logo_file" "$logo_url" 2>/dev/null
        ) &
    fi

    echo "$FALLBACK_LOGO"
}

get_model() {
    local model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if [ -z "$model" ] || [[ "$model" == *"System Product"* ]]; then
        model=$(cat /sys/class/dmi/id/board_name 2>/dev/null)
    fi
    echo "${model:-Unknown}"
}

get_cpu() {
    lscpu | grep "Model name" | cut -d':' -f2 | sed -e 's/(R)//g' -e 's/(TM)//g' -e 's/CPU //g' -e 's/Core //g' | xargs
}

get_gpu() {
    lspci | grep -i 'vga\|3d\|display' | cut -d':' -f3 | head -n1 | sed -e 's/Corporation //g' -e 's/\[.*\]//g' | xargs
}

get_ram() {
    free -h | awk '/^Mem:/ {print $2}'
}

get_disk() {
    local disk=$(df -h / | awk 'NR==2 {print $2}')
    local disk_type="SSD"
    if [ -f "/sys/block/sda/queue/rotational" ]; then
        [ "$(cat /sys/block/sda/queue/rotational)" -eq 1 ] && disk_type="HDD"
    fi
    echo "${disk} ${disk_type}"
}

# --- GENERATE DATA ---
BRAND=$(get_brand)
LOGO_PATH=$(get_logo_path "$BRAND")
MODEL=$(get_model)
CPU=$(get_cpu)
GPU=$(get_gpu)
RAM=$(get_ram)
DISK=$(get_disk)

# --- SAVE TO JSON CACHE ---
# Kita simpan output json ke variabel dulu
JSON_OUTPUT=$(jq -n \
  --arg brand "$BRAND" \
  --arg logo_path "$LOGO_PATH" \
  --arg model "$MODEL" \
  --arg cpu "$CPU" \
  --arg gpu "$GPU" \
  --arg ram "$RAM" \
  --arg disk "$DISK" \
  '{
    brand: $brand,
    logo_path: $logo_path,
    model: $model,
    cpu: $cpu,
    gpu: $gpu,
    ram: $ram,
    disk: $disk
  }')

# Tulis ke file cache
echo "$JSON_OUTPUT" > "$CACHE_FILE"

# Print ke stdout untuk Eww
echo "$JSON_OUTPUT"
