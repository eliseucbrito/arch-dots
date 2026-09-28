#!/usr/bin/env bash
set -euo pipefail

conf=/etc/sddm.conf.d/autologin.conf

sudo sed -i 's/^Session=.*/Session=niri.desktop/' "$conf"
echo "Sessão de autologin definida para niri (niri.desktop):"
cat "$conf"
echo
echo "Faça logout/reboot para aplicar."
