#!/usr/bin/env bash
# vm.sh - throwaway QEMU/KVM Arch VM for testing this repo end to end before
# it touches real hardware. See docs/vm-testing.md.
#
#   tools/vm/vm.sh test [flags] [--gui]   whole pipeline: base (if missing),
#                                         install, update, reboot + check
#   tools/vm/vm.sh base [--force]    build the bare-Arch base image (once)
#   tools/vm/vm.sh install [flags]   fresh VM from base, run install.sh [flags]
#   tools/vm/vm.sh update [flags]    run update.sh [flags] in the current VM
#   tools/vm/vm.sh check             run tools/vm/checks.sh in the current VM
#   tools/vm/vm.sh start [--headless]  boot the current VM (with a display)
#   tools/vm/vm.sh ssh [cmd...]      shell (or one command) in the running VM
#   tools/vm/vm.sh stop              shut the running VM down
#   tools/vm/vm.sh reset             discard the current VM, back to base
#
# [flags] are install.sh/update.sh profile flags (--skip a,b / --only a,b;
# none = all profiles). Pass the same ones to update: the VM's host file
# doesn't survive the fresh repo copy. The repo is copied in as it is on
# disk, uncommitted changes included.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"
require_not_root

VM_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/camarena-arch-setup/vm"
VM_MEM="${VM_MEM:-8G}"
VM_CPUS="${VM_CPUS:-4}"
VM_DISK_SIZE="${VM_DISK_SIZE:-80G}"
VM_SSH_PORT="${VM_SSH_PORT:-2222}"
VM_DISPLAY="${VM_DISPLAY:-gtk,gl=on}"   # sdl,gl=on if GTK+GL misbehaves
ISO_MIRROR="${ISO_MIRROR:-https://geo.mirror.pkgbuild.com/iso/latest}"

# Deliberately not your username, so hardcoded /home/<you> paths show up
VM_USER=tester
VM_PASS=tester
VM_HOST=cas-vm

# Arch's edk2-ovmf paths; override on other distros (CI on Ubuntu:
# /usr/share/OVMF/OVMF_{CODE,VARS}_4M.fd)
OVMF_CODE="${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}"
OVMF_VARS="${OVMF_VARS:-/usr/share/edk2/x64/OVMF_VARS.4m.fd}"

ISO="$VM_DIR/archlinux-x86_64.iso"
BASE="$VM_DIR/base.qcow2"
BASE_VARS="$VM_DIR/base-vars.fd"
DISK="$VM_DIR/current.qcow2"   # overlay on BASE, all changes land here
VARS="$VM_DIR/current-vars.fd"
PKG_CACHE="$VM_DIR/pkgcache.qcow2"   # survives reset, see use_pkg_cache
KEY="$VM_DIR/id_ed25519"
PIDFILE="$VM_DIR/qemu.pid"
SERIAL_LOG="$VM_DIR/serial.log"
QEMU_LOG="$VM_DIR/qemu.log"

SSH_OPTS=(-i "$KEY" -p "$VM_SSH_PORT"
          -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR -o ConnectTimeout=5)

