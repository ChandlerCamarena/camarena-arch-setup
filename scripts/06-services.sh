#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root

log "Deploying SDDM theme..."
SDDM_THEME_SRC="$SCRIPT_DIR/../config/sddm/retrowave"
SDDM_THEME_DEST="/usr/share/sddm/themes/retrowave"

if [[ ! -d "$SDDM_THEME_SRC" ]]; then
    err "SDDM theme source not found at $SDDM_THEME_SRC"
    exit 1
fi

sudo mkdir -p "$SDDM_THEME_DEST"
sudo cp -r "$SDDM_THEME_SRC"/* "$SDDM_THEME_DEST/"
sudo cp "$SCRIPT_DIR/../config/hypr/theme.json" "$SDDM_THEME_DEST/theme.json"
sudo cp "$SCRIPT_DIR/../config/hypr/wallpapers/wallpaper.png" "$SDDM_THEME_DEST/wallpaper.png"

sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=retrowave\n' | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
log "SDDM theme deployed and set as current."

SERVICES=(
    sddm
    NetworkManager
    bluetooth
)
for svc in "${SERVICES[@]}"; do
    if systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        log "$svc already enabled."
    else
        log "Enabling $svc..."
        sudo systemctl enable "$svc"
    fi
done
log "Service stage complete. Services will start on next boot."
