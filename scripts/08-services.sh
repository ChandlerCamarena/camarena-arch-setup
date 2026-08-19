#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root
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
