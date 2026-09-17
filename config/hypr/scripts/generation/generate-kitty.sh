#!/usr/bin/env bash
set -euo pipefail
THEME="$HOME/.config/hypr/theme.json"
OUT="$HOME/.config/kitty/colors-generated.conf"

c() { jq -r ".colors.$1" "$THEME"; }

cat > "$OUT" << INNEREOF
background            #$(c bg)
foreground             #$(c fg)
cursor                 #$(c coral)
selection_background   #$(c coral)
selection_foreground   #$(c bg_dark)
color0                 #$(c bg_dark)
color8                 #$(c purple)
color1                 #$(c error)
color9                 #$(c error)
color2                 #$(c cyan)
color10                #$(c cyan)
color3                 #$(c warning)
color11                #$(c warning)
color5                 #$(c purple)
color13                #$(c purple)
color6                 #$(c cyan)
color14                #$(c cyan)
color7                 #$(c fg)
INNEREOF
