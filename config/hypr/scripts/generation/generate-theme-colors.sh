#!/usr/bin/env bash
set -euo pipefail
THEME="$HOME/.config/hypr/theme.json"
OUT="$HOME/.config/nvim/lua/theme-colors.lua"

c() { jq -r ".colors.$1" "$THEME"; }

cat > "$OUT" << INNEREOF
-- Generated from theme.json by generate-theme-colors.sh. Do not edit by hand.
return {
  bg          = "#$(c bg_dark)",
  bg_float    = "#$(c bg_float)",
  bg_highlight= "#$(c bg_surface)",
  fg          = "#$(c fg)",
  fg_dim      = "#$(c fg_dim)",
  fg_subtle   = "#$(c fg_subtle)",
  coral       = "#$(c coral)",
  purple      = "#$(c purple)",
  cyan        = "#$(c cyan)",
  warning     = "#$(c warning)",
  error       = "#$(c error)",
}
INNEREOF
