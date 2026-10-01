#!/usr/bin/env bash

# =========================================================
# VPN CIn (IKEv2/strongSwan) para o widget de barra ecb-vpn (Noctalia)
#
# O runtime Luau do Noctalia não escreve em stdin de subprocessos, então a
# senha nunca passa pelo plugin: fica guardada no Secret Service do sistema
# (o mesmo keyring que o próprio Noctalia usa) e este script a lê de lá.
#
#   status               -> imprime JSON de status para a barra.
#   connect              -> conecta a VPN definida em ~/.vpn/ikev2.list.
#   disconnect           -> encerra a VPN ativa.
#   set-password <senha> -> grava a senha no Secret Service (via stdin/argv do CLI, não do plugin).
#   has-password         -> exit 0 se já existe senha salva.
#
# Comandos privilegiados (swanctl/ip/resolvectl) rodam via `sudo -n`,
# liberado sem senha por /etc/sudoers.d (ver ~/.vpn/vpn-install-root.sh).
# =========================================================

set -u

VPN_DIR="$HOME/.vpn"
IKE_LIST="$VPN_DIR/ikev2.list"
IKE_RT_TABLE=220   # tabela onde o strongSwan instala a rota do túnel (charon.routing_table)
SECRET_SCHEMA="cin.ufpe.vpn"

notify() { notify-send -a "VPN CIn" "$1" "$2"; }
refresh() { noctalia msg plugin ecb/vpn:widget refresh >/dev/null 2>&1 || true; }

have_swanctl() { command -v swanctl >/dev/null 2>&1; }

# ---------- conexão configurada ----------
ike_conn_name() { grep -vE '^\s*(#|$)' "$IKE_LIST" 2>/dev/null | head -n1; }

ike_login() {
    awk -F'=' '/eap_id[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2;exit}' \
        "$VPN_DIR/swanctl/conns.conf" 2>/dev/null
}

# ---------- estado ----------
ipsec_sas() { have_swanctl && sudo -n swanctl --list-sas 2>/dev/null; }
ipsec_up() { ipsec_sas | grep -qiE 'ESTABLISHED|INSTALLED'; }
ipsec_active_conn() { ipsec_sas | awk -F: 'NR==1{print $1; exit}'; }

# ---------- DNS sobre o túnel ----------
default_iface() { ip route show default 2>/dev/null | awk '{print $5; exit}'; }

apply_dns() {
    local name="$1" f="$VPN_DIR/$name.dns" iface servers domains
    [ -r "$f" ] || return 0
    servers="$(awk -F= '/^servers=/{print $2}' "$f")"
    domains="$(awk -F= '/^domains=/{print $2}' "$f")"
    iface="$(default_iface)"; [ -z "$iface" ] && return 0
    command -v resolvectl >/dev/null 2>&1 || return 0
    [ -n "$servers" ] && sudo -n resolvectl dns "$iface" $servers 2>/dev/null
    # Sem '~.' de propósito: evita full-tunnel de DNS, só os domínios do CIn
    # passam a resolver pelo túnel.
    [ -n "$domains" ] && sudo -n resolvectl domain "$iface" $domains 2>/dev/null
    return 0
}

revert_dns() {
    local iface; iface="$(default_iface)"
    [ -n "$iface" ] && command -v resolvectl >/dev/null 2>&1 \
        && sudo -n resolvectl revert "$iface" 2>/dev/null
    return 0
}

# ---------- roteamento do túnel ----------
# strongSwan instala a rota default do túnel na tabela 220, mas sem a ip-rule
# abaixo o kernel nunca consulta essa tabela: nada pega o source do túnel e o
# tráfego para as redes internas do CIn não entra no IPsec.
tunnel_rule_present() { ip rule show 2>/dev/null | grep -q "lookup $IKE_RT_TABLE"; }

apply_route_rule() {
    tunnel_rule_present && return 0
    sudo -n ip rule add to 10.0.0.0/8 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip rule add to 172.16.0.0/12 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip rule add to 192.168.0.0/16 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip route flush cache 2>/dev/null
    return 0
}

revert_route_rule() {
    sudo -n ip rule del to 10.0.0.0/8 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip rule del to 172.16.0.0/12 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip rule del to 192.168.0.0/16 lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip route flush cache 2>/dev/null
    return 0
}

# ---------- senha (Secret Service, nunca disco/argv do plugin) ----------
has_password() {
    secret-tool lookup schema "$SECRET_SCHEMA" login "$(ike_login)" >/dev/null 2>&1
}

set_password() {
    local pw="$1" login
    login="$(ike_login)"
    [ -z "$login" ] && { echo "Login não definido em swanctl/conns.conf" >&2; return 1; }
    printf '%s' "$pw" | secret-tool store --label="VPN CIn ($login)" schema "$SECRET_SCHEMA" login "$login"
}

get_password() {
    secret-tool lookup schema "$SECRET_SCHEMA" login "$(ike_login)" 2>/dev/null
}

# ---------- ações ----------
connect() {
    local name login pw tmp out
    name="$(ike_conn_name)"
    [ -z "$name" ] && { notify "Erro na VPN" "Nenhuma conexão em ~/.vpn/ikev2.list"; return 1; }
    have_swanctl || { notify "VPN" "strongSwan não instalado"; return 1; }
    if ! sudo -n swanctl --version >/dev/null 2>&1; then
        notify "VPN" "sudoers não configurado — rode: sudo ~/.vpn/vpn-install-root.sh"; return 1
    fi
    login="$(ike_login)"
    [ -z "$login" ] || [ "$login" = "SEU_LOGIN" ] && {
        notify "VPN" "Defina seu login em eap_id (~/.vpn/swanctl/conns.conf)"; return 1; }
    pw="$(get_password)"
    [ -z "$pw" ] && { notify "VPN" "Senha não configurada — abra o painel para salvá-la"; return 2; }

    tmp="$(mktemp)"; chmod 600 "$tmp"
    printf 'secrets {\n  eap-rt {\n    id = %s\n    secret = "%s"\n  }\n}\n' "$login" "$pw" > "$tmp"
    sudo -n swanctl --load-creds --file "$tmp" >/dev/null 2>&1
    shred -u "$tmp" 2>/dev/null || rm -f "$tmp"

    out="$(sudo -n swanctl --initiate --child "$name" 2>&1)"
    if ipsec_up; then
        apply_route_rule
        apply_dns "$name"
        notify "VPN conectada" "IKEv2: $name"
    else
        notify "Erro na VPN" "$(printf '%s' "$out" | tail -n1)"
        return 1
    fi
}

disconnect() {
    if ipsec_up; then
        local c; c="$(ipsec_active_conn)"
        sudo -n swanctl --terminate --ike "$c" >/dev/null 2>&1
        revert_route_rule
        revert_dns
        notify "VPN desconectada" "IKEv2 encerrada ($c)"
    fi
}

# ---------- status JSON ----------
print_status() {
    if ipsec_up; then
        printf '{"connected":true,"name":"%s","hasPassword":%s}\n' \
            "$(ipsec_active_conn)" "$(has_password && echo true || echo false)"
    else
        printf '{"connected":false,"name":null,"hasPassword":%s}\n' \
            "$(has_password && echo true || echo false)"
    fi
}

case "${1:-}" in
    status)        print_status ;;
    connect)       connect; refresh ;;
    disconnect)    disconnect; refresh ;;
    set-password)  set_password "${2:-}" ;;
    has-password)  has_password ;;
    *)             echo "usage: vpn.sh {status|connect|disconnect|set-password <pw>|has-password}" >&2; exit 64 ;;
esac
