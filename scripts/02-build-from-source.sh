#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
require_not_root

source "$SCRIPT_DIR/lib/sources.sh"

# Every source here is pinned in packages/sources.txt; a rebuild happens when
# the pin differs from what was last built (the .last-built-commit marker).

QS_SRC_DIR="$HOME/.local/src/quickshell"
QS_BUILD_MARKER="$QS_SRC_DIR/.last-built-commit"
QS_PIN="$(source_get quickshell pin)"
# Quickshell builds against Qt's private API, so a Qt update can break the
# installed binary even at the same pin: rebuild when either changes.
QS_BUILD_ID="$QS_PIN qt6-base=$(pacman -Q qt6-base | cut -d' ' -f2)"
if [[ "$(cat "$QS_BUILD_MARKER" 2>/dev/null)" != "$QS_BUILD_ID" ]]; then
    source_checkout quickshell "$QS_SRC_DIR"
    log "Building QuickShell @ ${QS_PIN:0:12}..."
    cd "$QS_SRC_DIR"
    cmake -B build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DINSTALL_QMLDIR=/usr/lib/qt6/qml \
        -DVENDOR_CPPTRACE=ON
    cmake --build build
    sudo cmake --install build
    echo "$QS_BUILD_ID" > "$QS_BUILD_MARKER"
    cd "$SCRIPT_DIR"
    log "QuickShell built and installed."
else
    log "QuickShell already at pinned ${QS_PIN:0:12}."
fi

log "Installing grimblast (single script from hyprwm/contrib, AUR-only otherwise)..."
mkdir -p "$HOME/.local/bin"
curl -fsSL "https://raw.githubusercontent.com/hyprwm/contrib/$(source_get contrib pin)/grimblast/grimblast" \
    -o "$HOME/.local/bin/grimblast"
chmod +x "$HOME/.local/bin/grimblast"

XPADNEO_SRC_DIR="$HOME/.local/src/xpadneo"
XPADNEO_BUILD_MARKER="$XPADNEO_SRC_DIR/.last-built-commit"
XPADNEO_PIN="$(source_get xpadneo pin)"
# capture first: grep -q on a pipe under pipefail, see 04-fonts.sh
dkms_modules="$(sudo dkms status)"
if grep -q '^hid-xpadneo' <<<"$dkms_modules" && [[ "$(cat "$XPADNEO_BUILD_MARKER" 2>/dev/null)" == "$XPADNEO_PIN" ]]; then
    log "xpadneo DKMS module already at pinned ${XPADNEO_PIN:0:12}."
else
    if grep -q '^hid-xpadneo' <<<"$dkms_modules"; then
        log "Removing old xpadneo DKMS module before installing ${XPADNEO_PIN:0:12}..."
        (cd "$XPADNEO_SRC_DIR" && sudo ./uninstall.sh) || err "xpadneo uninstall.sh failed or not present; attempting install over existing module."
    fi
    source_checkout xpadneo "$XPADNEO_SRC_DIR" --with-tags
    log "Installing xpadneo (Xbox controller DKMS driver, AUR-only otherwise) via its own install script..."
    (cd "$XPADNEO_SRC_DIR" && sudo ./install.sh)
    echo "$XPADNEO_PIN" > "$XPADNEO_BUILD_MARKER"
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
        # shellcheck source=/dev/null  # one of scripts/lib/builds/*.sh
        source "$profile_build_script"
        "run_${profile}_builds"
    fi
done

log "Build-from-source stage complete."
