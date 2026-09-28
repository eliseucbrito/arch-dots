#!/bin/bash

DB="$HOME/.local/share/opencode/opencode.db"

if [[ ! -f "$DB" ]]; then
  printf '{"text":"󱂛","tooltip":"OpenCode DB not found","class":"unavailable"}\n'
  exit 0
fi

format_tokens() {
  local tokens=$1
  if (( tokens >= 1000000 )); then
    local m=$(( tokens / 100000 ))
    printf "%d.%dM" $(( m / 10 )) $(( m % 10 ))
  elif (( tokens >= 1000 )); then
    printf "%dK" $(( tokens / 1000 ))
  else
    printf "%d" "$tokens"
  fi
}

now_ms=$(date +%s%3N)
day_ago=$(( now_ms - 86400000 ))
week_ago=$(( now_ms - 604800000 ))
month_ago=$(( now_ms - 2592000000 ))

daily_row=$(sqlite3 "$DB" "SELECT COALESCE(SUM(tokens_input),0), COALESCE(SUM(tokens_output),0), COALESCE(SUM(tokens_reasoning),0), COALESCE(SUM(tokens_cache_read),0), COALESCE(SUM(tokens_cache_write),0), COUNT(*) FROM session WHERE time_created >= $day_ago;" 2>/dev/null)

weekly_row=$(sqlite3 "$DB" "SELECT COALESCE(SUM(tokens_input),0), COALESCE(SUM(tokens_output),0), COALESCE(SUM(tokens_reasoning),0), COALESCE(SUM(tokens_cache_read),0), COALESCE(SUM(tokens_cache_write),0), COUNT(*) FROM session WHERE time_created >= $week_ago;" 2>/dev/null)

monthly_row=$(sqlite3 "$DB" "SELECT COALESCE(SUM(tokens_input),0), COALESCE(SUM(tokens_output),0), COALESCE(SUM(tokens_reasoning),0), COALESCE(SUM(tokens_cache_read),0), COALESCE(SUM(tokens_cache_write),0), COUNT(*) FROM session WHERE time_created >= $month_ago;" 2>/dev/null)

parse_row() {
  local row="$1"
  IFS='|' read -r in out reas cache_r cache_w count <<< "$row"
  local total=$(( in + out + reas + cache_r + cache_w ))
  echo "$total|$count|$in|$out|$reas|$cache_r|$cache_w"
}

daily_parsed=$(parse_row "$daily_row")
IFS='|' read -r daily_tok daily_sess daily_in daily_out daily_reas daily_cr daily_cw <<< "$daily_parsed"

weekly_parsed=$(parse_row "$weekly_row")
IFS='|' read -r weekly_tok weekly_sess weekly_in weekly_out weekly_reas weekly_cr weekly_cw <<< "$weekly_parsed"

monthly_parsed=$(parse_row "$monthly_row")
IFS='|' read -r monthly_tok monthly_sess monthly_in monthly_out monthly_reas monthly_cr monthly_cw <<< "$monthly_parsed"

d_label=$(format_tokens "$daily_tok")
w_label=$(format_tokens "$weekly_tok")
m_label=$(format_tokens "$monthly_tok")

bar_text="D:${d_label}"
tooltip="<b>OpenCode Token Usage</b>\n"

tooltip+="\n<b>Today</b> (${daily_sess} sessions)\n"
tooltip+="  Input:    $(format_tokens "$daily_in")\n"
tooltip+="  Output:   $(format_tokens "$daily_out")\n"
tooltip+="  Reasoning: $(format_tokens "$daily_reas")\n"
tooltip+="  Cache R/W: $(format_tokens "$daily_cr")/$(format_tokens "$daily_cw")\n"
tooltip+="  Total:    <b>${d_label}</b>\n"

tooltip+="\n<b>This Week</b> (${weekly_sess} sessions)\n"
tooltip+="  Input:    $(format_tokens "$weekly_in")\n"
tooltip+="  Output:   $(format_tokens "$weekly_out")\n"
tooltip+="  Reasoning: $(format_tokens "$weekly_reas")\n"
tooltip+="  Cache R/W: $(format_tokens "$weekly_cr")/$(format_tokens "$weekly_cw")\n"
tooltip+="  Total:    <b>${w_label}</b>\n"

tooltip+="\n<b>This Month</b> (${monthly_sess} sessions)\n"
tooltip+="  Input:    $(format_tokens "$monthly_in")\n"
tooltip+="  Output:   $(format_tokens "$monthly_out")\n"
tooltip+="  Reasoning: $(format_tokens "$monthly_reas")\n"
tooltip+="  Cache R/W: $(format_tokens "$monthly_cr")/$(format_tokens "$monthly_cw")\n"
tooltip+="  Total:    <b>${m_label}</b>\n"

printf '{"text":"\uF1C6 %s","tooltip":"%s","class":"available"}\n' "$bar_text" "$tooltip"
