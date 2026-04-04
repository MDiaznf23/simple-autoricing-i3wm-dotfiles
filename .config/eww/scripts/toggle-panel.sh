#!/bin/bash

PANEL=$1  # wifi_window / bluetooth_window / audio_window

# Close semua panel dulu
eww close wifi_window
eww close bluetooth_window
eww close audio_window

# Close control center
eww close control_center_window

# Buka panel yang diminta
eww open $PANEL
