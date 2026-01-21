#!/bin/bash

# SETTINGS vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

source "$HOME/.cache/m3-colors/colors.sh"

# API settings ________________________________________________________________

# Open-Meteo 
CITY_NAME='Jakarta'
COUNTRY_CODE='ID'

# FILL WITH LATITUDE AND LONGITUDE
LATITUDE="-6.17511"  # Semarang latitude
LONGITUDE="106.86504"  # Semarang longitude

# Desired output language 
LANG="en"

# UNITS: "metric" or "imperial"
UNITS="metric"

# Color Settings ______________________________________________________________

COLOR_CLOUD="$color7"           
COLOR_THUNDER="$color7"         
COLOR_LIGHT_RAIN="$color7"     
COLOR_HEAVY_RAIN="$color7"    
COLOR_SNOW="$color7"            
COLOR_FOG="$color7"            
COLOR_TORNADO="$color7"        
COLOR_SUN="$color7"            
COLOR_MOON="$color7"            
COLOR_ERR="$color7"             
COLOR_WIND="$color7"           
COLOR_COLD="$color7"            
COLOR_HOT="$color7"             
COLOR_NORMAL_TEMP="$color7"     

COLOR_TEXT=""

# Polybar settings ____________________________________________________________

# Font for the weather icons
WEATHER_FONT_CODE=2

# Font for the thermometer icon
TEMP_FONT_CODE=2

# Wind settings _______________________________________________________________

# Display info about the wind or not. yes/no
DISPLAY_WIND="yes"

# Show beaufort level in windicon
BEAUFORTICON="yes"

# Display in knots. yes/no
KNOTS="yes"

# How many decimals after the floating point
DECIMALS=0

# Min. wind force required to display wind info
MIN_WIND=11

# Display the numeric wind force or not. yes/no
DISPLAY_FORCE="yes"

# Display the wind unit if wind force is displayed. yes/no
DISPLAY_WIND_UNIT="yes"

# Thermometer settings ________________________________________________________

# When the thermometer icon turns red
HOT_TEMP=25

# When the thermometer icon turns blue
COLD_TEMP=0

# Other settings ______________________________________________________________

# Display the weather description. yes/no
DISPLAY_LABEL="yes"

# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

if [ "$COLOR_TEXT" != "" ]; then
    COLOR_TEXT_BEGIN="%{F$COLOR_TEXT}"
    COLOR_TEXT_END="%{F-}"
fi

