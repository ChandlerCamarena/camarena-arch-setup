#!/usr/bin/env bash
# Row colors read from theme.json at launch, so they follow rice switches
THEME="$HOME/.config/hypr/theme.json"
c() { jq -r ".colors.$1" "$THEME"; }
ID="$(c coral)" SEP="$(c purple)" TXT="$(c fg)"

sel="$(cliphist list \
  | sed "s/\([0-9]*\)\t\(.*\)/<span foreground=\"#$ID\">\1<\/span>  <span foreground=\"#$SEP\">│<\/span>  <span foreground=\"#$TXT\">\2<\/span>/" \
  | rofi -dmenu \
         -markup-rows \
         -theme ~/.config/rofi/launchers/type-1/style-2.rasi \
         -kb-row-down "j,Down" \
         -kb-row-up "k,Up" \
         -p "clipboard")" || exit 0   # Esc: leave the clipboard alone

id="$(printf '%s' "$sel" | sed 's/<[^>]*>//g' | awk '{print $1; exit}')"
[[ "$id" =~ ^[0-9]+$ ]] || exit 0

# cliphist 0.7 parses the id up to a tab ("<id>\t<preview>", like `cliphist list`);
# a bare "<id>\n" fails with strconv.Atoi and wl-copy got an empty clipboard
printf '%s\t\n' "$id" | cliphist decode | wl-copy
