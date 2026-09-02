#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

err() {
    echo "[$(date +%H:%M:%S)] ERROR: $*" >&2
}

usage() {
    cat <<USAGE
Usage: $0 [profile flags]

Same profile flags as install.sh. Pass whichever profiles are active
on this machine so package/build steps know what to sync.

Profiles (additive, combine as many as you want; base always updates):
  -g, --gaming     -p, --personal   -S, --security   -s, --server
  -d, --dev        -D, --datum      -m, --media      -v, --virt

Short flags may be combined, e.g. -gpD.
USAGE
}

declare -A VALID_PROFILES=(
    [g]=gaming [p]=personal [S]=security [s]=server
    [d]=dev [D]=datum [m]=media [v]=virt
)

PROFILES=()

add_profile() {
    local name="$1"
    if [[ ! " ${PROFILES[*]:-} " == *" $name "* ]]; then
        PROFILES+=("$name")
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gaming) add_profile gaming; shift ;;
        --personal) add_profile personal; shift ;;
        --security) add_profile security; shift ;;
        --server) add_profile server; shift ;;
        --dev) add_profile dev; shift ;;
        --datum) add_profile datum; shift ;;
        --media) add_profile media; shift ;;
        --virt) add_profile virt; shift ;;
        -h|--help) usage; exit 0 ;;
        -*)
            flagstr="${1#-}"
            for (( i=0; i<${#flagstr}; i++ )); do
                c="${flagstr:$i:1}"
                if [[ -n "${VALID_PROFILES[$c]:-}" ]]; then
                    add_profile "${VALID_PROFILES[$c]}"
                else
                    err "Unknown flag: -$c"
                    usage
                    exit 1
                fi
            done
            shift
            ;;
        *)
            err "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

export CAS_PROFILES="${PROFILES[*]:-}"

if [[ -n "$CAS_PROFILES" ]]; then
    log "Active profiles: $CAS_PROFILES"
else
    log "No profiles specified, base update only"
fi

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

# ---------------------------------------------------------------------------
log "Running preflight checks..."
bash "$SCRIPT_DIR/scripts/00-preflight.sh"

# ---------------------------------------------------------------------------
log "Running full system upgrade (pacman -Syu)..."
sudo pacman -Syu --noconfirm

log "Syncing package lists (new packages in base/profiles, flatpak updates)..."
bash "$SCRIPT_DIR/scripts/01-pacman-packages.sh"

# ---------------------------------------------------------------------------
log "Checking source builds for updates (quickshell, xpadneo, grimblast, profile builds)..."
bash "$SCRIPT_DIR/scripts/02-build-from-source.sh"

# ---------------------------------------------------------------------------
log "Refreshing dotfiles from repo..."
bash "$SCRIPT_DIR/scripts/05-dotfiles-copy.sh"

# ---------------------------------------------------------------------------
log "Refreshing services and SDDM theme..."
bash "$SCRIPT_DIR/scripts/06-services.sh"

# ---------------------------------------------------------------------------
log "Update complete. Restart Hyprland or reboot to apply any changes."
