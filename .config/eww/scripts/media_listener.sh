#!/bin/bash

SEP=$'\x1F'
FORMAT="${SEP}{{playerName}}${SEP}{{status}}${SEP}{{title}}${SEP}{{artist}}${SEP}{{mpris:artUrl}}${SEP}{{xesam:url}}${SEP}{{position}}${SEP}{{mpris:length}}${SEP}"

# --- COVER ART ---
get_cover() {
    local player="$1"
    local art_url="$2"
    local music_file="$3"

    local cover_cache="/tmp/mpd_cover_$(echo "$music_file" | md5sum | cut -d' ' -f1).jpg"
    local default_cover="$HOME/.config/eww/assets/default-cover.jpg"

    clean_url=$(echo "$art_url" | sed 's|^file://||')
    if [ -n "$clean_url" ] && [ -f "$clean_url" ]; then
        echo "$clean_url"
        return
    fi

    clean_file=$(echo "$music_file" | sed 's|^file://||')
    if [ -z "$clean_file" ]; then
        echo "$default_cover"
        return
    fi

    if [ ! -f "$clean_file" ]; then
        echo "$default_cover"
        return
    fi

    music_dir=$(dirname "$clean_file")

    local_cover=$(find "$music_dir" -maxdepth 1 \( -iname "cover.jpg" -o -iname "folder.jpg" -o -iname "*.png" \) 2>/dev/null | head -n1)
    if [ -n "$local_cover" ]; then
        echo "$local_cover"
        return
    fi

    if [ -f "$cover_cache" ]; then
        echo "$cover_cache"
        return
    fi

    if ffmpeg -i "$clean_file" -an -vcodec copy "$cover_cache" -y -loglevel quiet 2>/dev/null; then
        if [ -s "$cover_cache" ]; then
            echo "$cover_cache"
            return
        fi
    fi

    echo "$default_cover"
}

# --- ESCAPE JSON ---
json_escape() {
    echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r//g'
}

# --- BUILD JSON ---
build_json() {
    local player="$1"
    local status="$2"
    local title="$3"
    local artist="$4"
    local art_url="$5"
    local file_path="$6"
    local position="$7"
    local length="$8"

    if [ -z "$player" ]; then
        echo '{"title": "No Media", "artist": "Offline", "status": "Stopped", "player": "", "cover": "", "position": 0, "length": 0}'
        return
    fi

    cover_path=$(get_cover "$player" "$art_url" "$file_path")
    title=$(json_escape "$title")
    artist=$(json_escape "$artist")
    player=$(json_escape "$player")
    cover_path=$(json_escape "$cover_path")

    [[ "$position" =~ ^[0-9]+$ ]] || position=0
    [[ "$length" =~ ^[0-9]+$ ]]   || length=0

    echo "{\"player\": \"$player\", \"status\": \"$status\", \"title\": \"$title\", \"artist\": \"$artist\", \"cover\": \"$cover_path\", \"position\": $position, \"length\": $length}"
}

# --- MODE: --list ---
if [ "$1" = "--list" ]; then
    players=$(playerctl -l 2>/dev/null)
    if [ -z "$players" ]; then
        echo "[]"
        exit
    fi
    first=true
    echo -n "["
    while IFS= read -r player; do
        status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
        [ "$first" = true ] && first=false || echo -n ","
        echo -n "{\"player\":\"$player\",\"status\":\"$status\"}"
    done <<< "$players"
    echo "]"
    exit
fi

# --- MODE: --watch [player] ---
if [ "$1" = "--watch" ]; then
    player="$2"
    if [ -n "$player" ]; then
        playerctl metadata -p "$player" -F --format "$FORMAT" 2>/dev/null | \
        while IFS="$SEP" read -r _ p status title artist art_url file_path position length _; do
            build_json "$p" "$status" "$title" "$artist" "$art_url" "$file_path" "$position" "$length"
        done
    else
        playerctl metadata -F --format "$FORMAT" 2>/dev/null | \
        while IFS="$SEP" read -r _ p status title artist art_url file_path position length _; do
            build_json "$p" "$status" "$title" "$artist" "$art_url" "$file_path" "$position" "$length"
        done
    fi
    exit
fi
