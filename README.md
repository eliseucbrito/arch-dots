# My Personal Dotfiles

Personal configuration files for Arch Linux, optimized for systems installed via the **Omarchy** script. This setup uses **Hyprland** as the compositor and a heavily customized **Quickshell** interface.

## Management with GNU Stow & PKGBUILD

These dotfiles are managed using [GNU Stow](https://www.gnu.org/software/stow/). Stow creates symbolic links from this repository to your home folder, allowing for a centralized and version-controlled configuration.

Additionally, all personal applications and dependencies are managed declaratively via a custom **PKGBUILD** metapackage (`meta-package/`), ensuring a clean and reproducible system.

### Stow Packages

| Package | Config Path | Description |
|---------|-------------|-------------|
| `hypr/` | `~/.config/hypr/` | Hyprland compositor (WM, keybindings, monitors, appearance) |
| `quickshell/` | `~/.config/quickshell/` | Quickshell widgets (bars, panels, lockscreen) |
| `nvim/` | `~/.config/nvim/` | Neovim editor (LazyVim-based) |
| `alacritty/` | `~/.config/alacritty/` | Alacritty terminal |
| `kitty/` | `~/.config/kitty/` | Kitty terminal |
| `ghostty/` | `~/.config/ghostty/` | Ghostty terminal |
| `fish/` | `~/.config/fish/` | Fish shell config |
| `tmux/` | `~/.config/tmux/` | Tmux terminal multiplexer |
| `waybar/` | `~/.config/waybar/` | Waybar status bar (config + styles + custom scripts) |
| `git/` | `~/.config/git/` | Git configuration |
| `starship/` | `~/.config/starship.toml` | Starship prompt |
| `btop/` | `~/.config/btop/` | btop system monitor |
| `lazygit/` | `~/.config/lazygit/` | Lazygit git TUI |
| `fastfetch/` | `~/.config/fastfetch/` | Fastfetch system info |
| `walker/` | `~/.config/walker/` | Walker app launcher |
| `swayosd/` | `~/.config/swayosd/` | SwayOSD on-screen display |
| `opencode/` | `~/.config/opencode/` | OpenCode AI coding assistant |
| `omarchy/` | `~/.config/omarchy/` | Omarchy system config (hooks, branding, backgrounds) |

## Installation

After a fresh Arch Linux / Omarchy installation, clone this repository:

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
```

### Method 1: Automatic setup

Run the setup script - it handles everything:

```bash
chmod +x setup.sh
./setup.sh
```

This will:
1. Install `stow`, `base-devel`, `git` via pacman
2. Install `yay` AUR helper if missing
3. Install all packages via the PKGBUILD metapackage
4. Set up NetworkManager dispatcher (if configured)
5. Set fish as the default shell
6. Apply all symlinks with stow
7. Install Fisher and fish plugins

### Method 2: Manual setup

```bash
# Install packages
cd meta-package
yay -S --needed --noconfirm .
cd ..

# Apply symlinks
make install
# or: stow -t ~ hypr quickshell nvim alacritty fish tmux waybar ...
```

## What's Included

### Productivity
- **Chromium** - Browser with flags config
- **LibreOffice** - Office suite
- **Obsidian** - Notes and knowledge base
- **Nautilus** - File manager
- **Fish shell** - Interactive shell with Fisher plugin manager
- **tmux** - Terminal multiplexer
- **zoxide** - Smarter cd command
- **tldr** - Simplified man pages
- **bat** - Cat with syntax highlighting
- **fd** - Find alternative
- **fzf** - Fuzzy finder
- **eza** - Modern ls replacement
- **ripgrep** - grep alternative
- **qbittorrent** - Torrent client

### Development
- **Neovim** - Editor with LazyVim config
- **Visual Studio Code** - GUI editor
- **Docker** + Docker Compose - Containers
- **Node.js** (LTS), npm, pnpm - JavaScript ecosystem
- **Deno** - Modern JavaScript runtime
- **Go** - Go programming language
- **Rust** - Rust compiler and cargo
- **Python** - Python interpreter
- **Git** with GitHub CLI + GitLab CLI
- **Lazygit** + **Lazydocker** - TUI tools
- **Starship** - Cross-shell prompt
- **jq** - JSON processor
- **zellij** - Terminal workspace
- **Antigravity** - AI tool
- **DBeaver** - Database manager

### Media
- **mpv** - Video player
- **OBS Studio** - Screen recording/streaming
- **yt-dlp** - Video downloader
- **ffmpeg** - Media converter
- **imv** - Image viewer
- **playerctl** - Media controller
- **pamixer** - Audio controller

### Gaming
- **Steam** - Game platform
- **Lutris** - Game manager
- **Wine** + Winetricks - Windows compatibility
- **Proton GE** - Custom Proton builds
- **GameMode** - Performance optimization

### System
- **btop** - System monitor
- **fastfetch** - System info
- **Hyprland** - Wayland compositor
- **Waybar** - Status bar
- **Walker** - App launcher
- **SwayOSD** - On-screen display
- **Mako** - Notifications
- **Alacritty/Kitty/Ghostty** - Terminals

## Theme System

This setup uses Omarchy's theme system. Themes are defined in `~/.local/share/omarchy/themes/` and user customizations go in `~/.config/omarchy/themes/`.

```bash
# List available themes
omarchy theme list

# Set a theme
omarchy theme set <name>

# Cycle wallpaper
omarchy theme bg next
```

Custom hooks run automatically on theme changes:
```bash
~/.config/omarchy/hooks/theme-set     # Runs after theme change
~/.config/omarchy/hooks/post-boot.d/  # Runs at boot
```

## VPN

A Waybar module (`custom/vpn`, at `waybar/.config/waybar/scripts/vpn.sh`) provides a
one-click VPN selector. It supports two technologies side by side and lets you pick
which one to bring up from a `walker` menu:

- **OpenVPN** — profiles dropped in `~/.vpn/*.ovpn`
- **IKEv2/IPsec** (strongSwan) — connections listed in `~/.vpn/ikev2.list`

The bar icon shows the tunnel state (green = connected, grey = off). A left-click opens
the menu to connect a profile or disconnect the active one. **The password is prompted
on every connect and is never written to disk** (it is injected into the strongSwan
daemon in memory, or passed to OpenVPN through a temp file that is shredded right after).

### Requirements

```bash
sudo pacman -S --needed strongswan   # IKEv2
sudo pacman -S --needed openvpn       # OpenVPN (optional)
```

### Setup — IKEv2 (strongSwan)

Config lives under `~/.vpn/` (outside this repo, so credentials never reach git):

1. Edit `~/.vpn/swanctl/conns.conf` — set `remote_addrs` (gateway), the crypto
   proposals, and `eap_id` (your login).
2. Make sure the connection name is listed in `~/.vpn/ikev2.list`.
3. Install the root-side config, trust anchor and the passwordless `sudoers` drop-in
   (needed so the bar can query status / toggle without a prompt every 10 s):

   ```bash
   sudo ~/.vpn/vpn-install-root.sh
   ```

### Split-DNS over the tunnel (optional)

If internal hosts only resolve through the VPN's DNS, drop a `~/.vpn/<connection>.dns`
file (same base name as the connection, kept outside git). On connect the module points
`systemd-resolved` at those servers and search domains; on disconnect it reverts:

```ini
servers=10.0.0.1 10.0.0.2
domains=corp.example.com
```

This is needed because strongSwan's `resolve` plugin writes to `/etc/resolv.conf`, which
is a symlink managed by `systemd-resolved` and therefore ignored. `resolvectl` runs
without a password via the `sudoers` drop-in.

### Setup — OpenVPN

Drop a `.ovpn` profile into `~/.vpn/`. It appears in the menu automatically.

### Troubleshooting

If the tunnel connects but nothing works — internal hosts unreachable, DNS silent, even the
internet acting up — see [**TROUBLESHOOTING.md**](TROUBLESHOOTING.md#vpn--tunnel-up-but-nothing-works).
It covers the two bugs that cause this (a Docker bridge shadowing the tunnel's `172.16/12`
subnets, and the missing policy-routing rule for strongSwan's table `220`) and their permanent
fixes. Quick triage:

```bash
ip route get 172.21.2.1    # an internal host IP behind the tunnel
# dev br-*/docker0  → Docker overlap        (bug #1)
# src 192.168.1.x   → tunnel routing rule   (bug #2)
# src 172.23.x.x    → routing OK; check DNS/firewall
```

## Sandbox (nono)

Coding agents run in autonomous mode, so they execute commands without asking. To keep that
safe, the Claude Code agents run inside [**nono**](https://herdr.dev/docs/quick-start/), a
capability-based sandbox that fences off what the agent can read, write, and reach over the
network. The `claude` fish function (`fish/.config/fish/functions/claude.fish`) starts a
sandboxed session when you pass `--sandbox`:

```bash
claude --sandbox        # picks the account, then launches under nono
claude                  # normal, unsandboxed session
```

The policy lives in the user profile `~/.config/nono/profiles/claude-multi.json` and enforces
three things.

### Network: allow-list, not open door

The base profile leaves the network wide open, which defeats the point — an agent that can
read a file can also POST it anywhere. This profile flips that to default-deny: only the hosts
the agent actually needs are reachable (Anthropic's API, the package registries, GitHub raw
content, and the two GitLab hosts). Everything else, `pastebin.com` included, is refused at the
proxy. Even if the agent reads a project `.env`, it has nowhere to send it.

```bash
nono why --profile claude-multi --host https://pastebin.com    # DENIED
nono why --profile claude-multi --host https://api.anthropic.com # ALLOWED
```

### Credentials: gh and glab work, the token stays hidden

The agent can open PRs and MRs with `gh` and `glab`, but it never sees the real tokens. nono
runs a credential proxy: the supervisor reads the token outside the sandbox (`gh` from the
system keyring, `glab` from its config), injects a phantom token into the agent's environment,
and swaps in the real one only on outbound requests to the allowed API endpoints. Inside the
sandbox, `gh auth token` returns the phantom, and the real `~/.config/glab-cli/config.yml` is
unreadable. Destructive calls (`DELETE`, repo deletion) fall outside the allowed endpoint list,
so the proxy never authenticates them.

glab points at a sanitized, token-free copy of its config via `GLAB_CONFIG_DIR`
(`~/.config/nono/glab-sandbox/`). If you add or re-auth a GitLab host, regenerate it:

```bash
# strip the tokens from the real config into the sandbox copy
python3 - <<'PY'
import yaml
d = yaml.safe_load(open("$HOME/.config/glab-cli/config.yml"))
for h, v in (d.get("hosts") or {}).items():
    if isinstance(v, dict): v.pop("token", None); v.pop("oauth_token", None)
yaml.safe_dump(d, open("$HOME/.config/nono/glab-sandbox/config.yml", "w"), sort_keys=False)
PY
chmod 600 ~/.config/nono/glab-sandbox/config.yml
```

### Filesystem: secrets are out of reach

The profile grants read+write on `~/projects` and the Claude state dirs, read-only on a handful
of tool configs, and nothing else. The `deny_credentials` group (inherited, non-removable)
blocks `~/.ssh`, `~/.aws`, `~/.config/gcloud`, and the rest of the usual credential paths.

> **Linux caveat:** the kernel's Landlock backend cannot deny a file *inside* a directory that
> is granted read+write. Since `~/projects` is granted wholesale, a `.env` sitting in a repo is
> readable by the agent. The network allow-list is what actually prevents that secret from
> leaving the machine, so the protection holds even though the file is legible. On macOS the
> same profile would deny the file outright.

### Browser debugging (chromium)

For debugging with the claude-in-chrome extension and the DevTools MCP, the profile permits
chromium: its config and cache dirs, the fonts, a Unix-socket bind for the singleton lock, and
the remote-debug port `9222` on localhost. Launch it inside the sandbox with the
`chromium-sandbox` wrapper, which sets `TMPDIR` and the flags Landlock requires:

```bash
chromium-sandbox --remote-debugging-port=9222
```

### Status in the herdr sidebar

The function uses `nono run` (not `nono wrap`): the supervisor has to stay alive for the
credential proxy, and `run` still attaches the current terminal and passes through the OSC
title sequences that [herdr](https://herdr.dev) reads to show each agent's state
(`working` / `idle` / `blocked` / `done`) in its sidebar. `--silent` suppresses nono's startup
banner so it doesn't clutter the pane or confuse the detection.

## Maintenance

### Updating dotfiles

```bash
cd ~/dotfiles
git pull
make update
```

### Adding a new config

```bash
mkdir -p ~/dotfiles/<package>/.config/<app>
# Move your config there
stow -t ~ <package>
```

### Managing applications

Edit `meta-package/PKGBUILD` and update the `depends` array, then:

```bash
cd ~/dotfiles/meta-package
yay -S --needed --noconfirm .
```

## References & Inspirations

- [snes19xx/surface-dots](https://github.com/snes19xx/surface-dots)
- [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration)
- [Whisker Shell](https://github.com/corecathx/whisker)
- [leandronsp/dotfiles](https://github.com/leandronsp/dotfiles)
