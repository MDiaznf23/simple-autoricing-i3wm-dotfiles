#!/bin/bash

# WiFi Scan Script - Cache-First Version (FAST & BATTERY FRIENDLY)

# Check if WiFi is enabled
if [ "$(nmcli radio wifi)" != "enabled" ]; then
    echo "[]"
    exit 0
fi

# Get current connected network
CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)

# Scan without --rescan 
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | \
    grep -v '^$' | \
    awk -F: -v current="$CURRENT_SSID" '
    BEGIN { 
        print "[" 
        first=1
    }
    {
        ssid=$1
        signal=$2
        security=$3
        
        # Skip if SSID is empty or "--"
        if (ssid == "" || ssid == "--") next
        
        # Remove duplicates (keep first occurrence)
        if (seen[ssid]++) next
        
        # Determine if connected
        connected = (ssid == current) ? "true" : "false"
        
        # Determine security icon
        if (security == "" || security == "--") {
            sec_icon = ""
            secured = "false"
        } else {
            sec_icon = ""
            secured = "true"
        }
        
        # Signal strength icon
        if (signal >= 75) sig_icon = " "
          else if (signal >= 50) sig_icon = " "
            else if (signal >= 25) sig_icon = " "
              else sig_icon = " "

        # Print JSON object
        if (!first) print ","
        printf "  {\"ssid\":\"%s\",\"signal\":%d,\"security\":\"%s\",\"secured\":%s,\"connected\":%s,\"sig_icon\":\"%s\",\"sec_icon\":\"%s\"}", 
            ssid, signal, security, secured, connected, sig_icon, sec_icon
        first=0
    }
    END { 
        print ""
        print "]" 
    }'
