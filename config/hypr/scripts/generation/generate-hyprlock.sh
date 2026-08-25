#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../../hyprlock.conf.template"
OUT="$HOME/.config/hypr/hyprlock.conf"

# --------------------------------------------------------------
# Every value below is a PERCENT of half the screen dimension,
# measured from center (matches halign/valign = center in the
# template). Positive X = right, positive Y = up. Tune these once
# for your layout; they then hold on any monitor/resolution because
# actual pixel offsets are recomputed here on every run.
#
# Reverse-engineered from the old hardcoded values (1275,120 etc),
# which only make sense against a screen with a half-width close to
# 1280px (i.e. ~2560px wide). Confirm these render where you expect
# on prometheus, then adjust the percentages, not hyprlock.conf.
# --------------------------------------------------------------
CLOCK_X_PCT=99.6;   CLOCK_Y_PCT=16.7
DATE_X_PCT=99.6;    DATE_Y_PCT=5.6
INPUT_X_PCT=99.6;   INPUT_Y_PCT=-5.6
FAIL_X_PCT=99.6;    FAIL_Y_PCT=-15.6
FOOTER_X_PCT=99.6;  FOOTER_Y_PCT=-22.2

# Focused monitor's logical (post-scale) resolution via hyprctl.
mon_json=$(hyprctl monitors -j | python3 -c '
import json,sys
mons = json.load(sys.stdin)
m = next((m for m in mons if m.get("focused")), mons[0])
w = m["width"] / m["scale"]
h = m["height"] / m["scale"]
print(f"{w} {h}")
')
read -r width height <<< "$mon_json"

half_w=$(echo "$width / 2" | bc -l)
half_h=$(echo "$height / 2" | bc -l)

px() { # px <pct> <half_dim>
    printf "%.0f" "$(echo "$1 * $2 / 100" | bc -l)"
}

CLOCK_X=$(px "$CLOCK_X_PCT" "$half_w");   CLOCK_Y=$(px "$CLOCK_Y_PCT" "$half_h")
DATE_X=$(px "$DATE_X_PCT" "$half_w");     DATE_Y=$(px "$DATE_Y_PCT" "$half_h")
INPUT_X=$(px "$INPUT_X_PCT" "$half_w");   INPUT_Y=$(px "$INPUT_Y_PCT" "$half_h")
FAIL_X=$(px "$FAIL_X_PCT" "$half_w");     FAIL_Y=$(px "$FAIL_Y_PCT" "$half_h")
FOOTER_X=$(px "$FOOTER_X_PCT" "$half_w"); FOOTER_Y=$(px "$FOOTER_Y_PCT" "$half_h")

sed \
  -e "s/__CLOCK_X__/${CLOCK_X}/"   -e "s/__CLOCK_Y__/${CLOCK_Y}/" \
  -e "s/__DATE_X__/${DATE_X}/"     -e "s/__DATE_Y__/${DATE_Y}/" \
  -e "s/__INPUT_X__/${INPUT_X}/"   -e "s/__INPUT_Y__/${INPUT_Y}/" \
  -e "s/__FAIL_X__/${FAIL_X}/"     -e "s/__FAIL_Y__/${FAIL_Y}/" \
  -e "s/__FOOTER_X__/${FOOTER_X}/" -e "s/__FOOTER_Y__/${FOOTER_Y}/" \
  "$TEMPLATE" > "$OUT"

echo "[generate-hyprlock] wrote $OUT for ${width%.*}x${height%.*}"
chmod +x ~/camarena-arch-setup/config/hypr/scripts/generation/generate-hyprlock.sh
