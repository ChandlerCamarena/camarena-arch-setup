#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

FONT_SRC_DIR="$SCRIPT_DIR/../fonts"
FONT_DEST_DIR="$HOME/.local/share/fonts"

mkdir -p "$FONT_DEST_DIR"

log "Installing Departure Mono..."
cp "$FONT_SRC_DIR/DepartureMono-Regular.otf" "$FONT_DEST_DIR/DepartureMono-Regular.otf"
cp "$FONT_SRC_DIR/OFL.txt" "$FONT_DEST_DIR/DepartureMono-OFL.txt"

log "Rebuilding font cache..."
fc-cache -f "$FONT_DEST_DIR"

if fc-list | grep -qi "Departure Mono"; then
    log "Departure Mono registered successfully."
else
    err "Departure Mono not found by fontconfig after cache rebuild. Check the file and rerun fc-cache manually."
fi
