#!/usr/bin/env python3
import i3ipc
import sys
import os

config = {}
with open(os.path.expanduser("~/.config/i3/config-dotfiles")) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, val = line.split("=", 1)
            config[key.strip()] = val.strip()

max_ws = int(config.get("MAX_WORKSPACES", 5))

i3 = i3ipc.Connection()
workspaces = i3.get_workspaces()
current = next(ws.num for ws in workspaces if ws.focused)

direction = sys.argv[1] if len(sys.argv) > 1 else "next"

if direction == "next":
    next_ws = 1 if current >= max_ws else current + 1
else:
    next_ws = max_ws if current > max_ws or current <= 1 else current - 1

i3.command(f"workspace number {next_ws}")
