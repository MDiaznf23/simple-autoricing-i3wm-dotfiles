#!/bin/bash
PLAYER=$(~/.config/eww/scripts/get_player.sh)

if [ -z "$PLAYER" ]; then
    echo ""
    exit 0
fi

case "$1" in
    title)
        playerctl -p "$PLAYER" metadata --format "{{ title }}" 2>/dev/null || echo ""
        ;;
    artist)
        playerctl -p "$PLAYER" metadata --format "{{ artist }}" 2>/dev/null || echo ""
        ;;
    status)
        playerctl -p "$PLAYER" status 2>/dev/null || echo "Stopped"
        ;;
    player)
        playerctl -p "$PLAYER" metadata --format "{{ playerName }}" 2>/dev/null || echo ""
        ;;
    *)
        echo ""
        ;;
esac
