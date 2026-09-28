#!/usr/bin/env bash
set -euo pipefail

conf=/etc/sddm.conf.d/autologin.conf

sudo sed -i 's/^Session=.*/Session=omarchy.desktop/' "$conf"
echo "Sessão de autologin definida para Hyprland (omarchy.desktop):"
cat "$conf"
echo
echo "Faça logout/reboot para aplicar."
