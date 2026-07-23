#!/bin/bash

offset_file="/tmp/waybar_calendar_offset"
offset=0
[ -f "$offset_file" ] && offset=$(cat "$offset_file")

target_date=$(date -d "$offset months" '+%Y-%m-01')
month=$(date -d "$target_date" '+%B %Y')
year=$(date -d "$target_date" '+%Y')
month_num=$(date -d "$target_date" '+%m')

calendar=$(cal -m "$month_num" "$year" 2>/dev/null || cal "$month_num" "$year")
calendar=$(echo "$calendar" | tail -n +2 | head -n -1)

today=$(date +'%e' | tr -d ' ')
padded_today=$(printf "%2d" "$today")
current_ym=$(date +'%Y%m')
target_ym=$(date -d "$target_date" +'%Y%m')

highlighted=""
while IFS= read -r line; do
  if [ "$current_ym" = "$target_ym" ]; then
    highlighted_line=$(echo "$line" | sed -E "s/(^| )(${padded_today})( |$)/\1<span weight='bold' color='#df6124'>\2<\/span>\3/")
  else
    highlighted_line="$line"
  fi
  highlighted+="${highlighted_line}\n"
done <<< "$calendar"

day=$(date +'%a %d')
tooltip="<big><b>${month}</b></big>\n<tt>${highlighted}</tt>"

if [ "$offset" != 0 ]; then
  printf '{"text":"%s","tooltip":"%s","class":"calendar-alt"}\n' "$day" "$tooltip"
else
  printf '{"text":"%s","tooltip":"%s","class":"calendar"}\n' "$day" "$tooltip"
fi
