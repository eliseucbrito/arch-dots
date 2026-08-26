#!/usr/bin/env bash

# =========================================================
# VPN toggle/selector para a barra do Omarchy (widget ecb.vpn)
#
# Suporta duas tecnologias, listadas no painel QML do widget:
#   • OpenVPN  — perfis em ~/.vpn/*.ovpn
#   • IKEv2/IPsec (strongSwan) — conexões listadas em ~/.vpn/ikev2.list
#
# Sem argumento        -> imprime JSON de status para a barra.
# list                 -> imprime JSON dos perfis disponíveis + estado atual.
# connect-ovpn <name>  -> conecta o perfil OpenVPN <name>, senha via stdin.
# connect-ike <name>   -> conecta a conexão IKEv2 <name>, senha via stdin.
# disconnect           -> encerra qualquer VPN ativa.
#
# A senha nunca é passada por argv nem gravada em disco: o painel QML a lê
# de um campo de senha e a entrega a este script pelo stdin.
#
# Os comandos privilegiados (swanctl/openvpn) rodam via `sudo -n`,
# liberado sem senha pelo drop-in /etc/sudoers.d/vpn-waybar.
# =========================================================

TUN_IF="tun0"
VPN_DIR="$HOME/.vpn"
IKE_LIST="$VPN_DIR/ikev2.list"
IKE_RT_TABLE=220   # tabela onde o strongSwan instala a rota do túnel (charon.routing_table)

notify() { notify-send -a "VPN" "$1" "$2"; }
refresh() { omarchy-shell -q ecb.vpn refresh; }

have_swanctl() { command -v swanctl >/dev/null 2>&1; }

# ---------- detecção de estado ----------
ovpn_up() { ip link show "$TUN_IF" >/dev/null 2>&1; }

ipsec_sas() { have_swanctl && sudo -n swanctl --list-sas 2>/dev/null; }
ipsec_up() { ipsec_sas | grep -qiE 'ESTABLISHED|INSTALLED'; }
ipsec_active_conn() { ipsec_sas | awk -F: 'NR==1{print $1; exit}'; }

