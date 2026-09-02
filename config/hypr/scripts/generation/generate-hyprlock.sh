#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../../hyprlock.conf.template"
OUT="$HOME/.config/hypr/hyprlock.conf"

# --------------------------------------------------------------
# All elements use halign = center in the template, sharing the
# same CENTER_X_PCT (percent of half_w). Since halign = center
# anchors each element's own center at position.x, giving every
# element the same x aligns their centers regardless of each
# element's rendered width.
#
# Y values are percent of half_h, measured from vertical center,
# positive = up. Tune these to change vertical spacing.
# --------------------------------------------------------------
CENTER_X_PCT=71.0

CLOCK_Y_PCT=16.7
DATE_Y_PCT=5.6
INPUT_Y_PCT=-5.6
FAIL_Y_PCT=-15.6
FOOTER_Y_PCT=-22.2

# Focused monitor's logical (post-scale) resolution via hyprctl.
# This only works with a live Hyprland session (a running
# compositor with HYPRLAND_INSTANCE_SIGNATURE set and an IPC
# socket). During install.sh's dotfiles-copy stage there is no
# session yet, so this must NOT be called from there -- call it
# from hyprland's autostart (exec-once) after the compositor is up,
# and rely on monitors.lua's monitor.added/removed hooks after that.
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || ! command -v hyprctl >/dev/null 2>&1; then
    echo "[generate-hyprlock] no live Hyprland session, falling back to 2560x1440 default" >&2
    width=2560
    height=1440
else
    raw=$(hyprctl monitors -j 2>/dev/null || true)
    if [[ -z "$raw" ]]; then
        echo "[generate-hyprlock] hyprctl monitors -j returned nothing, falling back to 2560x1440 default" >&2
        width=2560
        height=1440
    else
        mon_json=$(echo "$raw" | python3 -c '
import json,sys
mons = json.load(sys.stdin)
m = next((m for m in mons if m.get("focused")), mons[0])
w = m["width"] / m["scale"]
h = m["height"] / m["scale"]
print(f"{w} {h}")
')
        read -r width height <<< "$mon_json"
    fi
fi

half_w=$(python3 -c "print($width / 2)")
half_h=$(python3 -c "print($height / 2)")

px() { # px <pct> <half_dim>
    python3 -c "print(round($1 * $2 / 100))"
}

CENTER_X=$(px "$CENTER_X_PCT" "$half_w")

CLOCK_Y=$(px "$CLOCK_Y_PCT" "$half_h")
DATE_Y=$(px "$DATE_Y_PCT" "$half_h")
INPUT_Y=$(px "$INPUT_Y_PCT" "$half_h")
FAIL_Y=$(px "$FAIL_Y_PCT" "$half_h")
FOOTER_Y=$(px "$FOOTER_Y_PCT" "$half_h")

sed \
  -e "s/__CENTER_X__/${CENTER_X}/g" \
  -e "s/__CLOCK_Y__/${CLOCK_Y}/" \
  -e "s/__DATE_Y__/${DATE_Y}/" \
  -e "s/__INPUT_Y__/${INPUT_Y}/" \
  -e "s/__FAIL_Y__/${FAIL_Y}/" \
  -e "s/__FOOTER_Y__/${FOOTER_Y}/" \
  "$TEMPLATE" > "$OUT"

echo "[generate-hyprlock] wrote $OUT for ${width%.*}x${height%.*}"
