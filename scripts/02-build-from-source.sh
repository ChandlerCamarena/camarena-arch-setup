#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root

QS_SRC_DIR="$HOME/.local/src/quickshell"
QS_BUILD_MARKER="$QS_SRC_DIR/.last-built-commit"
mkdir -p "$(dirname "$QS_SRC_DIR")"

if [[ ! -d "$QS_SRC_DIR" ]]; then
    log "Cloning QuickShell..."
    git clone https://github.com/quickshell-mirror/quickshell.git "$QS_SRC_DIR"
fi

cd "$QS_SRC_DIR"
log "Fetching latest QuickShell source..."
git fetch origin
REMOTE_HEAD="$(git rev-parse origin/master)"
LOCAL_BUILT="$(cat "$QS_BUILD_MARKER" 2>/dev/null || echo "none")"

if [[ "$REMOTE_HEAD" != "$LOCAL_BUILT" ]]; then
    log "Building QuickShell ($LOCAL_BUILT -> $REMOTE_HEAD)..."
    git checkout master
    git merge --ff-only origin/master
    cmake -B build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DINSTALL_QMLDIR=/usr/lib/qt6/qml \
        -DVENDOR_CPPTRACE=ON
    cmake --build build
    sudo cmake --install build
    echo "$REMOTE_HEAD" > "$QS_BUILD_MARKER"
    log "QuickShell built and installed successfully."
else
    log "QuickShell already up to date ($LOCAL_BUILT)."
fi

log "Fetching grimblast (AUR-only upstream, pulled as a single script instead)..."
mkdir -p "$HOME/.local/bin"
curl -fsSL https://raw.githubusercontent.com/hyprwm/contrib/main/grimblast/grimblast \
    -o "$HOME/.local/bin/grimblast"
chmod +x "$HOME/.local/bin/grimblast"
log "grimblast installed to $HOME/.local/bin/grimblast"

log "Installing xpadneo (Xbox controller Bluetooth DKMS driver, AUR-only upstream, built from source instead)..."
XPADNEO_SRC_DIR="$HOME/.local/src/xpadneo"
if [[ ! -d "$XPADNEO_SRC_DIR" ]]; then
    log "Cloning xpadneo..."
    git clone https://github.com/atar-axis/xpadneo.git "$XPADNEO_SRC_DIR"
else
    log "xpadneo source already present, pulling latest..."
    git -C "$XPADNEO_SRC_DIR" pull --ff-only
fi

if sudo dkms status | grep -q '^hid-xpadneo'; then
    log "xpadneo DKMS module already registered, skipping install."
else
    log "Installing xpadneo via its own install script (runs dkms add/build/install)..."
    (cd "$XPADNEO_SRC_DIR" && sudo ./install.sh)
fi

# ---------------------------------------------------------------------------
# Profile-specific build-from-source steps. Base builds above always run.
# Each active profile's scripts/lib/builds/<profile>.sh, if present, is
# sourced and its run_<profile>_builds function is called.
BUILD_LIB_DIR="$SCRIPT_DIR/lib/builds"

for profile in ${CAS_PROFILES:-}; do
    profile_build_script="$BUILD_LIB_DIR/${profile}.sh"
    if [[ -f "$profile_build_script" ]]; then
        log "Running build-from-source steps for profile: $profile"
        source "$profile_build_script"
        "run_${profile}_builds"
    fi
done

log "Build-from-source stage complete."
