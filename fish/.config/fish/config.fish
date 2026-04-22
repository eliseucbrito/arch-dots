# =============================================================================
# Environment Variables and Exports
# =============================================================================

# Disable the default Fish greeting message
set -U fish_greeting ""

# Set Neovim as the default editor (crucial for git and system commands)
set -gx EDITOR nvim
set -gx VISUAL nvim

# Add local directories to PATH (personal scripts, npm/yarn binaries, cargo)
fish_add_path ~/.local/bin
fish_add_path ~/.npm-global/bin
fish_add_path ~/.cargo/bin

# =============================================================================
# Essential System Aliases
# =============================================================================

# Navigation and listing (Requires 'eza' and 'bat' installed)
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias tree="eza --tree --icons"
alias cat="bat --style=plain --paging=never"

# Safety flags for destructive commands
alias rm="rm -I"
alias cp="cp -i"
alias mv="mv -i"

# =============================================================================
# Development Workflow Aliases
# =============================================================================

# Git (While plugins like forgit cover a lot, these manual shortcuts are handy)
alias gs="git status"
alias gc="git commit -m"
alias gp="git push"
alias gpl="git pull"

# Docker & Containers
alias d="docker"
alias dco="docker compose"
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dlogs="docker compose logs -f"
alias dclean="docker system prune -af --volumes" # Clean everything not in use

# Backend (Node, NestJS, TypeScript, Databases)
alias nr="npm run"
alias ndev="npm run start:dev" # Standard for NestJS projects
alias nbuild="npm run build"
alias psql-dev="psql -U postgres -h localhost" # Fast access to local PostgreSQL
alias db-migrate="npm run db:push" # Practical shortcut for Drizzle ORM

# =============================================================================
# System Maintenance and Dotfiles Aliases
# =============================================================================

# Pacman and AUR (Arch Linux shortcuts)
alias update="paru -Syu" # or yay -Syu
alias cleanup="paru -Sc && paru -c" # Clears pacman cache and orphan packages

# GNU Stow and Dotfiles
alias dot="cd ~/dotfiles"
alias dot-sync="cd ~/dotfiles && ./setup.sh" # Runs your bootstrap script quickly
alias sys-edit="nvim ~/dotfiles/meta-package/PKGBUILD" # Quick access to metapackage

# =============================================================================
# Tool Initialization and Plugins
# =============================================================================

# Fish fzf integration (Keybindings)
# If using the fzf.fish plugin, these variables enhance the preview visual
set -gx fzf_preview_dir_cmd eza --all --color=always
set -gx fzf_fd_opts --hidden --exclude=.git

if status is-interactive
    eval (zellij setup --generate-auto-start fish | string collect)
end
