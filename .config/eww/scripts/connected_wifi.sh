#!/bin/bash
# Check if WiFi is enabled
if [ "$(nmcli radio wifi)" != "enabled" ]; then
    echo "[]"
    exit 0
fi

# Get current connected network details directly
nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | \
    awk -F: -v current="$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)" '
    BEGIN { 
        print "[" 
        found=0
    }
    {
        ssid=$1
        signal=$2
        security=$3
        
        # Only process if this is the connected network
        if (ssid != current || ssid == "" || ssid == "--") next
        
        # Determine security icon
        if (security == "" || security == "--") {
            sec_icon = ""
            secured = "false"
        } else {
            sec_icon = ""
            secured = "true"
        }
        
        # Signal strength icon
        if (signal >= 75) sig_icon = " "
          else if (signal >= 50) sig_icon = " "
            else if (signal >= 25) sig_icon = " "
              else sig_icon = " "
        
        # Print JSON object
        printf "  {\"ssid\":\"%s\",\"signal\":%d,\"security\":\"%s\",\"secured\":%s,\"connected\":true,\"sig_icon\":\"%s\",\"sec_icon\":\"%s\"}", 
            ssid, signal, security, secured, sig_icon, sec_icon
        found=1
        exit
    }
    END { 
        print ""
        print "]" 
    }'
