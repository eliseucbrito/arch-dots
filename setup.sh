#!/usr/bin/env bash
set -e

# ==========================================
# Variables Configuration
# ==========================================
DOTFILES_DIR="$HOME/dotfiles"
META_PKG_DIR="$DOTFILES_DIR/meta-package"
WHISKER_DIR="$DOTFILES_DIR/whisker"

# Paths for the NetworkManager dispatcher script
DISPATCHER_SRC="$DOTFILES_DIR/scripts/99-qbittorrent"
DISPATCHER_DEST="/etc/NetworkManager/dispatcher.d/99-qbittorrent"

# ==========================================
# Setup Execution
# ==========================================

echo "=> Installing dependencies (stow, base-devel, git)..."
sudo pacman -Sy --needed --noconfirm stow base-devel git

# --- Meta-package Setup ---
if [ -f "$META_PKG_DIR/PKGBUILD" ]; then
    echo "=> Installing personal base packages..."
    cd "$META_PKG_DIR"
    yay -S --needed --noconfirm "$META_PKG_DIR"
    cd "$DOTFILES_DIR"
else
    echo "=> WARNING: PKGBUILD not found in $META_PKG_DIR. Skipping makepkg installation."
fi

# --- Whisker Setup ---
if [ -f "$WHISKER_DIR/PKGBUILD" ]; then
    echo "=> Installing whisker-shell-git from local clone..."
    cd "$WHISKER_DIR"
    makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
else
    echo "=> WARNING: PKGBUILD not found in $WHISKER_DIR. Skipping makepkg installation."
    echo "=> If it's just the source code, you can run it via 'quickshell -p $WHISKER_DIR/shell.qml'."
fi

# --- NetworkManager Dispatcher Setup ---
if [ -f "$DISPATCHER_SRC" ]; then
    echo "=> Setting up NetworkManager dispatcher script..."
    sudo cp "$DISPATCHER_SRC" "$DISPATCHER_DEST"
    sudo chown root:root "$DISPATCHER_DEST"
    sudo chmod +x "$DISPATCHER_DEST"
    
    echo "=> Enabling NetworkManager-dispatcher service..."
    sudo systemctl enable --now NetworkManager-dispatcher.service
else
    echo "=> WARNING: Dispatcher script not found at $DISPATCHER_SRC. Skipping network rule setup."
fi

# --- fish and fisher setup ---
if [ "$SHELL" != "$(which fish)" ]; then
    echo "Setting fish as default shell..."
    chsh -s $(which fish)
fi

echo "Setting up Fisher and plugins..."
fish -c "
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
    end
    fisher update
"

# --- GNU Stow Symlinks ---
echo "=> Applying symlinks with GNU Stow..."
cd "$DOTFILES_DIR"
stow -t ~ hyprland
stow -t ~ quickshell
stow -t ~ nvim
stow -t ~ alacritty
stow -t ~ fish

echo "=> Setup finished successfully! Your configurations are linked."
