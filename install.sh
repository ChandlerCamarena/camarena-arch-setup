#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

log "Starting environment setup from $SCRIPT_DIR"

for stage in "$SCRIPT_DIR"/scripts/0*.sh; do
    log "Running $(basename "$stage")..."
    bash "$stage"
done

log "All stages complete. Reboot or restart Hyprland to apply changes."

if [[ -f "$SCRIPT_DIR/install.sh" && -d "$SCRIPT_DIR/scripts" && -d "$SCRIPT_DIR/config" ]]; then
    cd "$HOME"
    log "Removing repo directory $SCRIPT_DIR"
    rm -rf "$SCRIPT_DIR"
    log "Done."
else
    log "WARNING: safety check failed, not deleting $SCRIPT_DIR. Remove it manually if desired."
fi
