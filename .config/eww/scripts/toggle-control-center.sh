#!/bin/bash
eww close wifi_window 2>/dev/null
eww close bluetooth_window 2>/dev/null
eww close audio_window 2>/dev/null
eww open --toggle control_center_window
