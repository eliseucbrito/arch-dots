#!/bin/bash

monitor=$(hyprctl cursorpos -j | python3 -c "
import sys, json, subprocess

cx, cy = json.load(sys.stdin)
monitors = json.loads(subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True).stdout)

for m in monitors:
    if m['x'] <= cx < m['x'] + m['width'] and m['y'] <= cy < m['y'] + m['height']:
        print(m['name'])
        break
")

geo=$(hyprctl monitors -j | python3 -c "
import sys, json

monitors = json.load(sys.stdin)
m = next((x for x in monitors if x['name'] == '$monitor'), monitors[0])
print(f\"{m['x']} {m['y']} {m['width']} {m['height']}\")
")

read -r mx my mw mh <<< "$geo"

bar_top=40
win_w=300
win_h=250

posx=$((mx + mw - win_w - 12))
posy=$((my + bar_top))

yad --calendar --no-buttons --mouse --close-on-unfocus --undecorated \
  --width="$win_w" --height="$win_h" \
  --posx="$posx" --posy="$posy" 2>/dev/null
