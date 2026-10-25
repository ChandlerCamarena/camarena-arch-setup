#!/usr/bin/env bash
# switch.sh - make ~/.config/rices/<name> the active rice.
#
#   switch.sh <name>               switch and reload the running session
#   switch.sh --no-reload <name>   relink + regenerate only (install/update)
#
# Every consumer reads ~/.config/hypr/theme.json and
# ~/.config/hypr/wallpapers/wallpaper.png, so switching is: repoint
# those two symlinks, rerun the generators, run the rice's optional
# apply.sh, then poke whatever's already running.
set -euo pipefail

RICES="$HOME/.config/rices"
HYPR="$HOME/.config/hypr"
GEN="$HYPR/scripts/generation"

log() { echo "[switch] $*"; }
die() { echo "[switch] ERROR: $*" >&2; exit 1; }

reload=1
if [[ "${1:-}" == "--no-reload" ]]; then
    reload=0
    shift
fi
name="${1:-}"

if [[ -z "$name" ]]; then
    echo "Usage: $0 [--no-reload] <rice>" >&2
    rices=()
    for d in "$RICES"/*/theme.json; do
        [[ -f "$d" ]] && rices+=("$(basename "$(dirname "$d")")")
    done
    echo "Rices: ${rices[*]:-none}" >&2
    exit 1
fi

rice="$RICES/$name"
[[ -f "$rice/theme.json" ]]    || die "$rice/theme.json not found"
[[ -f "$rice/wallpaper.png" ]] || die "$rice/wallpaper.png not found"
jq empty "$rice/theme.json"    || die "$rice/theme.json is not valid JSON"

mkdir -p "$HYPR/wallpapers"
ln -sfn "$rice/theme.json"    "$HYPR/theme.json"
ln -sfn "$rice/wallpaper.png" "$HYPR/wallpapers/wallpaper.png"
echo "$name" > "$RICES/.active"
log "Active rice: $name"

for g in yazi kitty nvim gtk rofi; do
    bash "$GEN/generate-$g.sh"
done

if [[ -x "$rice/apply.sh" ]]; then
    log "Running $name/apply.sh..."
    "$rice/apply.sh"
fi

(( reload )) || exit 0

if hyprctl version &>/dev/null; then
    bash "$GEN/generate-hyprlock.sh" >/tmp/generate-hyprlock.log 2>&1 || true
    hyprctl reload >/dev/null
    # Same path, new symlink target: hyprpaper won't notice without a restart.
    # setsid so it outlives this script (and Quickshell, if it launched us).
    pkill -x hyprpaper || true
    setsid -f hyprpaper >/dev/null 2>&1
fi

# Quickshell's file watcher is pinned to the old symlink target.
qs ipc call theme reload >/dev/null 2>&1 || true

# SIGUSR1 makes kitty reload kitty.conf, which includes colors-generated.conf.
pkill -USR1 -x kitty || true

if command -v rgb &>/dev/null; then
    rgb apply >/dev/null 2>&1 || true
fi

# SDDM keeps its own root-owned copy. Only refreshed if sudo needs no
# password; otherwise the next update.sh picks it up.
SDDM_THEME="/usr/share/sddm/themes/retrowave"
if [[ -d "$SDDM_THEME" ]] && sudo -n true 2>/dev/null; then
    sudo cp "$rice/theme.json"    "$SDDM_THEME/theme.json"
    sudo cp "$rice/wallpaper.png" "$SDDM_THEME/wallpaper.png"
fi

log "Done."
