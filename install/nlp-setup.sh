#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
DOTFILES_DIR=$(dirname "$SCRIPT_DIR")

source "$SCRIPT_DIR/lib/helpers.sh"

clear
log_header "NLP Environment Setup"
echo
log_info "Python 3.12 | FAISS | sentence-transformers | PyTorch | transformers"
echo

# ── Step 1: Check NVIDIA GPU ──
log_step "[1/5] Checking NVIDIA GPU"
if lspci | grep -i 'vga.*nvidia\|3d.*nvidia' &>/dev/null; then
  log_success "NVIDIA GPU detected"
  USE_GPU=true
else
  log_warning "No NVIDIA GPU detected"
  if ask_yes_no "Continue with faiss-cpu (no GPU acceleration)?"; then
    USE_GPU=false
  else
    log_info "Aborting"
    exit 0
  fi
fi

# ── Step 2: CUDA toolkit ──
log_step "[2/5] Installing CUDA toolkit"
if [ "$USE_GPU" = "true" ]; then
  if ! command -v nvidia-smi &>/dev/null 2>&1; then
    log_info "Installing NVIDIA driver..."
    sudo pacman -S --needed --noconfirm nvidia nvidia-utils
  fi
  if ! is_installed cuda; then
    log_info "Installing CUDA..."
    sudo pacman -S --needed --noconfirm cuda
  fi
  log_success "CUDA ready"
else
  log_detail "Skipping CUDA (CPU-only mode)"
fi

# ── Step 3: Install uv ──
log_step "[3/5] Installing uv"
if ! command -v uv &>/dev/null; then
  sudo pacman -S --needed --noconfirm uv
fi
log_success "uv $(uv --version 2>/dev/null | awk '{print $2}')"

# ── Step 4: Python 3.12 + virtualenv ──
log_step "[4/5] Setting up Python 3.12"
VENV_DIR="$HOME/nlp-lab/.venv"

uv python install 3.12 2>/dev/null || true
if [ ! -f "$VENV_DIR/bin/python" ]; then
  uv venv --python 3.12 "$VENV_DIR"
fi

PY_VER=$("$VENV_DIR/bin/python" --version)
log_success "venv ready: $PY_VER @ $VENV_DIR"

# ── Step 5: Install packages ──
log_step "[5/5] Installing NLP packages"

source "$VENV_DIR/bin/activate"

if [ "$USE_GPU" = "true" ]; then
  log_info "Installing PyTorch (CUDA 12.6)..."
  uv pip install torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu126
  FAISS_PKG="faiss-gpu>=1.13,<=1.14"
else
  log_info "Installing PyTorch (CPU)..."
  uv pip install torch torchvision torchaudio
  FAISS_PKG="faiss-cpu>=1.13,<=1.14"
fi

log_info "Installing NLP libraries..."
uv pip install \
  "sentence-transformers>=5.1.2,<=5.5.1" \
  "$FAISS_PKG" \
  transformers datasets peft accelerate bitsandbytes evaluate \
  scikit-learn psycopg2-binary wandb

deactivate 2>/dev/null || true

# ── Verify ──
log_info "Verifying installation..."

VERIFY_PY=$("$VENV_DIR/bin/python" -c "
import sys
print(f'Python {sys.version.split()[0]}')
import torch
print(f'PyTorch {torch.__version__}')
if torch.cuda.is_available():
    print(f'CUDA {torch.version.cuda} | GPU {torch.cuda.get_device_name(0)}')
else:
    print('CUDA: not available (CPU mode)')
import faiss
print(f'FAISS {faiss.__version__}')
import sentence_transformers
print(f'sentence-transformers {sentence_transformers.__version__}')
" 2>&1)

echo "$VERIFY_PY" | while IFS= read -r line; do
  [ -n "$line" ] && log_success "$line"
done

# ── Done ──
echo
log_header "NLP setup complete!"
echo
log_info "Usage:"
log_info "  nlp-on     Activate the environment"
log_info "  nlp-off    Deactivate"
echo
