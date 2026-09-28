#!/usr/bin/env bash

# =========================================================
# Toggle de proteção de visão (wlsunset) para a barra do niri.
# Substitui o "omarchy toggle nightlight" (hyprsunset), que depende do
# protocolo hyprland-ctm-control-v1 e não funciona sob niri.
#
# Sem argumento -> imprime JSON de status para a barra.
# toggle        -> liga/desliga o serviço wlsunset (systemd --user).
# =========================================================

UNIT="wlsunset.service"

is_active() { systemctl --user is-active --quiet "$UNIT"; }

toggle() {
    if is_active; then
        systemctl --user stop "$UNIT"
    else
        systemctl --user start "$UNIT"
    fi
}

print_status() {
    if is_active; then
        printf '{"text":"󰛨","class":"active","tooltip":"Proteção de visão: ligada\\nClique para desligar"}\n'
    else
        printf '{"text":"󰛩","class":"inactive","tooltip":"Proteção de visão: desligada\\nClique para ligar"}\n'
    fi
}

case "$1" in
    toggle) toggle ;;
    *)      print_status ;;
esac
