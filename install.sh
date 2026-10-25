#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

err() {
    echo "[$(date +%H:%M:%S)] ERROR: $*" >&2
}

source "$SCRIPT_DIR/scripts/lib/profiles.sh"

usage() {
    cat <<USAGE
Usage: $0 [--skip a,b | --only a,b] [--delete-repo]

$(profile_usage)

  --delete-repo    remove this clone after every stage passes. By default
                   it's kept, since update.sh runs from it.
USAGE
}

PROFILE_ARGS=()
DELETE_REPO=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip|--only)
            [[ $# -ge 2 ]] || { err "$1 needs a value, e.g. $1 gaming,security"; exit 1; }
            PROFILE_ARGS=("$1" "$2"); shift 2 ;;
        --skip=*|--only=*) PROFILE_ARGS=("${1%%=*}" "${1#*=}"); shift ;;
        --delete-repo) DELETE_REPO=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

resolve_profiles "${PROFILE_ARGS[@]}"

log "Starting environment setup from $SCRIPT_DIR"

# Repo linter on every commit (scripts/git-hooks/pre-commit -> verify-repo.sh)
if [[ -d "$SCRIPT_DIR/.git" ]]; then
    git -C "$SCRIPT_DIR" config --local core.hooksPath scripts/git-hooks
fi

for stage in "$SCRIPT_DIR"/scripts/0*.sh; do
    log "Running $(basename "$stage")..."
    bash "$stage"
done

log "All stages complete. Reboot or restart Hyprland to apply changes."

# Known-good restore point for `snap-rollback --baseline`, never auto-pruned.
if [[ -x /usr/local/bin/snap-baseline ]]; then
    log "Creating clean-install baseline snapshot (root + home)..."
    sudo /usr/local/bin/snap-baseline "clean install (camarena-arch-setup)"
fi

if [[ "$DELETE_REPO" -eq 0 ]]; then
    log "Repo kept at $SCRIPT_DIR (update.sh runs from here)."
elif [[ -f "$SCRIPT_DIR/install.sh" && -d "$SCRIPT_DIR/scripts" && -d "$SCRIPT_DIR/config" && -d "$SCRIPT_DIR/packages" ]]; then
    cd "$HOME"
    log "Removing repo directory $SCRIPT_DIR"
    rm -rf "$SCRIPT_DIR"
    log "Done."
else
    log "WARNING: safety check failed, not deleting $SCRIPT_DIR. Remove it manually if desired."
fi