# Jika latitude/longitude tidak diisi, coba gunakan geocoding
if [ -z "$LATITUDE" ] || [ -z "$LONGITUDE" ]; then
    if [ -z "$CITY_NAME" ]; then
        # Jika city juga kosong, gunakan IP location
        IP=`curl -s ifconfig.me`
        IPCURL=$(curl -s https://ipinfo.io/$IP)
        CITY_NAME=$(echo $IPCURL | jq -r ".city")
        COUNTRY_CODE=$(echo $IPCURL | jq -r ".country")
    fi
    
    # Gunakan Open-Meteo Geocoding API untuk mendapatkan koordinat
    GEOCODE_URL="https://geocoding-api.open-meteo.com/v1/search?name=$CITY_NAME&count=1&language=en&format=json"
    GEOCODE_RESPONSE=`curl -s "$GEOCODE_URL"`
    
    if [ "$1" = "-d" ]; then
        echo "Geocoding response: $GEOCODE_RESPONSE"
    fi
    
    LATITUDE=$(echo $GEOCODE_RESPONSE | jq -r '.results[0].latitude')
    LONGITUDE=$(echo $GEOCODE_RESPONSE | jq -r '.results[0].longitude')
    
    if [ "$LATITUDE" = "null" ] || [ "$LONGITUDE" = "null" ]; then
        echo "Error: Could not find coordinates for $CITY_NAME"
        exit 1
    fi
fi

RESPONSE=""
ERROR=0
ERR_MSG=""

# Temperature unit untuk Open-Meteo
if [ "$UNITS" = "imperial" ]; then
    TEMP_UNIT_PARAM="temperature_unit=fahrenheit"
else
    TEMP_UNIT_PARAM="temperature_unit=celsius"
fi

# Wind speed unit untuk Open-Meteo
if [ $KNOTS == "yes" ]; then
    WIND_UNIT_PARAM="windspeed_unit=kn"
elif [ "$UNITS" = "imperial" ]; then
    WIND_UNIT_PARAM="windspeed_unit=mph"
else
    WIND_UNIT_PARAM="windspeed_unit=kmh"
fi

# Open-Meteo API URL
URL="https://api.open-meteo.com/v1/forecast?latitude=$LATITUDE&longitude=$LONGITUDE&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&daily=sunrise,sunset&${TEMP_UNIT_PARAM}&${WIND_UNIT_PARAM}&timezone=auto"

function getData {
    ERROR=0
    RESPONSE=`curl -s "$URL"`
    CODE="$?"
    
    if [ "$1" = "-d" ]; then
        echo "URL: $URL"
        echo "Response: $RESPONSE"
        echo ""
    fi
    
    if [ $CODE -ne 0 ]; then
        ERR_MSG="curl Error $CODE"
        ERROR=1
    elif [ -z "$RESPONSE" ]; then
        ERR_MSG="Empty Response"
        ERROR=1
    else
        # Check if response contains error
        HAS_ERROR=$(echo $RESPONSE | jq -r '.error // false')
        if [ "$HAS_ERROR" = "true" ]; then
            ERR_MSG="API Error"
            ERROR=1
        fi
    fi
}

function setIcons {
    # WMO Weather interpretation codes (WW)
    # 0: Clear sky
    # 1-3: Mainly clear, partly cloudy, and overcast
    # 45, 48: Fog
    # 51-57: Drizzle
    # 61-67: Rain
    # 71-77: Snow
    # 80-82: Rain showers
    # 85-86: Snow showers
    # 95-99: Thunderstorm
    
    WID=$1
    DATE=$(date +%s)
    
    if [ $WID -ge 95 ]; then
        # Thunderstorm
        ICON_COLOR=$COLOR_THUNDER
        if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
            ICON=" "
        else
            ICON=" "
        fi
    elif [ $WID -ge 85 ]; then
        # Snow showers
        ICON_COLOR=$COLOR_SNOW
        ICON=" "
    elif [ $WID -ge 80 ]; then
        # Rain showers
        ICON_COLOR=$COLOR_HEAVY_RAIN
        if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
            ICON="殺"
        else
            ICON="殺"
        fi
    elif [ $WID -ge 71 ]; then
        # Snow
        ICON_COLOR=$COLOR_SNOW
        ICON=" "
    elif [ $WID -ge 61 ]; then
        # Rain
        ICON_COLOR=$COLOR_HEAVY_RAIN
        if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
            ICON=" "
        else
            ICON=" "
        fi
    elif [ $WID -ge 51 ]; then
        # Drizzle
        ICON_COLOR=$COLOR_LIGHT_RAIN
        if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
            ICON=" "
        else
            ICON=" "
        fi
    elif [ $WID -ge 45 ]; then
        # Fog
        ICON_COLOR=$COLOR_FOG
        ICON=" "
    elif [ $WID -eq 0 ]; then
        # Clear sky
        if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
            ICON_COLOR=$COLOR_SUN
            ICON=" "
        else
            ICON_COLOR=$COLOR_MOON
            ICON=" "
        fi
    elif [ $WID -ge 1 ] && [ $WID -le 3 ]; then
        # Partly cloudy to overcast
        if [ $WID -eq 1 ]; then
            # Few clouds
            if [ $DATE -ge $SUNRISE -a $DATE -le $SUNSET ]; then
                ICON_COLOR=$COLOR_SUN
                ICON="󰅟 " 
            else
                ICON_COLOR=$COLOR_MOON
                ICON=" "
            fi
        else
            # Overcast
            ICON_COLOR=$COLOR_CLOUD
            ICON="󰅟 " 
        fi
    else
        ICON_COLOR=$COLOR_ERR
        ICON=" "
    fi
    
    WIND=""
    WINDFORCE=$WINDFORCE_ACTUAL
    WINDICON=" "
    
    if [ $BEAUFORTICON == "yes" ]; then
        # Convert to km/h for Beaufort calculation
        if [ $KNOTS == "yes" ]; then
            WINDFORCE2=$(echo "scale=2;$WINDFORCE_ACTUAL * 1.852 / 1" | bc)
        elif [ "$UNITS" = "imperial" ]; then
            WINDFORCE2=$(echo "scale=2;$WINDFORCE_ACTUAL * 1.60934 / 1" | bc)
        else
            WINDFORCE2=$WINDFORCE_ACTUAL
        fi
        
        if (( $(echo "$WINDFORCE2 <= 1" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 1 && $WINDFORCE2 <= 5" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 5 && $WINDFORCE2 <= 11" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 11 && $WINDFORCE2 <= 19" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 19 && $WINDFORCE2 <= 28" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 28 && $WINDFORCE2 <= 38" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 38 && $WINDFORCE2 <= 49" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 49 && $WINDFORCE2 <= 61" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 61 && $WINDFORCE2 <= 74" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 74 && $WINDFORCE2 <= 88" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 88 && $WINDFORCE2 <= 102" | bc -l) )); then
            WINDICON=" "
        elif (( $(echo "$WINDFORCE2 > 102 && $WINDFORCE2 <= 117" | bc -l) )); then
            WINDICON=" "
        else
            WINDICON=" "
        fi
    fi
    
    WINDFORCE=$(echo "scale=$DECIMALS;$WINDFORCE / 1" | bc)
    
    if [ "$DISPLAY_WIND" == "yes" ] && (( $(echo "$WINDFORCE >= $MIN_WIND" | bc -l) )); then
        WIND="%{T$WEATHER_FONT_CODE}%{F$COLOR_WIND}$WINDICON%{F-}%{T-}"
        if [ "$DISPLAY_FORCE" == "yes" ]; then
            WIND="$WIND $COLOR_TEXT_BEGIN$WINDFORCE$COLOR_TEXT_END"
            if [ "$DISPLAY_WIND_UNIT" == "yes" ]; then
                if [ $KNOTS == "yes" ]; then
                    WIND="$WIND ${COLOR_TEXT_BEGIN}kn$COLOR_TEXT_END"
                elif [ $UNITS == "imperial" ]; then
                    WIND="$WIND ${COLOR_TEXT_BEGIN}mph$COLOR_TEXT_END"
                else
                    WIND="$WIND ${COLOR_TEXT_BEGIN}km/h$COLOR_TEXT_END"
                fi
            fi
        fi
        WIND="$WIND |"
    fi
    
    if [ "$UNITS" == "imperial" ]; then
        TEMP_UNIT="°F"
    else
        TEMP_UNIT="°C"
    fi
    
    TEMP=$(echo "$TEMP" | cut -d "." -f 1)
    
    if [ "$TEMP" -le $COLD_TEMP ]; then
        TEMP="%{F$COLOR_COLD}%{T$TEMP_FONT_CODE}%{T-}%{F-} $COLOR_TEXT_BEGIN$TEMP%{T$TEMP_FONT_CODE}$TEMP_ICON%{T-}$TEMP_UNIT$COLOR_TEXT_END"
    elif (( $(echo "$TEMP >= $HOT_TEMP" | bc -l) )); then
        TEMP="%{F$COLOR_HOT}%{T$TEMP_FONT_CODE}%{T-}%{F-} $COLOR_TEXT_BEGIN$TEMP%{T$TEMP_FONT_CODE}$TEMP_ICON%{T-}$TEMP_UNIT$COLOR_TEXT_END"
    else
        TEMP="%{F$COLOR_NORMAL_TEMP}%{T$TEMP_FONT_CODE}%{T-}%{F-} $COLOR_TEXT_BEGIN$TEMP%{T$TEMP_FONT_CODE}$TEMP_ICON%{T-}$TEMP_UNIT$COLOR_TEXT_END"
    fi
}

function outputCompact {
    OUTPUT="%{T$WEATHER_FONT_CODE}%{F$ICON_COLOR}$ICON%{F-}%{T-} $ERR_MSG$COLOR_TEXT_BEGIN$DESCRIPTION$COLOR_TEXT_END"
    echo "$OUTPUT"
}

# Weather code description mapping
function getWeatherDescription {
    local code=$1
    case $code in
        0) echo "Clear";;
        1) echo "Mainly Clear";;
        2) echo "Partly Cloudy";;
        3) echo "Overcast";;
        45|48) echo "Foggy";;
        51) echo "Light Drizzle";;
        53) echo "Moderate Drizzle";;
        55) echo "Dense Drizzle";;
        56|57) echo "Freezing Drizzle";;
        61) echo "Slight Rain";;
        63) echo "Moderate Rain";;
        65) echo "Heavy Rain";;
        66|67) echo "Freezing Rain";;
        71) echo "Slight Snow";;
        73) echo "Moderate Snow";;
        75) echo "Heavy Snow";;
        77) echo "Snow Grains";;
        80) echo "Slight Showers";;
        81) echo "Moderate Showers";;
        82) echo "Violent Showers";;
        85) echo "Slight Snow Showers";;
        86) echo "Heavy Snow Showers";;
        95) echo "Thunderstorm";;
        96) echo "Thunderstorm Light Hail";;
        99) echo "Thunderstorm Heavy Hail";;
        *) echo "Unknown";;
    esac
}

