#!/bin/bash
# Usage: ./connect_wifi.sh "SSID" ["password"]
SSID="$1"
PASSWORD="$2"
LOG_FILE="/tmp/wifi_connect.log"

# Function to log messages
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

if [ -z "$SSID" ]; then
    notify-send "WiFi Error" "No SSID provided"
    log_msg "ERROR: No SSID provided"
    exit 1
fi

log_msg "Attempting to connect to: $SSID"

notify-send "WiFi" "Connecting to $SSID..." -t 20000

# Function to prompt for password
prompt_password() {
    local password=""
    if command -v rofi &> /dev/null; then
        password=$(rofi -dmenu -password \
            -p " $SSID" \
            -theme ~/.config/rofi/wifi-password.rasi 2>/dev/null \
            -mesg "Enter WiFi Password")
    elif command -v zenity &> /dev/null; then
        password=$(zenity --password --title="WiFi Password" --text="Enter password for $SSID:" 2>/dev/null)
    else
        notify-send "WiFi Error" "No password input method available"
        log_msg "ERROR: No rofi or zenity available"
        exit 1
    fi
    echo "$password"
}

# Function to wait for connection to be established
wait_for_connection() {
    local max_attempts=20  # 20 attempts * 0.5s = 10 seconds max
    local attempt=0
    
    log_msg "Waiting for connection to establish..."
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if connected to the SSID
        CURRENT_SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d':' -f2)
        
        if [ "$CURRENT_SSID" = "$SSID" ]; then
            log_msg "Connection established successfully"
            return 0
        fi
        
        sleep 0.5
        attempt=$((attempt + 1))
    done
    
    log_msg "Timeout waiting for connection"
    return 1
}

# Check if network is already known
KNOWN=$(nmcli -t -f NAME connection show 2>/dev/null | grep "^${SSID}$")

if [ -n "$KNOWN" ]; then
    log_msg "Network $SSID is known, attempting connection..."
    
    # Try to connect with stored credentials
    ERROR_MSG=$(nmcli connection up "$SSID" 2>&1)
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        notify-send "WiFi Connected" "Connected to $SSID"
        log_msg "SUCCESS: Connected to $SSID"
        exit 0
    else
        log_msg "FAILED: Connection attempt failed with code $EXIT_CODE"
        log_msg "Error message: $ERROR_MSG"
        
        # Check if it's a password/authentication error
        if echo "$ERROR_MSG" | grep -qi "secret\|password\|auth\|802-1x\|psk"; then
            notify-send "WiFi" "Wrong password. Please re-enter..." -t 10000 
            log_msg "Detected authentication error, prompting for new password"
            
            # Prompt for new password
            PASSWORD=$(prompt_password)
            
            if [ -z "$PASSWORD" ]; then
                log_msg "User cancelled password prompt"
                exit 1
            fi
            
            log_msg "Deleting old connection profile..."
            nmcli connection delete "$SSID" 2>&1 | tee -a "$LOG_FILE"
            
            # Small delay to ensure profile is fully deleted
            sleep 0.5
            
            log_msg "Attempting connection with new password..."
            notify-send "WiFi" "Connecting Pass to $SSID..." -t 40000 
            
            ERROR_MSG=$(nmcli device wifi connect "$SSID" password "$PASSWORD" 2>&1)
            EXIT_CODE=$?
            
            if [ $EXIT_CODE -eq 0 ] || echo "$ERROR_MSG" | grep -qi "enqueued"; then
                # Connection command succeeded or was enqueued
                log_msg "Connection initiated, waiting for establishment..."
                
                if wait_for_connection; then
                    notify-send "WiFi Connected" "Successfully connected to $SSID"
                    log_msg "SUCCESS: Connected with new password"
                    exit 0
                else
                    notify-send "WiFi Error" "Connection timeout. Please try again."
                    log_msg "TIMEOUT: Connection not established within timeout period"
                    exit 1
                fi
            else
                notify-send "WiFi Error" "Failed to connect. Check password."
                log_msg "FAILED: Connection command failed"
                log_msg "Error: $ERROR_MSG"
                exit 1
            fi
        else
            # Not a password issue
            notify-send "WiFi Error" "Connection failed (not password issue)"
            log_msg "Non-authentication error detected"
            exit 1
        fi
    fi
fi

# New network, need password
log_msg "New network detected"

if [ -z "$PASSWORD" ]; then
    PASSWORD=$(prompt_password)
    
    if [ -z "$PASSWORD" ]; then
        log_msg "User cancelled password prompt for new network"
        exit 1
    fi
fi

# Connect to new network
log_msg "Connecting to new network..."
notify-send "WiFi" "Connecting to $SSID..."

ERROR_MSG=$(nmcli device wifi connect "$SSID" password "$PASSWORD" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ] || echo "$ERROR_MSG" | grep -qi "enqueued"; then
    log_msg "Connection initiated, waiting for establishment..."
    
    if wait_for_connection; then
        notify-send "WiFi Connected" "Successfully connected to $SSID"
        log_msg "SUCCESS: Connected to new network"
        exit 0
    else
        notify-send "WiFi Error" "Connection timeout. Please try again."
        log_msg "TIMEOUT: Connection not established within timeout period"
        exit 1
    fi
else
    notify-send "WiFi Error" "Failed to connect. Check password/signal."
    log_msg "FAILED: Could not connect to new network"
    log_msg "Error: $ERROR_MSG"
    exit 1
fi
