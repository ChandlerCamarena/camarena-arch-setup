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

log "Preflight checks passed."
