#!/usr/bin/env bash
# setup-snapshots.sh - install the snapshot/rollback/backup mechanisms on an
# already-running machine without a full install.sh/update.sh run.
# Creates no snapshots itself (the timers will, from the next day on).
# --purge-existing deletes every existing snapshot first.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/common.sh"
source "$SCRIPT_DIR/../scripts/lib/snapshots.sh"
source "$SCRIPT_DIR/../scripts/lib/profiles.sh"
require_not_root
require_arch

PURGE=0
case "${1:-}" in
    "") ;;
    --purge-existing) PURGE=1 ;;
    *) echo "usage: $0 [--purge-existing]" >&2; exit 1 ;;
esac

if [[ $PURGE -eq 1 ]]; then
    count="$(sudo snapper -c root --csvout --no-headers list --columns number | grep -vxc 0 || true)"
    read -rp "Delete ALL $count existing root snapshots (and any home ones)? [y/N] " ans
    [[ "$ans" == [yY] ]] || { err "aborted"; exit 1; }
    # the old hook would recreate snapshots during the pacman call below
    sudo rm -f /etc/pacman.d/hooks/00-snapshot.hook
    snapshots_purge root
    snapshots_purge home
fi

# Profile-specific excluded dirs (Steam -> gaming) follow this machine's selection
resolve_profiles

sudo pacman -S --needed --noconfirm snapper snap-pac
snapshots_setup_all

log "Done. snapper -c root list | snapper -c home list | sudo snap-rollback --list"