usage() {
    sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

require_host() {
    local missing=() c
    for c in qemu-system-x86_64 qemu-img xorriso ssh ssh-keygen rsync curl; do
        command_exists "$c" || missing+=("$c")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing host tools: ${missing[*]} (the virt profile provides them)"
        exit 1
    fi
    [[ -f "$OVMF_CODE" && -f "$OVMF_VARS" ]] \
        || { err "No UEFI firmware at $OVMF_CODE / $OVMF_VARS (edk2-ovmf; or set OVMF_CODE/OVMF_VARS)"; exit 1; }
    [[ -w /dev/kvm ]]     || { err "/dev/kvm not writable; is KVM enabled and are you in the kvm group?"; exit 1; }
    mkdir -p "$VM_DIR"
}

vm_running() {
    [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

# Launch QEMU detached on $1 (disk) / $2 (vars), "gui" or "headless" as $3,
# anything after that passed straight to QEMU.
qemu_launch() {
    local disk="$1" vars="$2" mode="$3"
    shift 3
    local display=(-display none -device virtio-vga)
    if [[ "$mode" == gui ]]; then
        display=(-display "$VM_DISPLAY" -device virtio-vga-gl)
    fi
    # Not during base: guest-install.sh assumes /dev/vda is the only disk
    local pkg=()
    if [[ "$disk" == "$DISK" ]]; then
        [[ -f "$PKG_CACHE" ]] || qemu-img create -q -f qcow2 "$PKG_CACHE" 60G
        # shellcheck disable=SC2054  # commas are QEMU's option syntax, not separators
        pkg=(-drive if=none,id=pkg,format=qcow2,file="$PKG_CACHE"
             -device virtio-blk-pci,drive=pkg,serial=pkgcache)
    fi
    rm -f "$PIDFILE"
    : > "$SERIAL_LOG"
    setsid -f qemu-system-x86_64 \
        -name cas-vm \
        -machine q35,accel=kvm -cpu host -smp "$VM_CPUS" -m "$VM_MEM" \
        -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
        -drive if=pflash,format=raw,file="$vars" \
        -drive if=none,id=disk,format=qcow2,file="$disk" \
        -device virtio-blk-pci,drive=disk,bootindex=1 \
        "${pkg[@]}" \
        -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:"$VM_SSH_PORT"-:22 \
        -device virtio-tablet-pci -device virtio-keyboard-pci \
        "${display[@]}" \
        -serial file:"$SERIAL_LOG" \
        -pidfile "$PIDFILE" \
        "$@" >"$QEMU_LOG" 2>&1
    local i
    for i in {1..20}; do
        vm_running && return 0
        sleep 0.5
    done
    err "QEMU didn't start:"
    cat "$QEMU_LOG" >&2
    exit 1
}

vm_wait_exit() {
    local timeout="$1" i
    for (( i=0; i<timeout; i++ )); do
        vm_running || return 0
        sleep 1
    done
    return 1
}

vm_ssh() {
    ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "$@"
}

wait_ssh() {
    log "Waiting for the VM to come up on ssh (port $VM_SSH_PORT)..."
    local i
    for i in {1..90}; do
        vm_ssh true 2>/dev/null && return 0
        vm_running || { err "VM exited while booting; see $SERIAL_LOG"; exit 1; }
        sleep 2
    done
    err "No ssh after 3 minutes; see $SERIAL_LOG"
    exit 1
}

# Mount the persistent cache disk over the VM's own pacman cache, so packages
# download once instead of once per fresh VM. Only for the install/update run
# itself; a plain boot leaves the VM's real @pkg cache in place.
use_pkg_cache() {
    vm_ssh 'set -e
        dev=/dev/disk/by-id/virtio-pkgcache
        [ -b "$dev" ] || exit 0
        sudo blkid "$dev" >/dev/null || sudo mkfs.btrfs -q -L vm-pkgcache "$dev"
        findmnt -S "$(readlink -f "$dev")" >/dev/null || sudo mount "$dev" /var/cache/pacman/pkg'
    log "Using the shared package cache ($PKG_CACHE)."
}

# Working tree as-is, uncommitted changes and .git included, into ~/$1
sync_repo() {
    local dest="${1:-camarena-arch-setup}"
    log "Copying $REPO_ROOT into the VM (~/$dest)..."
    rsync -a --delete -e "ssh ${SSH_OPTS[*]}" \
        "$REPO_ROOT/" "$VM_USER@127.0.0.1:$dest/"
}

# update.sh wants a clean git checkout it can pull into. The real origin
# (GitHub over ssh) has no credentials in the VM and isn't what's under test
# anyway, so: working tree -> ~/cas-upstream, uncommitted changes committed
# there, and ~/camarena-arch-setup re-cloned from it. update.sh's pull then
# runs for real against exactly the host's state, offline.
sync_repo_for_update() {
    sync_repo cas-upstream
    vm_ssh 'set -e
        cd ~/cas-upstream
        if [ -n "$(git status --porcelain)" ]; then
            git add -A
            git -c user.name=vm -c user.email=vm@localhost \
                commit -q --no-verify -m "vm: uncommitted host changes"
        fi
        rm -rf ~/camarena-arch-setup
        git clone -q ~/cas-upstream ~/camarena-arch-setup'
}

# Runs $1 (install.sh/update.sh) in the VM with profile flags, logs to
# $VM_DIR/<name>.log, returns its exit code.
run_in_vm() {
    local script="$1"
    shift
    local name="${script%.sh}" quoted=""
    [[ $# -gt 0 ]] && quoted="$(printf '%q ' "$@")"
    log "Running $script $* in the VM (log: $VM_DIR/$name.log)..."
    set +e
    # Nobody's at the prompts in here; sync-packages.sh reports instead of asking
    vm_ssh -t "cd camarena-arch-setup && CAS_NONINTERACTIVE=1 ./$script $quoted" 2>&1 | tee "$VM_DIR/$name.log"
    local rc="${PIPESTATUS[0]}"
    set -e
    return "$rc"
}

new_overlay() {
    rm -f "$DISK" "$VARS"
    qemu-img create -q -f qcow2 -b "$BASE" -F qcow2 "$DISK"
    cp "$BASE_VARS" "$VARS"
}

require_base() {
    [[ -f "$BASE" ]] || { err "No base image yet. Run: $0 base"; exit 1; }
}

require_stopped() {
    if vm_running; then
        err "The VM is running. Stop it first: $0 stop"
        exit 1
    fi
}

# ---------------------------------------------------------------------------

fetch_iso() {
    log "Checking for the latest Arch ISO..."
    local sums want
    sums="$(curl -fsSL "$ISO_MIRROR/sha256sums.txt")"
    want="$(awk '$2 == "archlinux-x86_64.iso" {print $1}' <<<"$sums")"
    [[ -n "$want" ]] || { err "archlinux-x86_64.iso not listed in $ISO_MIRROR/sha256sums.txt"; exit 1; }

    if [[ -f "$ISO" ]] && [[ "$(sha256sum "$ISO" | awk '{print $1}')" == "$want" ]]; then
        log "Cached ISO is current."
        return
    fi
    log "Downloading $ISO_MIRROR/archlinux-x86_64.iso..."
    curl -fL --progress-bar -o "$ISO.part" "$ISO_MIRROR/archlinux-x86_64.iso"
    curl -fsSL -o "$ISO.sig" "$ISO_MIRROR/archlinux-x86_64.iso.sig"
    [[ "$(sha256sum "$ISO.part" | awk '{print $1}')" == "$want" ]] \
        || { err "ISO checksum mismatch"; rm -f "$ISO.part"; exit 1; }
    # On Arch the release signing key is in the pacman keyring; elsewhere
    # (CI) fetch it by WKD, as archlinux.org/download describes
    if command_exists pacman-key; then
        log "Verifying ISO signature against the pacman keyring..."
        pacman-key -v "$ISO.sig" "$ISO.part" \
            || { err "ISO signature check failed"; rm -f "$ISO.part"; exit 1; }
    else
        log "Verifying ISO signature (release key via WKD)..."
        local gnupg
        gnupg="$(mktemp -d)"
        gpg --homedir "$gnupg" --quiet --auto-key-locate clear,wkd --locate-external-keys pierre@archlinux.org
        gpg --homedir "$gnupg" --verify "$ISO.sig" "$ISO.part" \
            || { err "ISO signature check failed"; rm -rf "$ISO.part" "$gnupg"; exit 1; }
        rm -rf "$gnupg"
    fi
    mv "$ISO.part" "$ISO"
}

build_seed() {
    local seed="$VM_DIR/seed"
    rm -rf "$seed"
    mkdir -p "$seed"
    [[ -f "$KEY" ]] || ssh-keygen -q -t ed25519 -N "" -C cas-vm -f "$KEY"
    cp "$SCRIPT_DIR/guest-install.sh" "$SCRIPT_DIR/base-packages.txt" "$seed/"
    cp "$KEY.pub" "$seed/authorized_keys"
    printf 'VM_USER=%q\nVM_PASS=%q\nVM_HOST=%q\n' "$VM_USER" "$VM_PASS" "$VM_HOST" > "$seed/vm.env"
    echo "instance-id: cas-vm-base" > "$seed/meta-data"
    cat > "$seed/user-data" <<'EOF'
#cloud-config
runcmd:
  - [bash, -c, "mkdir -p /run/seed && mount -o ro /dev/disk/by-label/cidata /run/seed && bash /run/seed/guest-install.sh"]
EOF
    # NoCloud datasource: any disk labelled cidata with user-data + meta-data
    xorriso -as mkisofs -quiet -V cidata -J -R -o "$VM_DIR/seed.iso" "$seed"
}

cmd_base() {
    require_host
    require_stopped
    if [[ -f "$BASE" && "${1:-}" != --force ]]; then
        log "Base image already exists at $BASE (rebuild: $0 base --force)."
        return
    fi
    fetch_iso
    build_seed

    log "Installing bare Arch into a fresh $VM_DISK_SIZE disk (headless, ~10 min)..."
    rm -f "$DISK" "$VARS"   # an overlay on the old base would be garbage
    qemu-img create -q -f qcow2 "$BASE.part" "$VM_DISK_SIZE"
    cp "$OVMF_VARS" "$BASE_VARS.part"
    qemu_launch "$BASE.part" "$BASE_VARS.part" headless \
        -drive if=none,id=iso,media=cdrom,readonly=on,file="$ISO" \
        -device ide-cd,drive=iso,bus=ide.0,bootindex=0 \
        -drive if=none,id=seed,media=cdrom,readonly=on,file="$VM_DIR/seed.iso" \
        -device ide-cd,drive=seed,bus=ide.1

    # The guest powers itself off when done, either way
    tail -n +1 -f --pid="$(cat "$PIDFILE")" "$SERIAL_LOG" | grep --line-buffered '^\[guest\]\|VM-INSTALL' || true
    if ! vm_wait_exit 60; then
        err "VM still running after install finished; killing it."
        kill "$(cat "$PIDFILE")"
    fi

    if grep -q VM-INSTALL-OK "$SERIAL_LOG"; then
        mv "$BASE.part" "$BASE"
        mv "$BASE_VARS.part" "$BASE_VARS"
        log "Base image ready: $BASE"
    else
        err "Base install failed. Full output: $SERIAL_LOG"
        rm -f "$BASE.part" "$BASE_VARS.part"
        exit 1
    fi
}

cmd_install() {
    require_host
    require_base
    require_stopped
    log "Fresh VM from base..."
    new_overlay
    qemu_launch "$DISK" "$VARS" headless
    wait_ssh
    use_pkg_cache
    sync_repo
    local rc=0
    run_in_vm install.sh "$@" || rc=$?
    log "Shutting the VM down..."
    vm_ssh sudo systemctl poweroff 2>/dev/null || true
    vm_wait_exit 60 || kill "$(cat "$PIDFILE")"
    if [[ $rc -ne 0 ]]; then
        err "install.sh failed (exit $rc). Log: $VM_DIR/install.log. Poke at it: $0 start"
        exit "$rc"
    fi
    log "install.sh passed. See the desktop: $0 start  (login $VM_USER / $VM_PASS)"
}

cmd_update() {
    require_host
    [[ -f "$DISK" ]] || { err "No current VM. Run: $0 install [flags]"; exit 1; }
    local booted=0
    if ! vm_running; then
        qemu_launch "$DISK" "$VARS" headless
        booted=1
    fi
    wait_ssh
    use_pkg_cache
    sync_repo_for_update
    local rc=0
    run_in_vm update.sh "$@" || rc=$?
    if [[ $booted -eq 1 ]]; then
        vm_ssh sudo systemctl poweroff 2>/dev/null || true
        vm_wait_exit 60 || kill "$(cat "$PIDFILE")"
    fi
    if [[ $rc -ne 0 ]]; then
        err "update.sh failed (exit $rc). Log: $VM_DIR/update.log"
        exit "$rc"
    fi
    log "update.sh passed."
}

cmd_check() {
    require_host
    [[ -f "$DISK" ]] || { err "No current VM. Run: $0 install [flags]"; exit 1; }
    local booted=0
    if ! vm_running; then
        qemu_launch "$DISK" "$VARS" headless
        booted=1
    fi
    wait_ssh
    local rc=0
    vm_ssh 'bash -s' < "$SCRIPT_DIR/checks.sh" | tee "$VM_DIR/check.log" || rc=$?
    if [[ $booted -eq 1 ]]; then
        vm_ssh sudo systemctl poweroff 2>/dev/null || true
        vm_wait_exit 60 || kill "$(cat "$PIDFILE")"
    fi
    return "$rc"
}

STAGE_RESULTS=()

print_summary() {
    echo
    log "Pipeline summary:"
    local line
    for line in "${STAGE_RESULTS[@]}"; do
        echo "    $line"
    done
}

# Each stage in a subshell so a stage's own `exit` ends the stage, not the
# pipeline before the summary. set -e re-enabled inside: a subshell that's
# part of an || list would otherwise run with errexit silently off.
run_stage() {
    local name="$1" start="$SECONDS" rc took
    shift
    log "===== STAGE: $name ====="
    set +e
    ( set -e; "$@" )
    rc=$?
    set -e
    took=$(( SECONDS - start ))
    STAGE_RESULTS+=("$(printf '%-8s %-5s %3dm%02ds' "$name" \
        "$([[ $rc -eq 0 ]] && echo PASS || echo FAIL)" $((took / 60)) $((took % 60)))")
    if [[ $rc -ne 0 ]]; then
        print_summary
        err "Stopped at '$name'. Logs: $VM_DIR/{install,update,check,serial}.log"
        exit "$rc"
    fi
}

cmd_test() {
    local gui=0 flags=() a
    for a in "$@"; do
        if [[ "$a" == --gui ]]; then gui=1; else flags+=("$a"); fi
    done
    require_host
    require_stopped
    run_stage base    cmd_base
    run_stage install cmd_install "${flags[@]}"
    # update.sh straight after install: must succeed, and must leave no .bak
    # files behind (everything it touches was just installed by the repo)
    run_stage update  cmd_update "${flags[@]}"
    run_stage check   cmd_check
    print_summary
    log "All stages passed."
    if [[ $gui -eq 1 ]]; then
        cmd_start
    fi
}

cmd_start() {
    require_host
    require_stopped
    if [[ ! -f "$DISK" ]]; then
        require_base
        log "No current VM, starting a fresh one from base."
        new_overlay
    fi
    local mode=gui
    [[ "${1:-}" == --headless ]] && mode=headless
    qemu_launch "$DISK" "$VARS" "$mode"
    if [[ "$mode" == headless ]]; then
        wait_ssh
        log "VM up without a display. Shell: $0 ssh   Stop: $0 stop"
    else
        log "VM started (login $VM_USER / $VM_PASS). Shell: $0 ssh   Stop: $0 stop"
    fi
}

cmd_ssh() {
    vm_running || { err "VM isn't running. $0 start"; exit 1; }
    vm_ssh "$@"
}

cmd_stop() {
    if ! vm_running; then
        log "VM isn't running."
        return
    fi
    log "Shutting the VM down..."
    vm_ssh sudo systemctl poweroff 2>/dev/null || true
    if ! vm_wait_exit 60; then
        log "No clean shutdown after 60s, killing QEMU."
        kill "$(cat "$PIDFILE")"
    fi
}

cmd_reset() {
    cmd_stop
    rm -f "$DISK" "$VARS"
    log "Current VM discarded. Next install/start begins from the base image."
}

case "${1:-}" in
    test|base|install|update|check|start|ssh|stop|reset)
        cmd="$1"
        shift
        "cmd_$cmd" "$@"
        ;;
    -h|--help|help|"") usage ;;
    *) err "Unknown command: $1"; usage; exit 1 ;;
esac
