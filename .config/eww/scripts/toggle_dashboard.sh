#!/bin/bash
WINDOW="performance_monitor"

if eww active-windows | grep -q "$WINDOW"; then
    eww update performance_monitor_visible=false
    eww close "$WINDOW"
else
    eww update performance_monitor_visible=true
    eww open "$WINDOW"
fi
