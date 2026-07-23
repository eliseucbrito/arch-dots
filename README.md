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
