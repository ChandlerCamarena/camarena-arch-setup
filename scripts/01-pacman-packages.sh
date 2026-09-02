#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root
require_arch
section() {
    echo ""
    echo "===== SECTION: $1 ====="
}
section_done() {
    echo "===== DONE: $1 ====="
    echo ""
}
# ---------------------------------------------------------------------------
section "PACMAN"
log "Enabling multilib repo..."
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    log "multilib enabled."
else
    log "multilib already enabled, skipping."
fi

# --- snapper bootstrap: minimal install, config, hook, baseline snapshot ---
# Runs before the base+profiles install below so the rest of the pacman
# section (and every later stage) is under snapshot protection.
log "Installing snapper (minimal, ahead of full package list)..."
sudo pacman -Sy --needed --noconfirm snapper

if command_exists snapper; then
    if sudo snapper -c root get-config &>/dev/null; then
        log "Snapper config 'root' already exists, skipping create-config."
    else
        log "Creating snapper config 'root' for /..."
        sudo snapper -c root create-config /
    fi
else
    err "snapper binary not found after minimal install. Skipping config, hook, and baseline snapshot. Remaining packages will install WITHOUT snapshot protection."
fi

if command_exists snapper && sudo snapper -c root get-config &>/dev/null; then
    HOOK_SRC="$SCRIPT_DIR/../config/pacman-hooks/00-snapshot.hook"
    HOOK_DEST="/etc/pacman.d/hooks/00-snapshot.hook"
    if [[ -f "$HOOK_SRC" ]]; then
        log "Installing snapper pre-transaction snapshot hook..."
        sudo mkdir -p "$(dirname "$HOOK_DEST")"
        sudo cp "$HOOK_SRC" "$HOOK_DEST"
    else
        err "Snapshot hook source not found at $HOOK_SRC, skipping."
    fi

    log "Creating baseline snapshot before full package install..."
    sudo snapper -c root create -d "pre-install baseline (camarena-arch-setup)"
else
    err "Skipping hook install and baseline snapshot: no valid snapper 'root' config."
fi
# --- end snapper bootstrap ---

BASE_PKGLIST="$SCRIPT_DIR/../packages/base.txt"
PROFILES_DIR="$SCRIPT_DIR/../packages/profiles"
if [[ ! -f "$BASE_PKGLIST" ]]; then
    err "Base package list not found at $BASE_PKGLIST"
    exit 1
fi
PACMAN_PKGLIST_TMP="$(mktemp)"
trap 'rm -f "$PACMAN_PKGLIST_TMP"' EXIT
cat "$BASE_PKGLIST" >> "$PACMAN_PKGLIST_TMP"
for profile in ${CAS_PROFILES:-}; do
    profile_file="$PROFILES_DIR/${profile}.txt"
    if [[ -f "$profile_file" ]]; then
        log "Adding pacman packages for profile: $profile"
        cat "$profile_file" >> "$PACMAN_PKGLIST_TMP"
    else
        err "No pacman package list for profile '$profile' at $profile_file, skipping"
    fi
done
log "Updating package databases..."
sudo pacman -Sy
mapfile -t pacman_packages < <(grep -vE '^\s*#|^\s*$' "$PACMAN_PKGLIST_TMP" | sort -u)
log "Installing ${#pacman_packages[@]} packages..."
sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"
section_done "PACMAN"
# ---------------------------------------------------------------------------
section "FLATPAK"
FLATPAK_PKGLIST="$SCRIPT_DIR/../packages/flatpak-packages.txt"
if ! command_exists flatpak; then
    err "flatpak binary not found after pacman section. Check that 'flatpak' is listed in base.txt."
    exit 1
fi
log "Ensuring Flathub remote is configured..."
if ! flatpak remote-list | grep -q '^flathub'; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
else
    log "Flathub remote already present."
fi
if [[ ! -f "$FLATPAK_PKGLIST" ]]; then
    err "Flatpak package list not found at $FLATPAK_PKGLIST"
    exit 1
fi
mapfile -t flatpak_apps < <(grep -vE '^\s*#|^\s*$' "$FLATPAK_PKGLIST")
for app in "${flatpak_apps[@]}"; do
    if flatpak list --app | awk '{print $2}' | grep -qx "$app"; then
        log "$app already installed, updating..."
        flatpak update --noninteractive "$app"
    else
        log "Installing $app..."
        flatpak install --noninteractive flathub "$app"
    fi
done
section_done "FLATPAK"
log "Package preparation stage complete."
