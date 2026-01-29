#!/bin/bash
templates="$HOME/.cache/m3-colors/"
gtk320_dir="$HOME/.local/share/themes/FlatColor/gtk-3.20"
cp "$templates/gtk.3.20-$M3_MODE" "$gtk320_dir/gtk.css"
