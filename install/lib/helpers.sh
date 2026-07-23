#!/usr/bin/env bash

# Colors
readonly RESET="\e[0m"
readonly BOLD="\e[1m"
readonly RED="\e[31m"
readonly GREEN="\e[32m"
readonly YELLOW="\e[33m"
readonly BLUE="\e[34m"
readonly MAGENTA="\e[35m"
readonly CYAN="\e[36m"
readonly GRAY="\e[90m"

log_info()    { echo -e "  ${BLUE}::${RESET} $1"; }
log_success() { echo -e "  ${GREEN}✓${RESET} $1"; }
log_warning() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
log_error()   { echo -e "  ${RED}✗${RESET} $1"; }
log_detail()  { echo -e "  ${GRAY}$1${RESET}"; }
log_step()    { echo -e "\n${BOLD}${CYAN}==>${RESET} ${BOLD}$1${RESET}"; }
log_header()  { echo -e "${BOLD}${MAGENTA}$1${RESET}"; }

is_installed() {
  pacman -Qi "$1" &>/dev/null
}

spinner() {
  local msg="$1"
  shift
  local -a s=('.' '..' '...')
  local i=0
  local delay=0.3
  (
    eval "$@" &>/tmp/spinner.log
  ) &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    echo -ne "\r  ${msg} ${s[$i]}  "
    i=$(((i + 1) % 3))
    sleep "$delay"
  done
  wait "$pid"
  local rc=$?
  echo -ne "\r\033[K"
  return $rc
}

ask_yes_no() {
  local prompt="$1"
  local answer
  while true; do
    read -p "  ${prompt} [y/N]: " answer
    case "$answer" in
      [yY]) return 0 ;;
      [nN]|"") return 1 ;;
    esac
  done
}

ensure_sudo() {
  sudo -v
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" 2>/dev/null || exit
  done 2>/dev/null &
}
