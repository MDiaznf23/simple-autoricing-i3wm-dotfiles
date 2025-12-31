#!/bin/bash
PLAYER=$(playerctl -l 2>/dev/null | grep -v "kdeconnect" | head -n1)
if [ -z "$PLAYER" ]; then
    echo ""
else
    echo "$PLAYER"
fi
