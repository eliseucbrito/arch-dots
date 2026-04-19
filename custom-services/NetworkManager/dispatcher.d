#!/bin/bash

INTERFACE=$1
ACTION=$2

# Dynamically gets the primary user (assumes the main desktop user is UID 1000)
TARGET_USER=$(id -nu 1000)

if [ "$ACTION" == "up" ]; then
    SSID=$(iwgetid -r)
    if [[ "$SSID" == "MVT-KLE_5G" || "$SSID" == "MVT-KLE_2.4" ]]; then
        # Runs as the target user in the Wayland session
        su - "$TARGET_USER" -c "DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 qbittorrent &"
    fi
elif [ "$ACTION" == "down" ]; then
    # Optional: Kill the process if disconnected from the network
    killall qbittorrent
fi
