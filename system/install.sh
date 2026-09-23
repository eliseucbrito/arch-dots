#!/usr/bin/env bash
# Installs the root-owned system config that keeps Docker out of 172.16.0.0/12.
# Run with sudo:  sudo ./system/install.sh
#
# Idempotent. Backs up anything it overwrites. Recreates user-defined Docker
# networks so existing 172.x bridges move onto the 10.100.x pool.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0" >&2
    exit 1
fi

SRC="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

install_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.bak-$STAMP"
        echo "  backed up $dst -> $dst.bak-$STAMP"
    fi
    install -m 0644 "$src" "$dst"
    echo "  installed $dst"
}

echo "==> Installing system config"
install_file "$SRC/etc/docker/daemon.json"                        /etc/docker/daemon.json
install_file "$SRC/etc/systemd/resolved.conf.d/20-docker-dns.conf" /etc/systemd/resolved.conf.d/20-docker-dns.conf
install_file "$SRC/etc/sysctl.d/99-docker-linkdown.conf"          /etc/sysctl.d/99-docker-linkdown.conf
install -m 0755 "$SRC/bin/docker-net-guard"                       /usr/local/bin/docker-net-guard
echo "  installed /usr/local/bin/docker-net-guard"

echo "==> Cleaning stray resolved drop-ins"
rm -fv /etc/systemd/resolved.conf.d/20-docker-dns.confsudo \
       /etc/systemd/resolved.conf.d/20-docker-dns.conf.pacnew \
       /etc/systemd/resolved.conf.d/20-docker-dns.conf.bak-20260714-154243 \
       /etc/systemd/resolved.conf.d/10-disable-multicast.conf.pacnew 2>/dev/null || true

echo "==> Applying sysctl"
sysctl --system >/dev/null

echo "==> Recreating Docker networks on the new pool"
systemctl stop docker docker.socket
# daemon must be up to talk to it; start it, remove user nets, they get
# recreated by compose/run later on 10.100.x
systemctl start docker
sleep 2
for net in $(docker network ls --format '{{.Name}}'); do
    case "$net" in bridge|host|none) continue ;; esac
    if docker network rm "$net" >/dev/null 2>&1; then
        echo "  removed $net"
    else
        echo "  skip $net (in use — 'docker compose -p <p> down' then rerun)"
    fi
done
systemctl restart docker

echo "==> Restarting systemd-resolved"
systemctl restart systemd-resolved

echo
echo "==> Verify"
echo "-- routes in 172.16/12 (want: none):"
ip route show | grep -E '172\.(1[6-9]|2[0-9]|3[01])\.' || echo "   none — good"
echo "-- pool probe:"
docker network create _pool_probe >/dev/null
docker network inspect _pool_probe --format '   {{range .IPAM.Config}}{{.Subnet}}{{end}}'
docker network rm _pool_probe >/dev/null
echo "-- guard:"
/usr/local/bin/docker-net-guard || true
