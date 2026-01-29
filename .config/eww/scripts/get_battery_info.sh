#!/bin/bash

# 1. Ambil nama baterai (hapus newline di akhir dengan tr -d '\n')
BAT_NAME=$(cat /sys/class/power_supply/BAT*/model_name | head -n 1 | tr -d '\n')

# 2. Ambil power profile
PROFILE=$(powerprofilesctl get | tr -d '\n')

# 3. Output JSON
printf '{"battery_name": "%s", "profile": "%s"}\n' "$BAT_NAME" "$PROFILE"
