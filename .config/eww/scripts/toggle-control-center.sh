#!/bin/bash
WINDOW="control_center_window"

if eww active-windows | grep -q "$WINDOW"; then
    eww update control_center_visible=false
    eww close "$WINDOW"
else
    eww update control_center_visible=true
    eww open "$WINDOW"
fi
