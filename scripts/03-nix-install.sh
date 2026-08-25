#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

if command_exists nix; then
    log "Nix already installed, checking for updates..."
    nix upgrade-nix || log "nix upgrade-nix failed or not applicable, continuing."
else
    log "Installing Nix via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

log "Nix stage complete. You may need to restart your shell for nix to be on PATH."
