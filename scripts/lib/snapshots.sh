#!/usr/bin/env bash
# snapshots.sh - snapper/snap-pac/rollback setup, shared by 01-pacman-packages.sh
# and tools/setup-snapshots.sh. Sourced, not executed directly; needs common.sh.
# Nothing here creates a snapshot; callers decide that.

SNAP_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" && pwd)"

# create-config wants to create /.snapshots itself and fails when the
# @snapshots subvolume is already mounted there (our fstab layout). Arch
# wiki workaround: let it create its nested subvolume, then swap back to @snapshots.
snapshots_create_config() {
    local name="$1" path="$2"
    if sudo snapper -c "$name" get-config &>/dev/null; then
        log "Snapper config '$name' already exists, skipping create-config."
        return
    fi
    local snapdir="${path%/}/.snapshots"
    if mountpoint -q "$snapdir"; then
        log "Creating snapper config '$name' around existing $snapdir mount..."
        sudo umount "$snapdir"
        sudo rmdir "$snapdir"
        sudo snapper -c "$name" create-config "$path"
        sudo btrfs subvolume delete "$snapdir"
        sudo mkdir "$snapdir"
        sudo mount "$snapdir"
        sudo chmod 750 "$snapdir"
    else
        log "Creating snapper config '$name' for $path..."
        sudo snapper -c "$name" create-config "$path"
    fi
}

# key=value lines from config/snapper/<name>.conf -> snapper set-config
snapshots_apply_settings() {
    local name="$1" conf="$SNAP_SRC/snapper/$1.conf"
    [[ -f "$conf" ]] || { err "No $conf, leaving '$name' at snapper defaults."; return; }
    mapfile -t kv < <(grep -vE '^\s*#|^\s*$' "$conf")
    log "Applying ${#kv[@]} settings to snapper config '$name'..."
    sudo snapper -c "$name" set-config "${kv[@]}"
}

snapshots_install_hooks() {
    log "Installing /boot mirror hooks + snap-boot-backup..."
    sudo install -Dm755 "$SNAP_SRC/snapper/snap-boot-backup" /usr/local/bin/snap-boot-backup
    sudo install -Dm644 "$SNAP_SRC/pacman-hooks/00-boot-backup.hook" /etc/pacman.d/hooks/00-boot-backup.hook
    sudo install -Dm644 "$SNAP_SRC/pacman-hooks/95-boot-backup-post.hook" /etc/pacman.d/hooks/95-boot-backup-post.hook
    # superseded by snap-pac (pre+post pairs with cleanup); leaving it
    # would double every pre snapshot and those never get cleaned up
    sudo rm -f /etc/pacman.d/hooks/00-snapshot.hook
}

snapshots_install_tools() {
    log "Installing snap-rollback/snap-baseline/snap-backup and snbk backup configs..."
    for t in snap-rollback snap-baseline snap-backup; do
        sudo install -Dm755 "$SNAP_SRC/snapper/$t" "/usr/local/bin/$t"
    done
    sudo install -Dm644 "$SNAP_SRC/snapper/systemd/snap-backup.service" /etc/systemd/system/snap-backup.service
    sudo install -Dm644 "$SNAP_SRC/snapper/systemd/snap-backup.timer" /etc/systemd/system/snap-backup.timer
    # install.sh --delete-repo removes the clone, so keep a copy of the docs
    sudo install -Dm644 "$SNAP_SRC/../docs/snapshots-and-backups.md" \
        /usr/local/share/doc/camarena-arch-setup/snapshots-and-backups.md
    # automatic=false: snbk never runs on its own, see docs/snapshots-and-backups.md
    for f in "$SNAP_SRC"/snapper/backup-configs/*.json; do
        sudo install -Dm644 "$f" "/etc/snapper/backup-configs/${f##*/}"
    done
}

snapshots_enable_timers() {
    sudo install -Dm644 "$SNAP_SRC/snapper/systemd/snapper-timeline-daily.conf" \
        /etc/systemd/system/snapper-timeline.timer.d/daily.conf
    sudo systemctl daemon-reload
    # snap-backup.timer exits cleanly when no CAS-BACKUP drive is connected
    for t in snapper-timeline.timer snapper-cleanup.timer snap-backup.timer; do
        if systemctl is-enabled --quiet "$t" 2>/dev/null; then
            log "$t already enabled."
        else
            log "Enabling $t..."
            sudo systemctl enable --now "$t"
        fi
    done
}

# Deletes every existing snapshot of a config (except 0 = live system).
# Only called on explicit request (tools/setup-snapshots.sh --purge-existing).
snapshots_purge() {
    local name="$1"
    sudo snapper -c "$name" get-config &>/dev/null || return 0
    mapfile -t nums < <(sudo snapper -c "$name" --csvout --no-headers list --columns number | grep -vx 0)
    if [[ ${#nums[@]} -eq 0 ]]; then
        log "No '$name' snapshots to delete."
        return
    fi
    log "Deleting ${#nums[@]} '$name' snapshots..."
    sudo snapper -c "$name" delete --sync "${nums[@]}"
}

# Directories that must never be in /home snapshots or backups. Created as
# nested subvolumes before anything is put in them (snapshots don't recurse).
# Existing directories: tools/make-subvolume.sh <dir>
# "<dir>|<profile>": only created when that profile is active; no profile
# means always.
SNAPSHOT_EXCLUDED_DIRS=(
    "$HOME/.local/share/Steam|gaming"   # 1.5T of re-downloadable games
    "$HOME/AI/models"                   # re-downloadable model weights
)

snapshots_exclude_dirs() {
    local entry d profile
    for entry in "${SNAPSHOT_EXCLUDED_DIRS[@]}"; do
        d="${entry%%|*}"
        profile=""
        [[ "$entry" == *"|"* ]] && profile="${entry#*|}"
        if [[ -n "$profile" ]] && ! profile_active "$profile"; then
            continue
        fi
        if [[ ! -e "$d" ]]; then
            mkdir -p "$(dirname "$d")"
            btrfs subvolume create "$d" >/dev/null
            log "Created $d as its own subvolume (excluded from snapshots)."
        elif [[ "$(stat -c %i "$d")" != 256 ]]; then
            err "$d exists as a plain directory and IS included in /home snapshots; convert it with tools/make-subvolume.sh"
        fi
    done
}

snapshots_setup_all() {
    snapshots_create_config root /
    snapshots_apply_settings root
    snapshots_create_config home /home
    snapshots_apply_settings home
    snapshots_exclude_dirs
    snapshots_install_hooks
    snapshots_install_tools
    snapshots_enable_timers
}
