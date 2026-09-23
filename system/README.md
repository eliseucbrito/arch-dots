# system/ — root-owned config

The dotfiles `make install` only touches `$HOME`. This directory holds the
handful of files that live under `/etc` and need `sudo`. They are **not**
symlinked (Docker and systemd don't follow symlinks reliably here) — they are
**copied** by `install.sh`, which backs up whatever it overwrites.

```
sudo make system      # from the repo root
# or
sudo ./system/install.sh
```

Idempotent. Re-run after `git pull` if anything here changed.

## What it fixes

Docker auto-allocates networks from `172.16.0.0/12` — the same range CIn uses
internally and the same range the strongSwan VPN draws its virtual IP from.
Every bridge installs a `scope link` `/16` route; a `/16` beats the VPN's
`0.0.0.0/0` and the wired default, so traffic to `*.cin.ufpe.br`
(`manager1`, the resolvers at `172.21.2.x`, the servers) is handed to a local
Docker bridge and dropped. DNS still resolves, connections time out. A
`linkdown` bridge with no containers still does this.

Deleting the route by hand (`ip route del 172.21.0.0/16 dev br-*`) works until
the next `docker` restart or reboot, then the bridge and its route come back.

`daemon.json` here moves Docker to `10.99.x` / `10.100.x` / `10.101.x`
(`bip`, `dns`, `default-address-pools`) so **new** networks never land in
`172.16/12`. `default-address-pools` does not touch existing networks, so
`install.sh` also removes every user-defined network once — `docker compose up`
recreates them on the new pool (named volumes survive).

- `etc/systemd/resolved.conf.d/20-docker-dns.conf` — follows `docker0`'s stub
  listener to `10.99.0.1` so containers keep DNS.
- `etc/sysctl.d/99-docker-linkdown.conf` — `ignore_routes_with_linkdown=1` so a
  stopped bridge can't shadow anything.
- `bin/docker-net-guard` → `/usr/local/bin/docker-net-guard` — exits non-zero if
  any Docker network is back in `172.16/12`. Run it after adding a project, or
  from CI.

See `../TROUBLESHOOTING.md` → "Wired CIn network" and "VPN — Bug #1".
