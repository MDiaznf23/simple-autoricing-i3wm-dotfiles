#!/bin/bash

# Fungsi untuk get workspace state
get_workspaces() {
    i3-msg -t get_workspaces | jq -c '
        map({
            num: .num,
            name: .name,
            focused: .focused,
            urgent: .urgent,
            visible: .visible,
            output: .output
        })'
}

# Output initial state
get_workspaces

# Subscribe to workspace events
i3-msg -t subscribe -m '["workspace"]' | while read -r line; do
    get_workspaces
done
