#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

if command_exists determinate-nixd; then
    # Determinate Nix upgrades through its daemon (nix upgrade-nix is for
    # upstream Nix). `version` says when a newer release is out; captured
    # before grepping, see 04-fonts.sh on grep -q under pipefail.
    log "Nix already installed, checking for a newer Determinate Nix..."
    nix_version="$(determinate-nixd version 2>&1 || true)"
    if grep -q "new version of Determinate Nix is available" <<<"$nix_version"; then
        log "Upgrading Determinate Nix..."
        sudo determinate-nixd upgrade
    else
        log "Determinate Nix is up to date."
    fi
elif command_exists nix; then
    err "nix is installed but not Determinate Nix; leaving it alone (this stage only manages Determinate's installer)."
else
    log "Installing Nix via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi

log "Nix stage complete. You may need to restart your shell for nix to be on PATH."
