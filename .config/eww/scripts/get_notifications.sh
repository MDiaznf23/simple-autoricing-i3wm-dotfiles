#!/bin/bash
MODE=${1:-"all"}
RECENT_COUNT=10

dunstctl history 2>/dev/null | jq -c --arg mode "$MODE" --argjson n "$RECENT_COUNT" '
  [.data[0][]? | {
    appname: .appname.data,
    summary: .summary.data,
    id: .id.data,
    icon: .icon_path.data,
    time: (.timestamp.data / 1000000000 | strftime("%H:%M"))
  }] |
  if $mode == "recent" then .[:$n]
  elif $mode == "earlier" then .[$n:]
  else . end
' 2>/dev/null || echo '[]'
