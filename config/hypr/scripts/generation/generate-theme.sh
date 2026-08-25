#!/usr/bin/env bash
# generate-theme.sh
# Reads ~/.config/hypr/theme.json (single source of truth) and emits
# ~/.config/yazi/theme.toml. Yazi has no live-reload and no scripting
# in theme.toml itself (unlike theme.lua's jq-loader pattern for
# Hyprland), so this runs once per theme change, not per Yazi launch.
set -euo pipefail

THEME_JSON="$HOME/.config/hypr/theme.json"
OUT="$HOME/.config/yazi/theme.toml"

# Pull each field once, fail loudly if theme.json is missing/malformed
# rather than silently falling back -- unlike theme.lua's DEFAULTS
# table, there's no equivalent "keep Hyprland alive at all costs"
# requirement for a file manager theme.
jget() { jq -r "$1" "$THEME_JSON"; }

bg=$(jget '.colors.bg')
bg_surface=$(jget '.colors.bg_surface')
bg_float=$(jget '.colors.bg_float')
coral=$(jget '.colors.coral')
coral_dim=$(jget '.colors.coral_dim')
purple=$(jget '.colors.purple')
cyan=$(jget '.colors.cyan')
cyan_dim=$(jget '.colors.cyan_dim')
error=$(jget '.colors.error')
warning=$(jget '.colors.warning')
fg=$(jget '.colors.fg')
fg_dim=$(jget '.colors.fg_dim')
fg_subtle=$(jget '.colors.fg_subtle')

cat > "$OUT" << TOML
# Auto-generated from ~/.config/hypr/theme.json by generate-theme.sh
# Do not hand-edit -- changes will be overwritten on next theme switch.

[manager]
cwd = { fg = "#${cyan}" }

hovered         = { fg = "#${bg}", bg = "#${coral}" }
preview_hovered = { underline = true }

find_keyword  = { fg = "#${warning}", italic = true }
find_position = { fg = "#${purple}", bg = "reset", italic = true }

marker_copied   = { fg = "#${cyan}",  bg = "#${cyan}" }
marker_cut      = { fg = "#${error}", bg = "#${error}" }
marker_marked   = { fg = "#${coral}", bg = "#${coral}" }
marker_selected = { fg = "#${warning}", bg = "#${warning}" }

tab_active   = { fg = "#${bg}", bg = "#${coral}" }
tab_inactive = { fg = "#${fg_dim}", bg = "#${bg_surface}" }

count_copied   = { fg = "#${bg}", bg = "#${cyan}" }
count_cut      = { fg = "#${bg}", bg = "#${error}" }
count_selected = { fg = "#${bg}", bg = "#${warning}" }

border_symbol = "│"
border_style  = { fg = "#${fg_subtle}" }

syntect_theme = ""

[status]
separator_open  = ""
separator_close = ""
separator_style = { fg = "#${bg_surface}", bg = "#${bg_surface}" }

primary_fg = "#${fg}"
primary_bg = "#${bg_surface}"

success_fg = "#${cyan}"
success_bg = "#${bg_surface}"

failure_fg = "#${error}"
failure_bg = "#${bg_surface}"

body_fg = "#${fg}"

perm_type  = { fg = "#${purple}" }
perm_read  = { fg = "#${cyan}" }
perm_write = { fg = "#${warning}" }
perm_exec  = { fg = "#${coral}" }
perm_sep   = { fg = "#${fg_subtle}" }

progress_label  = { bold = true }
progress_normal = { fg = "#${cyan}", bg = "#${bg_surface}" }
progress_error  = { fg = "#${error}", bg = "#${bg_surface}" }

[select]
active   = { fg = "#${coral}" }
inactive = {}

[input]
border   = { fg = "#${coral}" }
title    = {}
value    = {}
selected = { reversed = true }

[tasks]
border = { fg = "#${coral}" }
title  = {}
hovered = { underline = true }

[which]
mask            = { bg = "#${bg_float}" }
cand            = { fg = "#${cyan}" }
rest            = { fg = "#${fg_dim}" }
desc            = { fg = "#${purple}" }
separator       = "  "
separator_style = { fg = "#${fg_subtle}" }

[help]
on      = { fg = "#${coral}" }
run     = { fg = "#${cyan}" }
desc    = { fg = "#${fg_dim}" }
hovered = { bg = "#${bg_surface}", bold = true }
footer  = { fg = "#${fg_dim}", bg = "#${bg_surface}" }

[confirm]
border  = { fg = "#${coral}" }
title   = { fg = "#${coral}" }
content = {}
list    = {}
btn_yes = { fg = "#${bg}", bg = "#${cyan}" }
btn_no  = { fg = "#${fg}", bg = "#${bg_surface}" }
TOML

echo "wrote $OUT"
