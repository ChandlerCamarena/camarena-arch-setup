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
Usage: $0 [--skip a,b | --only a,b]

No flags needed: the selection install.sh recorded in
hosts/<hostname>.conf is used. Pass a flag only to change it.

$(profile_usage)
USAGE
}

PROFILE_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip|--only)
            [[ $# -ge 2 ]] || { err "$1 needs a value, e.g. $1 gaming,security"; exit 1; }
            PROFILE_ARGS=("$1" "$2"); shift 2 ;;
        --skip=*|--only=*) PROFILE_ARGS=("${1%%=*}" "${1#*=}"); shift ;;
        -h|--help) usage; exit 0 ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate now, before the pull; the selection is written after it, since
# the clean-tree check below would refuse a just-modified host file.
if [[ ${#PROFILE_ARGS[@]} -gt 0 ]]; then
    expand_profiles "${PROFILE_ARGS[1]}"
fi

# Stages check this to skip first-install-only steps
export CAS_MODE=update

log "Starting update from $SCRIPT_DIR"

# ---------------------------------------------------------------------------
log "Checking repo state before pulling..."
cd "$SCRIPT_DIR"

if ! git rev-parse --git-dir &>/dev/null; then
    err "$SCRIPT_DIR is not a git repo. Cannot update in place."
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    err "Repo has uncommitted changes. Commit or stash before running update.sh, or the pull below could conflict/fail unpredictably."
    git status --short
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "On branch $CURRENT_BRANCH, pulling latest (fast-forward only)..."
if ! git pull --ff-only; then
    err "git pull --ff-only failed. Local branch has likely diverged from upstream. Resolve manually (rebase/merge) and rerun update.sh."
    exit 1
fi

resolve_profiles "${PROFILE_ARGS[@]}"

# ---------------------------------------------------------------------------
log "Running preflight checks..."
bash "$SCRIPT_DIR/scripts/00-preflight.sh"

# ---------------------------------------------------------------------------
# Before anything is installed: the package sync below reinstalls every
# listed package, so a removal has to reach the lists first. Interactive on a
# terminal, report-only otherwise (CAS_NONINTERACTIVE=1 forces report-only).
log "Reviewing package lists against what's installed..."
bash "$SCRIPT_DIR/tools/sync-packages.sh"

# ---------------------------------------------------------------------------
log "Running full system upgrade (pacman -Syu)..."
sudo pacman -Syu --noconfirm

log "Syncing package lists (new packages in base/profiles, flatpak updates)..."
bash "$SCRIPT_DIR/scripts/01-pacman-packages.sh"

# ---------------------------------------------------------------------------
log "Checking source builds for updates (quickshell, xpadneo, grimblast, profile builds)..."
bash "$SCRIPT_DIR/scripts/02-build-from-source.sh"

# ---------------------------------------------------------------------------
log "Reconciling dotfiles with repo (overwrite managed files, prune removed ones)..."
bash "$SCRIPT_DIR/scripts/05-dotfiles-copy.sh"

# ---------------------------------------------------------------------------
log "Refreshing services and SDDM theme..."
bash "$SCRIPT_DIR/scripts/06-services.sh"

# ---------------------------------------------------------------------------
if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain -- packages/ hosts/)" ]]; then
    log "Package lists / host selection changed during this update; commit them (the next update.sh refuses a dirty tree):"
    git -C "$SCRIPT_DIR" status --short -- packages/ hosts/
fi
log "Update complete. Restart Hyprland or reboot to apply any changes."
