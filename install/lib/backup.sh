#!/usr/bin/env bash

BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
RESTORE_FILE="$BACKUP_DIR/restore.sh"

init_backup_session() {
  mkdir -p "$BACKUP_DIR"
  echo "#!/usr/bin/env bash" > "$RESTORE_FILE"
  echo "set -e" >> "$RESTORE_FILE"
  echo "# Restore configs from: $BACKUP_DIR" >> "$RESTORE_FILE"
  chmod +x "$RESTORE_FILE"
  echo "$BACKUP_DIR"
}

backup_config() {
  local path="$1"
  local dest="$BACKUP_DIR/$path"
  local dir
  dir=$(dirname "$dest")
  mkdir -p "$dir"
  if [ -e "$HOME/$path" ] || [ -L "$HOME/$path" ]; then
    cp -a "$HOME/$path" "$dest"
    echo "ln -sf $(readlink "$HOME/$path") \"$HOME/$path\"" >> "$RESTORE_FILE"
    log_detail "  backed up: $path"
  fi
}
