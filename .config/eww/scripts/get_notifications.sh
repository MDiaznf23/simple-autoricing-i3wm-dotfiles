#!/bin/bash

get_notifs() {
  dunstctl history 2>/dev/null | jq -c --arg mode "$1" --argjson n 10 '
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
}

MODE=${1:-"all"}

prev=""

emit() {
  current=$(get_notifs "$MODE")
  if [[ "$current" != "$prev" ]]; then
    echo "$current"
    prev="$current"
  fi
}

emit

dbus-monitor --session \
  "interface='org.freedesktop.Notifications',member='Notify'" \
  "interface='org.dunstproject.cmd0'" 2>/dev/null | \
while read -r _; do
  emit
done
