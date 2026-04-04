#!/bin/bash

source "$HOME/.config/i3/config-dotfiles"

all_ws=$(i3-msg -t get_workspaces | jq '[.[].num]')

echo "$all_ws" | python3 -c "
import json, sys

max_ws = ${MAX_WORKSPACES}
existing = json.loads(sys.stdin.read())
base = list(range(1, max_ws + 1))
extras = sorted(n for n in existing if n > max_ws)
result = base + extras
print(json.dumps(result))
"
