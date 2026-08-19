#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root
require_arch

PKGLIST="$SCRIPT_DIR/../packages/vulkan-datum-packages.txt"

if [[ ! -f "$PKGLIST" ]]; then
    err "Vulkan/Datum package list not found at $PKGLIST"
    exit 1
fi

log "Installing Vulkan/Datum toolchain packages from $PKGLIST..."
mapfile -t packages < <(grep -vE '^\s*#|^\s*$' "$PKGLIST")

sudo pacman -S --needed --noconfirm "${packages[@]}"

log "Vulkan/Datum stage complete."
