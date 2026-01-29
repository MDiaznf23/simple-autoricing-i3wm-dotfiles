#!/bin/bash
templates="$HOME/.cache/m3-colors"
gtk3_dir="$HOME/.local/share/themes/FlatColor/gtk-3.0"
cp "$templates/gtk-$M3_MODE.css" "$gtk3_dir/gtk.css"
