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

Profiles (additive, combine as many as you want; base always installs):
  -g, --gaming     steam, gamescope, gamemode, mangohud, prismlauncher, wine
  -p, --personal   discord, spotify-launcher
  -S, --security   recon/RE/pentest tooling, Burp + Metasploit builds
  -s, --server     headless/server tooling
  -d, --dev        general dev toolchain (non-Datum)
  -D, --datum      Vulkan / Project Datum graphics-driver toolchain
  -m, --media      recording/streaming tooling
  -v, --virt       qemu/libvirt/virt-manager

Short flags may be combined, e.g. -gpD for gaming+personal+datum.
Any number of flags may be given, in any combination or order.
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
            # combined short flags, e.g. -gpD
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
    log "No profiles specified, base install only"
fi

log "Starting environment setup from $SCRIPT_DIR"

for stage in "$SCRIPT_DIR"/scripts/0*.sh; do
    log "Running $(basename "$stage")..."
    bash "$stage"
done

log "All stages complete. Reboot or restart Hyprland to apply changes."

if [[ -f "$SCRIPT_DIR/install.sh" && -d "$SCRIPT_DIR/scripts" && -d "$SCRIPT_DIR/config" && -d "$SCRIPT_DIR/packages" ]]; then
    cd "$HOME"
    log "Removing repo directory $SCRIPT_DIR"
    rm -rf "$SCRIPT_DIR"
    log "Done."
else
    log "WARNING: safety check failed, not deleting $SCRIPT_DIR. Remove it manually if desired."
fi
