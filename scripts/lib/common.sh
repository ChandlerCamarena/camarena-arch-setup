#!/usr/bin/env bash
# common.sh - shared functions for all install stages
# sourced, not executed directly

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

err() {
    echo "[$(date +%H:%M:%S)] ERROR: $*" >&2
}

require_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        err "Do not run this as root. Run as your normal user; sudo is invoked internally where needed."
        exit 1
    fi
}

require_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        err "This script targets Arch Linux only. /etc/arch-release not found."
        exit 1
    fi
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup="${target}.bak.$(date +%s)"
        log "Backing up existing $target -> $backup"
        mv "$target" "$backup"
    elif [[ -L "$target" ]]; then
        rm "$target"
    fi
}

copy_plain() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    backup_if_exists "$dest"
    cp -r "$src" "$dest"
    log "Copied $src -> $dest"
}

copy_templated() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    backup_if_exists "$dest"
    sed "s|__HOME__|$HOME|g" "$src" > "$dest"
    log "Copied (templated) $src -> $dest"
}

command_exists() {
    command -v "$1" &>/dev/null
}
