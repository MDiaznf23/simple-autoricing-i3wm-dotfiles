#!/bin/bash
templates="$HOME/.cache/m3-colors"
gtkrc_dir="$HOME/.local/share/themes/FlatColor/gtk-2.0"
cp "$templates/gtkrc-$M3_MODE" "$gtkrc_dir/gtkrc"
