#!/bin/bash

SELECTED_FILE="/tmp/eww_selected_player"
SCRIPT="$HOME/.config/eww/scripts/media_listener.sh"
PGID_FILE="/tmp/eww_media_pgid"

kill_old() {
    if [ -f "$PGID_FILE" ]; then
        old_pgid=$(cat "$PGID_FILE")
        kill -- "-$old_pgid" 2>/dev/null
        rm -f "$PGID_FILE"
    fi
}

start_watch() {
    kill_old

    local player="$1"

    # Jalankan dalam subshell baru dengan setsid supaya punya PGID sendiri
    setsid bash -c "
        echo \$\$ > '$PGID_FILE'
        exec '$SCRIPT' --watch '$player'
    " &

    sleep 0.2
}

# Bersihkan saat start
rm -f "$SELECTED_FILE"

# Ambil default player pertama yang aktif
default_player=$(playerctl -l 2>/dev/null | head -n1)
if [ -n "$default_player" ]; then
    echo "$default_player" > "$SELECTED_FILE"
fi

current=""
start_watch "${default_player:-}"

while true; do
    selected=""
    [ -f "$SELECTED_FILE" ] && selected=$(cat "$SELECTED_FILE")

    if [ "$selected" != "$current" ]; then
        current="$selected"
        start_watch "$current"
    fi

    sleep 0.5
done
