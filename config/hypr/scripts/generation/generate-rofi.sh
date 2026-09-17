#!/usr/bin/env bash
set -euo pipefail
THEME="$HOME/.config/hypr/theme.json"
OUT="$HOME/.config/rofi/colors/retrowave.rasi"

c() { jq -r ".colors.$1" "$THEME"; }

cat > "$OUT" << TOML
/**
 * Retrowave color scheme
 * Derived from city pop wallpaper palette.
 * Matches hyprland theme.lua
 * GENERATED FILE -- do not edit directly, edit theme.json and re-run generate-rofi.sh
 **/
* {
    background:     #$(c bg)ff;           /* bg -- deep indigo */
    background-alt: #$(c bg_surface)ff;   /* bg_surface -- raised surface */
    foreground:     #$(c fg)ff;           /* fg -- cool white */
    selected:       #$(c coral)ff;        /* coral -- primary accent */
    active:         #$(c purple)ff;       /* purple -- secondary accent */
    urgent:         #$(c error)ff;        /* hot pink -- error */
}
TOML
