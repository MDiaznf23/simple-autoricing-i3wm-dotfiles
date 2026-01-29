#!/bin/bash

while true; do
    if pactl list sink-inputs | grep -q "Corked: no"; then
        echo "▂▃▄▅▄▃▂▁"
        sleep 0.4
        echo "▃▄▅▆▅▄▃▂"
        sleep 0.4
        echo "▄▅▆▇▆▅▄▃"
        sleep 0.4
        echo "▃▄▅▆▅▄▃▂"
        sleep 0.4
    else
        echo "▁▁▁▁▁▁▁▁"
        sleep 1
    fi
done
