# =============================================================================
# Environment Variables and Exports
# =============================================================================

# Disable the default Fish greeting message
set -U fish_greeting ""

# Set Neovim as the default editor (crucial for git and system commands)
set -gx EDITOR nvim
set -gx VISUAL nvim

# Add local directories to PATH (personal scripts, npm/yarn binaries, cargo)
fish_add_path ~/.dotfiles/bin
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
alias update="yay -Syu"
alias cleanup="yay -Sc && yay -Yc" # Clears pacman cache and orphan packages

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

# if status is-interactive eval (zellij setup --generate-auto-start fish | string collect)
# end
# status is-interactive; and begin
#     set fish_tmux_autostart true
# end

# Added by LM Studio CLI tool (lms)
set -gx PATH $PATH $HOME/.lmstudio/bin

# Tmux 

function work_session
    set session work

    if not tmux has-session -t $session 2>/dev/null

        ## sshm
        tmux new-session -d -s $session -n sshm
        tmux kill-session -t 0 2>/dev/null sleep 0.2

        tmux split-window -h -t "$session:sshm.1"
        tmux send-keys -t "$session:sshm.1" sshm C-m
        tmux send-keys -t "$session:sshm.2" opencode C-m

        ## dotfiles
        tmux new-window -t $session -n dotfiles

        tmux split-window -h -t "$session:dotfiles.1"
        tmux send-keys -t "$session:dotfiles.1" 'cd ~/dotfiles && nvim .' C-m
        tmux send-keys -t "$session:dotfiles.2" 'cd ~/dotfiles && lazygit' C-m

        ## opencode
        tmux new-window -t $session -n opencode
        tmux send-keys -t "$session:opencode.1" 'cd ~/projects && opencode' C-m

        tmux select-window -t "$session:sshm"
    end

    exec tmux attach-session -t $session
end

# if status is-interactive
#     and not set -q TMUX
#     work_session
# end

# string match -q "$TERM_PROGRAM" kiro and . (kiro --locate-shell-integration-path fish)

# opencode
fish_add_path /home/ecb/.opencode/bin

# =============================================================================
# NLP Environment (optional -- activate with: nlp-on)
# =============================================================================

function nlp-on
    if test -n "$NLP_ACTIVE"
        echo "NLP environment already active"
        return 0
    end
    if test -f ~/nlp-lab/.venv/bin/activate.fish
        source ~/nlp-lab/.venv/bin/activate.fish
        set -gx NLP_ACTIVE 1
        echo "NLP environment activated (Python 3.12, FAISS-GPU, PyTorch)"
        echo "Run 'nlp-off' to deactivate"
    else
        echo "NLP environment not found."
        echo "Run: ~/dotfiles/install/nlp-setup.sh"
    end
end

function nlp-off
    if test -z "$NLP_ACTIVE"
        echo "NLP environment not active"
        return 0
    end
    deactivate 2>/dev/null
    set -e NLP_ACTIVE
    echo "NLP environment deactivated"
end

# Starship prompt
starship init fish | source
