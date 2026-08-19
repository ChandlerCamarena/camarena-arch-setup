#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

PKGLIST="$SCRIPT_DIR/../packages/flatpak-packages.txt"

if ! command_exists flatpak; then
    err "flatpak binary not found. It should have been installed by 01-pacman-packages.sh."
    exit 1
fi

log "Ensuring Flathub remote is configured..."
if ! flatpak remote-list | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
    log "Flathub remote already present."
fi

if [[ ! -f "$PKGLIST" ]]; then
    err "Flatpak package list not found at $PKGLIST"
    exit 1
fi

mapfile -t apps < <(grep -vE '^\s*#|^\s*$' "$PKGLIST")

for app in "${apps[@]}"; do
    if flatpak list --app | awk '{print $2}' | grep -qx "$app"; then
        log "$app already installed, updating..."
        flatpak update --noninteractive "$app"
    else
        log "Installing $app..."
        flatpak install --noninteractive flathub "$app"
    fi
done

log "Flatpak stage complete."
