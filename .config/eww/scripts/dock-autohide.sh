#!/usr/bin/env bash

SCREEN_HEIGHT=$(xdpyinfo | awk '/dimensions/{print $2}' | cut -d'x' -f2)
THRESHOLD=5
HIDE_DELAY=1.0
dock_visible=false
last_near=false
STATE_FILE=$(mktemp /tmp/dock-state-XXXX)
DOTFILES="$HOME/.config/i3/config-dotfiles"

echo "false" > "$STATE_FILE"

load_dock_enabled() {
  val=$(grep -m1 '^DOCK_ENABLED=' "$DOTFILES" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
  echo "${val:-true}"
}

update_window_state() {
  focused_ws=$(i3-msg -t get_workspaces 2>/dev/null | jq -r '.[] | select(.focused == true) | .name')
  count=$(i3-msg -t get_tree 2>/dev/null | jq --arg ws "$focused_ws" '
    [.. | select(.type? == "workspace" and .name? == $ws) |
    .. | select(
      .window? != null and
      (.window_properties?.class? | ascii_downcase | test("eww") | not)
    )] | length
  ')
  if [ "${count:-0}" -gt 0 ]; then
    echo "true" > "$STATE_FILE"
  else
    echo "false" > "$STATE_FILE"
  fi
}

update_window_state

# Watch config-dotfiles pakai inotify
inotifywait -m -e close_write "$DOTFILES" 2>/dev/null | while read -r _; do
  dock_enabled=$(load_dock_enabled)
  if [ "$dock_enabled" = "false" ]; then
    eww close dock-window
    echo "disabled" > "$STATE_FILE"
  else
    update_window_state
  fi
done &

# Watch i3 events
i3-msg -t subscribe -m '["window", "workspace"]' 2>/dev/null | while read -r _; do
  [ "$(cat $STATE_FILE)" = "disabled" ] && continue
  update_window_state
done &

SUBSCRIBE_PID=$!
trap "kill $SUBSCRIBE_PID 2>/dev/null; rm -f $STATE_FILE" EXIT

# Cek enabled/disabled di awal
dock_enabled=$(load_dock_enabled)

while true; do
  # Kalau disabled, idle saja sambil tetap watch
  if [ "$(cat $STATE_FILE)" = "disabled" ] || [ "$(load_dock_enabled)" = "false" ]; then
    sleep 1
    continue
  fi

  cursor_y=$(xdotool getmouselocation 2>/dev/null | grep -o 'y:[0-9]*' | cut -d':' -f2)
  near_bottom=false
  if [ -n "$cursor_y" ] && [ "$cursor_y" -ge "$((SCREEN_HEIGHT - THRESHOLD))" ]; then
    near_bottom=true
  fi

  workspace_has_window=$(cat "$STATE_FILE")

  if [ "$near_bottom" = "true" ]; then
    if [ "$dock_visible" = "false" ]; then
      eww open dock-window
      dock_visible=true
    fi
    last_near=true

  elif [ "$last_near" = "true" ]; then
    sleep "$HIDE_DELAY"
    cursor_y=$(xdotool getmouselocation 2>/dev/null | grep -o 'y:[0-9]*' | cut -d':' -f2)
    if [ -n "$cursor_y" ] && [ "$cursor_y" -lt "$((SCREEN_HEIGHT - THRESHOLD))" ]; then
      if [ "$workspace_has_window" = "true" ]; then
        eww close dock-window
        dock_visible=false
      fi
    fi
    last_near=false

  else
    if [ "$workspace_has_window" = "true" ]; then
      if [ "$dock_visible" = "true" ]; then
        eww close dock-window
        dock_visible=false
      fi
    else
      if [ "$dock_visible" = "false" ]; then
        eww open dock-window
        dock_visible=true
      fi
    fi
  fi

  sleep 0.2
done
