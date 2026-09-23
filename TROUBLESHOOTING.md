# Troubleshooting

Notes on bugs that have actually bitten this setup, and their permanent fixes.

- [VPN — tunnel up but nothing works](#vpn--tunnel-up-but-nothing-works)
  - [Bug #1 — a Docker bridge shadows the tunnel's subnets](#bug-1--a-docker-bridge-shadows-the-tunnels-subnets)
  - [Bug #2 — the tunnel's routing rule is missing](#bug-2--the-tunnels-routing-rule-is-missing)
- [Wired CIn network — DNS resolves but connections time out](#wired-cin-network--dns-resolves-but-connections-time-out)
- [Minikube — pods stuck ImagePullBackOff, DNS SERVFAIL inside the node](#minikube--pods-stuck-imagepullbackoff-dns-servfail-inside-the-node)

---

## VPN — tunnel up but nothing works

Symptoms: the tunnel connects (`sudo swanctl --list-sas` shows `ESTABLISHED` / `INSTALLED`)
but you can't reach internal hosts, DNS goes silent, and sometimes even the internet behaves
oddly. Two *independent* bugs cause this, and they can stack. Diagnose with a single command —
the **source address** it prints tells you which one you're hitting:

```bash
ip route get 172.21.2.151          # some internal CIn IP
```

- `... dev br-*` / `dev docker0` → **bug #1** (Docker).
- `... src 192.168.1.x` (your LAN IP, not the VPN IP) → **bug #2** (routing rule).
- `... src 172.23.x.x` (the VPN-assigned IP) → routing is fine; look at DNS/firewall.

### Bug #1 — a Docker bridge shadows the tunnel's subnets

Docker auto-allocates networks from `172.16.0.0/12` — precisely the range the CIn (and many
institutions) use internally. Each bridge installs a `scope link` `/16` route, and because a
`/16` is more specific than the VPN's `0.0.0.0/0`, it shadows the tunnel: traffic to those
hosts is handed to the bridge and dropped. This holds **even for bridges with no running
containers** — a `linkdown` `br-*` keeps its route in the main table, and the kernel still
uses it unless `net.ipv4.conf.all.ignore_routes_with_linkdown=1`.

This bites the **wired CIn network too** (no VPN): `manager1.cin.ufpe.br` and the servers are
`172.21.x`, and a `nextjs15-demo_default`-style bridge on `172.21.0.0/16` swallows them the
moment `docker compose up` brings it up. It also collides with the **VPN's own virtual-IP
range**: strongSwan hands out `172.23.x`, and a bridge on `172.23.0.0/16` (e.g. a
`keycloak-net`) shadows the tunnel's source subnet.

**Permanent fix — move all of Docker out of `172.16.0.0/12`** into the `10.x` space (your LAN
is `192.168.x`, the VPN is `172.x`, so `10.x` is free), so *new* networks never land there
again. This repo ships it: **`sudo make system`** installs `system/etc/docker/daemon.json`,
the resolved drop-in, the `ignore_routes_with_linkdown` sysctl, and `docker-net-guard`, then
recreates existing bridges on the new pool. Contents of `/etc/docker/daemon.json`:

```json
{
    "bip": "10.99.0.1/16",
    "dns": ["10.99.0.1"],
    "default-address-pools": [
        { "base": "10.100.0.0/16", "size": 24 },
        { "base": "10.101.0.0/16", "size": 24 }
    ]
}
```

`dns` points containers at the `docker0` gateway, where `systemd-resolved` serves them the
host's (split-)DNS — so moving `docker0` means moving that stub listener too, otherwise
containers lose DNS. In `/etc/systemd/resolved.conf.d/20-docker-dns.conf`:

```ini
[Resolve]
DNSStubListenerExtra=10.99.0.1
```

`default-address-pools` only affects **new** networks, so drop any bridge already sitting on
`172.x` (detach its stopped containers first — this does *not* delete them; `docker compose up`
recreates the network on the new pool and named volumes survive):

```bash
for c in $(docker network inspect -f '{{range $k,$v := .Containers}}{{$k}} {{end}}' <name>); do
    docker network disconnect -f <name> "$c"
done
docker network rm <name>
```

Then apply: `sudo systemctl restart docker && sudo systemctl restart systemd-resolved`. Verify
with `ip route | grep 172` (empty) and by creating a throwaway network — it should land in
`10.100.x`. `sudo make system` does all of this; afterward `docker-net-guard` fails CI/your
shell if any network creeps back into `172.16/12`.

### Bug #2 — the tunnel's routing rule is missing

This is a full-tunnel, **policy-based** IPsec setup: strongSwan assigns a virtual IP
(`172.23.x.x`) and installs the tunnel's default route into a *separate* routing table
(`charon.routing_table`, `220` by default) rather than the main table. For that table to be
consulted, a policy-routing rule (`from all lookup 220`) must exist — it's what makes outbound
packets take the VPN source address, which is what the IPsec out-policy matches on. In this
setup **that rule is not created automatically**, so:

- packets keep their LAN source (`192.168.1.x`), never match the out-policy, and never enter
  the tunnel — internal hosts are unreachable and the SA shows `in 0 bytes`
  (`sudo swanctl --list-sas`);
- because split-DNS then points every query at the CIn resolvers (`172.21.2.x`), which are
  themselves only reachable *through* the tunnel, **no name resolves at all** — not even
  public ones.

Confirm the rule is absent (`ip rule show` has no `lookup 220` line) and that forcing the VPN
source still escapes the tunnel:

```bash
ip route get 8.8.8.8 from 172.23.44.232   # prints 'via 192.168.1.1' == still off-tunnel
```

**Fix — this is now handled automatically by `vpn.sh`:** `apply_route_rule` installs the rule
on connect and `revert_route_rule` removes it on disconnect (mirroring the DNS handling). It
needs passwordless `ip`, so the sudoers drop-in written by `vpn-install-root.sh` includes
`/usr/bin/ip`; re-run `sudo ~/.vpn/vpn-install-root.sh` after updating. To apply it by hand on
a live tunnel:

```bash
sudo ip rule add from all lookup 220 priority 220   # undo: ip rule del ... priority 220
```

After it's in place, `ip route get 8.8.8.8` should report `src 172.23.x.x`, the SA's `in`
counter starts climbing, and DNS/internal hosts come alive. (In full-tunnel mode the local LAN
— printer, router UI — becomes unreachable while connected; that's expected.)

## Wired CIn network — DNS resolves but connections time out

Symptoms: on the CIn wired network (no VPN needed there), `resolvectl query <host>.cin.ufpe.br`
resolves correctly and fast via the DHCP-provided CIn resolvers (`eno1` link), but `curl`/`ping`
to that IP just times out. Also seen **with the VPN connected**: `manager1.cin.ufpe.br:7443`
and `ssh` to the servers hang.

This is [Bug #1](#bug-1--a-docker-bridge-shadows-the-tunnels-subnets). It recurred because the
permanent fix had never actually been written to `/etc/docker/daemon.json` — the file still had
`"bip": "172.17.0.1/16"` and no `default-address-pools`, so Docker kept handing new project
networks `172.18`–`172.23`. `nextjs15-demo_default` landed on `172.21.0.0/16` (shadowing
`manager1` and the resolvers) and `nextjs15-demo_keycloak-net` on `172.23.0.0/16` (the VPN's
own virtual-IP block). Deleting the route by hand works until the next `docker` restart or
reboot.

**Diagnose:**

```bash
ip route show | grep -E '172\.(1[6-9]|2[0-9]|3[01])\.'   # any hit = a bridge shadowing CIn
docker network ls --format '{{.Name}}' | while read n; do \
  printf '%s ' "$n"; docker network inspect "$n" -f '{{range .IPAM.Config}}{{.Subnet}} {{end}}'; echo; done
```

**Temporary unblock** (gone after `docker` restart / reboot):

```bash
sudo ip route del 172.21.0.0/16 dev br-XXXX   # the dev name from the grep above
```

**Permanent fix — `sudo make system`** (from this repo). It installs
`system/etc/docker/daemon.json` (Docker → `10.99`/`10.100`/`10.101`), the resolved drop-in,
the `ignore_routes_with_linkdown=1` sysctl, and `/usr/local/bin/docker-net-guard`, then
recreates existing bridges on the new pool. Re-run after `git pull` if `system/` changed. The
old blunt workaround (`sudo systemctl restart docker && sudo systemctl restart systemd-resolved`)
only helps when it's a stale `systemd-resolved` cache, not the route shadowing — check the
`ip route` grep first.

## Minikube — pods stuck ImagePullBackOff, DNS SERVFAIL inside the node

Symptoms: `minikube start` prints `Failing to connect to https://registry.k8s.io/`, and every
pod that needs an image (even unrelated ones — `busybox`, `postgres`, app images) sits in
`ErrImagePull`/`ImagePullBackOff`. `kubectl describe pod` shows the real cause in Events:

```
Failed to pull image "...": Error response from daemon: Get "https://registry-1.docker.io/v2/":
dial tcp: lookup registry-1.docker.io on <bridge-gateway-ip>:53: server misbehaving
```

Root cause: same family as [Bug #1](#bug-1--a-docker-bridge-shadows-the-tunnels-subnets)'s DNS
half, but the *other* direction. `minikube start -p <profile>` (the `docker` driver) creates its
**own** Docker bridge (e.g. `br-02bb1af570dd`) with its own gateway IP — not necessarily
`docker0`/`172.17.0.1`, and not the `bip` configured in `daemon.json` either. That gateway isn't
in `DNSStubListenerExtra` (`/etc/systemd/resolved.conf.d/20-docker-dns.conf`), so
`systemd-resolved`'s stub never answers queries from inside the minikube node — they `SERVFAIL`,
and every image pull fails regardless of registry.

Confirm the mismatch:

```bash
docker network inspect <profile> --format '{{(index .IPAM.Config 0).Gateway}}'   # e.g. 192.168.58.1
cat /etc/systemd/resolved.conf.d/20-docker-dns.conf                              # stub IP(s) configured
```

If the gateway isn't listed, that's it.

**Fix — add the minikube bridge's gateway as an extra stub listener** (the directive accepts
multiple lines, one IP each):

```ini
[Resolve]
DNSStubListenerExtra=172.17.0.1
DNSStubListenerExtra=192.168.58.1
```

The `[Resolve]` header is mandatory and easy to lose if you overwrite the file with a bare
`echo`/`tee` (e.g. piping just the `DNSStubListenerExtra=...` lines) — without it,
`systemd-resolved` silently ignores every line in the drop-in (`journalctl -u systemd-resolved`
shows `Assignment outside of section. Ignoring.` for each one) and the stub never binds, so the
symptom looks unchanged after "fixing" it. Always write the whole file, header included.

```bash
sudo systemctl restart systemd-resolved && sudo systemctl restart docker
docker exec <profile> getent hosts registry-1.docker.io   # should resolve now
```

Note: `restart docker` kills every running container, minikube included — `minikube start
-p <profile>` again afterward.

Note: this gateway IP is **not stable** — `minikube delete && minikube start` (or Docker
reallocating bridges) can hand the profile a different subnet next time, reproducing the same
`SERVFAIL` with a new IP. There's no permanent fix short of pinning the minikube network's
subnet explicitly; when it recurs, re-diagnose with the two commands above and add the new IP.
