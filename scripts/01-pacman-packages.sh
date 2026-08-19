#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
require_arch

PKGLIST="$SCRIPT_DIR/../packages/pacman-packages.txt"

if [[ ! -f "$PKGLIST" ]]; then
    err "Package list not found at $PKGLIST"
    exit 1
fi

log "Reading package list from $PKGLIST..."
mapfile -t packages < <(grep -vE '^\s*#|^\s*$' "$PKGLIST")

log "Syncing databases, upgrading system, and installing packages in one transaction..."
sudo pacman -Syu --needed --noconfirm "${packages[@]}"

log "Package install stage complete."
