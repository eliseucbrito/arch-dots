#!/bin/bash

offset_file="/tmp/waybar_calendar_offset"
direction="${1:-reset}"

offset=0
[ -f "$offset_file" ] && offset=$(cat "$offset_file")

case "$direction" in
  up)   offset=$((offset + 1)) ;;
  down) offset=$((offset - 1)) ;;
  reset) offset=0 ;;
esac

echo "$offset" > "$offset_file"

kill -SIGRTMIN+3 "$(pgrep waybar)" 2>/dev/null