getData $1

if [ $ERROR -eq 0 ]; then
    # Parse current weather dari Open-Meteo
    TEMP=$(echo $RESPONSE | jq -r '.current.temperature_2m')
    WID=$(echo $RESPONSE | jq -r '.current.weather_code')
    WINDFORCE_ACTUAL=$(echo $RESPONSE | jq -r '.current.wind_speed_10m')
    HUMIDITY=$(echo $RESPONSE | jq -r '.current.relative_humidity_2m')
    
    # Parse sunrise/sunset (dalam format ISO8601)
    SUNRISE_ISO=$(echo $RESPONSE | jq -r '.daily.sunrise[0]')
    SUNSET_ISO=$(echo $RESPONSE | jq -r '.daily.sunset[0]')
    
    # Convert ISO8601 to unix timestamp
    SUNRISE=$(date -d "$SUNRISE_ISO" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M" "$SUNRISE_ISO" +%s 2>/dev/null || echo "0")
    SUNSET=$(date -d "$SUNSET_ISO" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M" "$SUNSET_ISO" +%s 2>/dev/null || echo "0")
    
    if [ $DISPLAY_LABEL = "yes" ]; then
        DESCRIPTION=$(getWeatherDescription $WID)" "
    else
        DESCRIPTION=""
    fi
    
    WIND=""
    setIcons $WID
    outputCompact
else
    echo " "
fi
