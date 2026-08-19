#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
require_arch

log "Checking for internet connectivity..."
if command_exists curl; then
    CHECK_CMD=(curl -fsS --max-time 5 https://archlinux.org)
elif command_exists ping; then
    CHECK_CMD=(ping -c 1 -W 5 archlinux.org)
else
    err "Neither curl nor ping available to check connectivity. Skipping check."
    CHECK_CMD=()
fi

if [[ ${#CHECK_CMD[@]} -gt 0 ]] && ! "${CHECK_CMD[@]}" &>/dev/null; then
    err "No internet connectivity detected. Cannot proceed."
    exit 1
fi

log "Checking for sudo access..."
if ! sudo -v; then
    err "This script requires sudo access for package installation and service setup."
    exit 1
fi

HOOK_SRC="$SCRIPT_DIR/../config/pacman-hooks/00-snapshot.hook"
HOOK_DEST="/etc/pacman.d/hooks/00-snapshot.hook"

if [[ -f "$HOOK_SRC" ]]; then
    log "Installing snapper pre-transaction snapshot hook..."
    sudo mkdir -p "$(dirname "$HOOK_DEST")"
    sudo cp "$HOOK_SRC" "$HOOK_DEST"
else
    err "Snapshot hook source not found at $HOOK_SRC, skipping. Every pacman transaction from here forward will run WITHOUT snapshot protection until this file exists."
fi

log "Preflight checks passed."
