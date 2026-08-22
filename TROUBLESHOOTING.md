# Troubleshooting

Notes on bugs that have actually bitten this setup, and their permanent fixes.

- [VPN — tunnel up but nothing works](#vpn--tunnel-up-but-nothing-works)
  - [Bug #1 — a Docker bridge shadows the tunnel's subnets](#bug-1--a-docker-bridge-shadows-the-tunnels-subnets)
  - [Bug #2 — the tunnel's routing rule is missing](#bug-2--the-tunnels-routing-rule-is-missing)
- [Wired CIn network — DNS resolves but connections time out](#wired-cin-network--dns-resolves-but-connections-time-out)

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

**Permanent fix — move all of Docker out of `172.16.0.0/12`** into the `10.x` space (your LAN
is `192.168.x`, the VPN is `172.x`, so `10.x` is free), so *new* networks never land there
again. In `/etc/docker/daemon.json`:

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
`10.100.x`.

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
resolves correctly and fast via the DHCP-provided CIn resolvers (`eno1` link), routing looks
normal (`ip route get <ip>` goes straight out `eno1` to the gateway), but `curl`/`ping` to that
IP just time out. No `172.16.0.0/12` route shadowing was present — the Docker bridges were
already on `10.x`/`192.168.x` (see [Bug #1](#bug-1--a-docker-bridge-shadows-the-tunnels-subnets)),
so this isn't the same route-shadowing mechanism, but the symptom (reachability broken with
correct DNS) and the fix are the same family.

**Fix:**

```bash
sudo systemctl restart docker && sudo systemctl restart systemd-resolved
```

Likely a stuck `systemd-resolved` state/cache rather than Docker itself, but restarting both
together is the known-working sequence — hasn't been isolated further yet.
