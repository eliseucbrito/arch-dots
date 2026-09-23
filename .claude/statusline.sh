#!/usr/bin/env bash
# Wrapper around claude-powerline: appends a SANDBOX ON/OFF flag to line 1.
# ON  -> green, shown when running under `claude --sandbox` (nono).
# OFF -> strong red, shown otherwise.
# The env var is exported by the `claude` fish function's sandbox branch.
set -euo pipefail

payload=$(cat)

base=$(printf '%s' "$payload" | claude-powerline --config="${HOME}/.claude/claude-powerline.json")

if [[ "${NONO_SANDBOX_ACTIVE:-}" == "on" ]]; then
  chunk=$'\033[0m\033[48;2;46;160;67m\033[38;2;255;255;255m SANDBOX ON \033[0m'
else
  chunk=$'\033[0m\033[48;2;204;0;0m\033[38;2;255;255;255m SANDBOX OFF \033[0m'
fi

# Splice the chunk in just before the first line break.
if [[ "$base" == *$'\n'* ]]; then
  printf '%s%s\n%s' "${base%%$'\n'*}" "$chunk" "${base#*$'\n'}"
else
  printf '%s%s' "$base" "$chunk"
fi
