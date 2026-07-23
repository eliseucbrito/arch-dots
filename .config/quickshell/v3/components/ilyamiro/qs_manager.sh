#!/usr/bin/env bash

# Mock qs_manager.sh to handle widget states via /tmp/qs_widget_state
# Expected usage: qs_manager.sh toggle <widget> or qs_manager.sh <widget>
# Close command: qs_manager.sh close

COMMAND=$1
WIDGET=$2

if [ "$COMMAND" = "close" ]; then
    echo "close" > /tmp/qs_widget_state
    exit 0
fi

# Detect if the command is just a workspace number
if [[ "$COMMAND" =~ ^[0-9]+$ ]]; then
    hyprctl dispatch workspace "$COMMAND"
    exit 0
fi

if [ "$COMMAND" = "toggle" ]; then
    echo "$WIDGET" > /tmp/qs_widget_state
else
    echo "$COMMAND" > /tmp/qs_widget_state
fi
