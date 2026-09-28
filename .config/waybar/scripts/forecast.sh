#!/bin/bash

CACHE_FILE="/tmp/waybar-weather-cache.json"
CACHE_MAX_AGE=$((30 * 60))
LOCATION="${WAYBAR_WEATHER_LOCATION:-Chongqing}"

now=$(date +%s)

get_weather_data() {
  curl -fsS --max-time 8 "https://wttr.in/${LOCATION}?format=j1" 2>/dev/null
}

cached_data=""
if [[ -f "$CACHE_FILE" ]]; then
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  if (( now - cache_mtime < CACHE_MAX_AGE )); then
    cached_data=$(cat "$CACHE_FILE")
  fi
fi

if [[ -z "$cached_data" ]]; then
  fresh_data=$(get_weather_data)
  if [[ -n "$fresh_data" ]] && echo "$fresh_data" | jq -e '.weather' >/dev/null 2>&1; then
    echo "$fresh_data" > "$CACHE_FILE"
    raw_data="$fresh_data"
  elif [[ -f "$CACHE_FILE" ]]; then
    raw_data=$(cat "$CACHE_FILE")
  else
    printf '{"text":"󰖐","tooltip":"Weather unavailable","class":"unavailable"}\n'
    exit 0
  fi
else
  raw_data="$cached_data"
fi

current_temp=$(echo "$raw_data" | jq -r '.current_condition[0].temp_C // empty')
weather_code=$(echo "$raw_data" | jq -r '.current_condition[0].weatherCode // empty')
current_desc=$(echo "$raw_data" | jq -r '.current_condition[0].weatherDesc[0].value // empty')
humidity=$(echo "$raw_data" | jq -r '.current_condition[0].humidity // empty')
windspeed=$(echo "$raw_data" | jq -r '.current_condition[0].windspeedKmph // empty')

sunrise=$(echo "$raw_data" | jq -r '.weather[0].astronomy[0].sunrise // empty')
sunset=$(echo "$raw_data" | jq -r '.weather[0].astronomy[0].sunset // empty')

now_epoch=$(date +%s)
sunrise_epoch=$(date -d "today $sunrise" +%s 2>/dev/null || echo 0)
sunset_epoch=$(date -d "today $sunset" +%s 2>/dev/null || echo 0)
if (( sunrise_epoch > 0 && sunset_epoch > 0 && (now_epoch < sunrise_epoch || now_epoch >= sunset_epoch) )); then
  night=true
else
  night=false
fi

get_weather_icon() {
  local code="$1"
  local night="$2"
  case $code in
    113) [[ $night == "true" ]] && echo "" || echo "" ;;
    116) [[ $night == "true" ]] && echo "" || echo "" ;;
    119|122) echo "" ;;
    143|248|260) echo "" ;;
    176|263|266|293|296|353) [[ $night == "true" ]] && echo "" || echo "" ;;
    179|227|230|323|326|368) [[ $night == "true" ]] && echo "" || echo "" ;;
    182|185|281|284|311|314|317|320|350|362|365|374|377) echo "" ;;
    200|386|389|392|395) echo "" ;;
    299|302|305|308|356|359) echo "" ;;
    329|332|335|338|371) echo "" ;;
    *) echo "" ;;
  esac
}

icon=$(get_weather_icon "$weather_code" "$night")

tooltip="<b>${current_desc}, ${current_temp}°C</b>\n"
tooltip+="Humidity: ${humidity}%  ·  Wind: ${windspeed}km/h\n"
tooltip+="\n<b>Next hours:</b>\n"

hourly=$(echo "$raw_data" | jq -r '.weather[0].hourly[:8][] | [.time, .weatherCode, .tempC, .weatherDesc[0].value, .precipMM] | @tsv')

while IFS=$'\t' read -r time code temp desc precip; do
  [[ -z "$time" ]] && continue
  hour_num=$((10#$time / 100))
  pad_time=$(printf "%02d:00" "$hour_num")
  hour_icon=$(get_weather_icon "$code" "false")
  rain_info=""
  precip_val="${precip:-0}"
  if [[ "$precip_val" != "0" && "$precip_val" != "0.0" && -n "$precip_val" ]]; then
    rain_info="  ${precip_val}mm"
  fi
  tooltip+="${hour_icon}  ${pad_time}  ${temp}°C  ${desc}${rain_info}\n"
done <<< "$hourly"

printf '{"text":"%s %s°","tooltip":"%s","class":"available"}\n' "$icon" "$current_temp" "$tooltip"
