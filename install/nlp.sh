#!/usr/bin/env bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

source "$SCRIPT_DIR/lib/helpers.sh"

NLP_DIR="$HOME/.local/share/nlp-workspace"

clear
log_header "NLP Tools Installation"
echo

TOTAL_STEPS=5
CURRENT_STEP=0

# --- Step 1: Install uv ---
CURRENT_STEP=$((CURRENT_STEP + 1))
log_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing uv (Python package manager)"

export PATH="$HOME/.local/bin:$PATH"

if command -v uv &>/dev/null; then
  log_info "uv already installed, skipping"
else
  log_info "Downloading uv installer..."
  if spinner "Downloading uv..." \
    curl -LsSf -o /tmp/uv-install.sh https://astral.sh/uv/install.sh; then
    log_info "Running uv installer..."
    sh /tmp/uv-install.sh
    rm -f /tmp/uv-install.sh
    log_success "uv installed"
  else
    log_error "Failed to download uv installer"
    rm -f /tmp/uv-install.sh
    exit 1
  fi
fi

# --- Step 2: Setup Python 3.12 and workspace ---
CURRENT_STEP=$((CURRENT_STEP + 1))
log_step "[$CURRENT_STEP/$TOTAL_STEPS] Setting up Python 3.12 workspace"

mkdir -p "$NLP_DIR"

cd "$NLP_DIR"

if [ ! -f "$NLP_DIR/pyproject.toml" ]; then
  log_info "Creating project with Python 3.12..."
  cat > "$NLP_DIR/pyproject.toml" << 'EOF'
[project]
name = "nlp-workspace"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = []
EOF
  log_success "Project created"
fi

log_info "Installing Python 3.12..."
uv python install 3.12 2>&1
log_success "Python 3.12 ready"

log_info "Creating virtual environment..."
uv venv --python 3.12 2>&1
log_success "Virtual environment created"

# --- Step 3: Install NLP packages ---
CURRENT_STEP=$((CURRENT_STEP + 1))
log_step "[$CURRENT_STEP/$TOTAL_STEPS] Installing NLP packages (PyTorch CUDA, FAISS, sentence-transformers)"

cd "$NLP_DIR"

log_info "Installing PyTorch with CUDA 12.4 support..."
uv add torch --extra-index-url https://download.pytorch.org/whl/cu124 2>&1
log_success "PyTorch CUDA installed"

log_info "Installing sentence-transformers, FAISS GPU, and supporting libraries..."
uv add \
  "sentence-transformers>=5.1.2,<=5.5.1" \
  "faiss-gpu-cu12>=1.13,<=1.14" \
  numpy scipy scikit-learn 2>&1
log_success "NLP packages installed"

# --- Step 4: Verify GPU ---
CURRENT_STEP=$((CURRENT_STEP + 1))
log_step "[$CURRENT_STEP/$TOTAL_STEPS] Verifying GPU availability"

cd "$NLP_DIR"

if uv run python -c "
import torch
print(f'  CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  Device count:   {torch.cuda.device_count()}')
    print(f'  Device name:    {torch.cuda.get_device_name(0)}')
" 2>&1; then
  log_success "GPU verified via PyTorch"
else
  log_warning "PyTorch GPU check failed"
fi

if uv run python -c "
import faiss
gpus = faiss.get_num_gpus()
print(f'  FAISS GPU support: {gpus} GPU(s) available')
" 2>&1; then
  log_success "FAISS GPU verified"
else
  log_warning "FAISS GPU check failed (may still work with CPU fallback)"
fi

# --- Step 5: Create nlp-run wrapper ---
CURRENT_STEP=$((CURRENT_STEP + 1))
log_step "[$CURRENT_STEP/$TOTAL_STEPS] Creating nlp-run wrapper"

WRAPPER="$HOME/.local/bin/nlp-run"

if [ ! -f "$WRAPPER" ]; then
  mkdir -p "$HOME/.local/bin"
  cat > "$WRAPPER" << 'WRAPEOF'
#!/usr/bin/env bash
set -e
NLP_DIR="$HOME/.local/share/nlp-workspace"
exec uv --directory "$NLP_DIR" run "$@"
WRAPEOF
  chmod +x "$WRAPPER"
  log_success "nlp-run created at ~/.local/bin/nlp-run"
else
  log_info "nlp-run already exists, skipping"
fi

# --- Done ---
echo
log_header "NLP installation complete!"
echo
log_info "Workspace: $NLP_DIR"
log_info ""
log_info "Usage from anywhere (e.g. ~/projects/meu-projeto):"
log_info "  nlp-run python script.py"
log_info "  nlp-run python -c \"from sentence_transformers import SentenceTransformer\""
log_info "  nlp-run pip install pacote-extra   # install more packages"
echo
