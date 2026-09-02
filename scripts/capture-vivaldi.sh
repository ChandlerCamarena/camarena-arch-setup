#!/usr/bin/env bash
# capture-vivaldi.sh - manual tool, NOT run by install.sh.
# Run this by hand whenever you want the repo's tracked Vivaldi config
# to reflect your current live browser tuning. Overwrites
# config/vivaldi/{Preferences,Bookmarks} in the repo working tree --
# review the diff and commit deliberately, don't blind-commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

VIVALDI_PROFILE="$HOME/.config/vivaldi/Default"
DEST="$SCRIPT_DIR/../config/vivaldi"

if [[ ! -f "$VIVALDI_PROFILE/Preferences" ]]; then
    err "No live Vivaldi Preferences found at $VIVALDI_PROFILE/Preferences"
    exit 1
fi

mkdir -p "$DEST"

log "Stripping protection.macs (device-specific, breaks portability) from Preferences..."
python3 -c "
import json
with open('$VIVALDI_PROFILE/Preferences') as f:
    prefs = json.load(f)
prefs.pop('protection', None)
with open('$DEST/Preferences', 'w') as f:
    json.dump(prefs, f, indent=2)
"
log "Wrote $DEST/Preferences"

if [[ -f "$VIVALDI_PROFILE/Bookmarks" ]]; then
    cp "$VIVALDI_PROFILE/Bookmarks" "$DEST/Bookmarks"
    log "Wrote $DEST/Bookmarks"
else
    log "No Bookmarks file found, skipping."
fi

log "Capture complete. Review the diff in config/vivaldi/ before committing."
log "Extension IDs are NOT auto-captured -- edit config/vivaldi/extensions.txt by hand."
log "Reminder: config/vivaldi/Preferences may still contain personal data (search history"
log "entries, saved form data references, etc). Review before pushing to a public repo."
