#!/usr/bin/env bash
# generate-thunar-css.sh
# Reads ~/.config/hypr/theme.json, substitutes tokens in the
# gtk-template.css, writes the result to ~/.config/gtk-3.0/gtk.css.
set -euo pipefail

THEME_JSON="$HOME/.config/hypr/theme.json"
TEMPLATE="$HOME/.config/gtk-3.0/gtk-template.css"
OUTPUT="$HOME/.config/gtk-3.0/gtk.css"

if [[ ! -f "$THEME_JSON" ]]; then
  echo "generate-thunar-css.sh: $THEME_JSON not found" >&2
  exit 1
fi
if [[ ! -f "$TEMPLATE" ]]; then
  echo "generate-thunar-css.sh: $TEMPLATE not found" >&2
  exit 1
fi

mapfile -t pairs < <(jq -r '
  paths(scalars) as $p | "\($p | join(".")) = \(getpath($p))"
' "$THEME_JSON")

tmp="$(mktemp)"
cp "$TEMPLATE" "$tmp"

for line in "${pairs[@]}"; do
  key="${line%% = *}"
  val="${line#* = }"
  flat_key="${key//./_}"
  flat_key="${flat_key#colors_}"
  sed -i "s|{{${flat_key}}}|${val}|g" "$tmp"
done

mv "$tmp" "$OUTPUT"
echo "generate-thunar-css.sh: wrote $OUTPUT"
