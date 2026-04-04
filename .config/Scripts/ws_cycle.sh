#!/bin/bash

source "$HOME/.config/i3/config-dotfiles"

current=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true).num')
direction=$1

if [ "$direction" = "next" ]; then
    if [ "$current" -ge "$MAX_WORKSPACES" ]; then
        next=1
    else
        next=$((current + 1))
    fi
    i3-msg workspace number $next

elif [ "$direction" = "prev" ]; then
    if [ "$current" -gt "$MAX_WORKSPACES" ]; then
        prev=$MAX_WORKSPACES
    elif [ "$current" -le 1 ]; then
        prev=$MAX_WORKSPACES
    else
        prev=$((current - 1))
    fi
    i3-msg workspace number $prev
fi