# ---------- listagem de VPNs disponíveis ----------
ovpn_profiles() { ls "$VPN_DIR"/*.ovpn 2>/dev/null; }
ike_conns() { [ -r "$IKE_LIST" ] && grep -vE '^\s*(#|$)' "$IKE_LIST"; }

# lê o eap_id (login) definido em conns.conf
ike_login() {
    awk -F'=' '/eap_id[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2;exit}' \
        "$VPN_DIR/swanctl/conns.conf" 2>/dev/null
}

# ---------- DNS sobre o túnel ----------
# Se existir ~/.vpn/<conexão>.dns (fora do git), aplica os servidores DNS e
# domínios de busca daquela VPN no systemd-resolved. Formato do arquivo:
#     servers=10.0.0.1 10.0.0.2
#     domains=exemplo.com sub.exemplo.com
default_iface() { ip route show default 2>/dev/null | awk '{print $5; exit}'; }

apply_dns() {
    local name="$1" f="$VPN_DIR/$name.dns" iface servers domains
    [ -r "$f" ] || return 0
    servers="$(awk -F= '/^servers=/{print $2}' "$f")"
    domains="$(awk -F= '/^domains=/{print $2}' "$f")"
    iface="$(default_iface)"; [ -z "$iface" ] && return 0
    command -v resolvectl >/dev/null 2>&1 || return 0
    [ -n "$servers" ] && sudo -n resolvectl dns "$iface" $servers 2>/dev/null
    # domínios de busca + '~.' torna esta interface a rota DNS padrão enquanto
    # a VPN está de pé (túnel completo). Ao desconectar, revert_dns restaura.
    [ -n "$domains" ] && sudo -n resolvectl domain "$iface" $domains '~.' 2>/dev/null
    return 0
}

revert_dns() {
    local iface; iface="$(default_iface)"
    [ -n "$iface" ] && command -v resolvectl >/dev/null 2>&1 \
        && sudo -n resolvectl revert "$iface" 2>/dev/null
    return 0
}

# ---------- política de roteamento do túnel ----------
# O strongSwan instala a rota default do túnel na tabela 220 (charon.routing_table),
# mas neste setup a ip-rule que faz o kernel consultar essa tabela não é criada
# sozinha — sem ela nada pega o source do túnel, nenhum pacote casa a policy de
# saída e o tráfego não entra no túnel (hosts internos ficam inalcançáveis e o
# DNS interno fica mudo). Garantimos a regra aqui (idempotente) e a removemos ao
# desconectar. Ver README › VPN › Troubleshooting (bug #2).
tunnel_rule_present() {
    ip rule show 2>/dev/null | grep -qE "lookup ${IKE_RT_TABLE}( |\$)"
}

apply_route_rule() {
    tunnel_rule_present && return 0
    sudo -n ip rule add from all lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null
    sudo -n ip route flush cache 2>/dev/null
    return 0
}

revert_route_rule() {
    while tunnel_rule_present; do
        sudo -n ip rule del from all lookup "$IKE_RT_TABLE" priority "$IKE_RT_TABLE" 2>/dev/null || break
    done
    sudo -n ip route flush cache 2>/dev/null
    return 0
}

# ---------- ações ----------
# Senha lida da primeira linha do stdin (nunca de argv/disco).
connect_ovpn() {
    local name="$1" cfg="$VPN_DIR/$1.ovpn" pw tmp
    [ -r "$cfg" ] || { notify "Erro na VPN" "Perfil OpenVPN não encontrado: $name"; return 1; }
    IFS= read -r pw; [ -z "$pw" ] && return 0
    tmp="$(mktemp)"; chmod 600 "$tmp"; printf '%s\n' "$pw" > "$tmp"
    sudo -n openvpn --config "$cfg" --askpass "$tmp" --daemon
    sleep 2
    shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
    if ovpn_up; then
        notify "VPN conectada" "OpenVPN: $name\n$(ip -4 addr show "$TUN_IF" | awk '/inet /{print $2}')"
    else
        notify "Erro na VPN" "Falha ao conectar OpenVPN ($name)"
    fi
}

connect_ike() {
    local name="$1" login pw tmp out
    have_swanctl || { notify "VPN" "strongSwan não instalado (sudo pacman -S strongswan)"; return 1; }
    if ! sudo -n swanctl --version >/dev/null 2>&1; then
        notify "VPN" "sudoers não configurado — rode: sudo ~/.vpn/vpn-install-root.sh"; return 1
    fi
    login="$(ike_login)"
    [ -z "$login" ] || [ "$login" = "SEU_LOGIN" ] && {
        notify "VPN" "Defina seu login em eap_id (~/.vpn/swanctl/conns.conf)"; return 1; }
    IFS= read -r pw; [ -z "$pw" ] && return 0
    # injeta a credencial só em memória do charon e apaga o arquivo temporário
    tmp="$(mktemp)"; chmod 600 "$tmp"
    printf 'secrets {\n  eap-rt {\n    id = %s\n    secret = "%s"\n  }\n}\n' "$login" "$pw" > "$tmp"
    sudo -n swanctl --load-creds --file "$tmp" >/dev/null 2>&1
    shred -u "$tmp" 2>/dev/null || rm -f "$tmp"
    out="$(sudo -n swanctl --initiate --child "$name" 2>&1)"
    if ipsec_up; then
        apply_route_rule       # garante que o tráfego realmente entre no túnel…
        apply_dns "$name"      # …antes de apontar o DNS para os servidores internos
        notify "VPN conectada" "IKEv2: $name"
    else
        notify "Erro na VPN" "$(printf '%s' "$out" | tail -n1)"
    fi
}

disconnect_all() {
    if ovpn_up; then
        sudo -n pkill -x openvpn
        notify "VPN desconectada" "OpenVPN encerrada"
    fi
    if ipsec_up; then
        local c; c="$(ipsec_active_conn)"
        sudo -n swanctl --terminate --ike "$c" >/dev/null 2>&1
        revert_route_rule
        revert_dns
        notify "VPN desconectada" "IKEv2 encerrada ($c)"
    fi
}

# ---------- listagem (JSON para o painel QML) ----------
json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

print_list() {
    local active="null" entries=() p name c
    if ovpn_up; then
        active="\"$(json_str "$(basename "$(ovpn_profiles | head -n1)" .ovpn)")\""
    elif ipsec_up; then
        active="\"$(json_str "$(ipsec_active_conn)")\""
    fi
    for p in $(ovpn_profiles); do
        name="$(basename "$p" .ovpn)"
        entries+=("{\"kind\":\"ovpn\",\"name\":\"$(json_str "$name")\"}")
    done
    while read -r c; do
        [ -n "$c" ] && entries+=("{\"kind\":\"ike\",\"name\":\"$(json_str "$c")\"}")
    done < <(ike_conns)

    local joined; joined="$(IFS=,; echo "${entries[*]}")"
    printf '{"connected":%s,"active":%s,"profiles":[%s]}\n' \
        "$([ "$active" != "null" ] && echo true || echo false)" "$active" "$joined"
}

# ---------- status JSON ----------
print_status() {
    if ovpn_up; then
        local name ip
        name="$(basename "$(ovpn_profiles | head -n1)" .ovpn 2>/dev/null)"
        ip=$(ip -4 addr show "$TUN_IF" | awk '/inet /{print $2}')
        printf '{"text":"󰌾 VPN","class":"connected","tooltip":"OpenVPN: %s\\n%s"}\n' "${name:-on}" "$ip"
    elif ipsec_up; then
        printf '{"text":"󰌾 VPN","class":"connected","tooltip":"IKEv2: %s"}\n' "$(ipsec_active_conn)"
    else
        printf '{"text":"󰌿 VPN","class":"disconnected","tooltip":"VPN desconectada — clique para escolher"}\n'
    fi
}

case "$1" in
    list)          print_list ;;
    connect-ovpn)  connect_ovpn "$2"; refresh ;;
    connect-ike)   connect_ike "$2"; refresh ;;
    disconnect)    disconnect_all; refresh ;;
    *)             print_status ;;
esac
