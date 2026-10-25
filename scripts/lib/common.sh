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

profile_active() {
    local target="$1"
    [[ " ${CAS_PROFILES:-} " == *" $target "* ]]
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" && ! -L "$target" ]]; then
        local backup
        backup="${target}.bak.$(date +%s)"
        log "Backing up existing $target -> $backup"
        mv "$target" "$backup"
    elif [[ -L "$target" ]]; then
        rm "$target"
    fi
}

# Every file copy_plain/copy_templated installs is recorded here. The
# previous run's list is what makes a path "repo-managed": those are
# overwritten without a .bak, and any the repo stops shipping are
# deleted by prune_managed at the end of the dotfiles stage.
MANIFEST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/camarena-arch-setup"
MANIFEST="$MANIFEST_DIR/managed-files"
MANIFEST_NEW="$MANIFEST_DIR/managed-files.new"

begin_managed() {
    mkdir -p "$MANIFEST_DIR"
    : > "$MANIFEST_NEW"
}

is_managed() {
    [[ -f "$MANIFEST" ]] && grep -qxF -- "$1" "$MANIFEST"
}

# Back up $dest only if it holds something we'd lose: not a file we
# installed last run, and not already identical to what replaces it.
backup_unless_managed() {
    local new="$1" dest="$2"
    if [[ -L "$dest" ]]; then
        rm "$dest"
    elif [[ -e "$dest" ]] && ! is_managed "$dest" && ! cmp -s "$new" "$dest"; then
        backup_if_exists "$dest"
    fi
}

install_file() {
    local new="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    backup_unless_managed "$new" "$dest"
    # Mode from the repo, so a script's executable bit is set (and kept in
    # sync) without per-file chmod lines
    cp --preserve=mode "$new" "$dest"
    echo "$dest" >> "$MANIFEST_NEW"
}

# Files under directory $1, NUL-separated, relative to it. Inside a git
# checkout: tracked plus untracked-but-not-ignored (so work in progress is
# included, __pycache__ and generated theme outputs are not). Plain find
# otherwise.
list_files() {
    local dir="$1"
    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        git -C "$dir" ls-files -z --cached --others --exclude-standard -- .
    else
        (cd "$dir" && find . -type f -printf '%P\0')
    fi
}

copy_plain() {
    local src="$1" dest="$2" f
    if [[ -d "$src" ]]; then
        # File by file, so things in $dest the repo doesn't ship
        # (oh-my-zsh, shell history) stay put instead of the whole
        # directory being moved aside.
        src="${src%/.}"
        while IFS= read -r -d '' f; do
            # ls-files still lists tracked files deleted from the working tree
            [[ -f "$src/$f" ]] || continue
            install_file "$src/$f" "$dest/$f"
        done < <(list_files "$src")
    else
        install_file "$src" "$dest"
    fi
    log "Copied $src -> $dest"
}

copy_templated() {
    local src="$1" dest="$2" tmp
    tmp="$(mktemp)"
    sed "s|__HOME__|$HOME|g" "$src" > "$tmp"
    install_file "$tmp" "$dest"
    rm -f "$tmp"
    log "Copied (templated) $src -> $dest"
}

# Delete files the last run installed that this run didn't, i.e. ones
# removed from the repo since. Only regular files: symlinks (the active
# rice) and anything never recorded are left alone.
prune_managed() {
    local f
    if [[ -f "$MANIFEST" ]]; then
        while IFS= read -r f; do
            grep -qxF -- "$f" "$MANIFEST_NEW" && continue
            [[ -f "$f" && ! -L "$f" ]] || continue
            log "Removing $f (no longer in repo)"
            rm -- "$f"
            rmdir -p --ignore-fail-on-non-empty "$(dirname "$f")" 2>/dev/null || true
        done < "$MANIFEST"
    fi
    sort -u "$MANIFEST_NEW" > "$MANIFEST"
    rm -f "$MANIFEST_NEW"
}

command_exists() {
    command -v "$1" &>/dev/null
}
