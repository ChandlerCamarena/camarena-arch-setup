#!/usr/bin/env bash
cliphist list \
  | sed 's/\([0-9]*\)\t\(.*\)/<span foreground="#e8505b">\1<\/span>  <span foreground="#9b6eb5">│<\/span>  <span foreground="#c8cae8">\2<\/span>/' \
  | rofi -dmenu \
         -markup-rows \
         -theme ~/.config/rofi/launchers/type-1/style-2.rasi \
         -kb-row-down "j,Down" \
         -kb-row-up "k,Up" \
         -p "clipboard" \
  | sed 's/<[^>]*>//g' \
  | awk '{print $1}' \
  | cliphist decode \
  | wl-copy
