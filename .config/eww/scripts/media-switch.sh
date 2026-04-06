#!/bin/bash
# Usage: media-switch.sh <player_name>
# Kirim perintah switch ke media-monitor.py via socket
echo "switch:$1" | socat - UNIX-CONNECT:/tmp/eww-media-monitor.sock
