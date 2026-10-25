#!/usr/bin/env bash
# make-subvolume.sh - turn an existing directory into its own btrfs subvolume,
# in place, without copying data (reflink). Snapshots never descend into
# nested subvolumes, so this is how a directory (Steam library, VM images...)
# is excluded from /home snapshots and therefore from snap-backup.
#
#   tools/make-subvolume.sh ~/.local/share/Steam
#
# Close whatever uses the directory first (Steam). Needs no extra space beyond
# metadata. The original stays as <dir>.pre-subvolume until you delete it.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib/common.sh"
require_not_root

[[ $# -eq 1 ]] || { err "usage: $0 <directory>"; exit 1; }
dir="$(realpath "$1")"
old="$dir.pre-subvolume"

[[ -d "$dir" ]] || { err "$dir is not a directory"; exit 1; }
[[ "$(stat -f -c %T "$dir")" == btrfs ]] || { err "$dir is not on btrfs"; exit 1; }
if [[ "$(stat -c %i "$dir")" == 256 ]]; then
    log "$dir is already a subvolume, nothing to do."
    exit 0
fi
[[ ! -e "$old" ]] || { err "$old already exists from an earlier run; inspect and remove it first"; exit 1; }
# system-wide open-file list filtered by path; lsof +D would walk the whole tree.
# Captured first: piped into grep -q under pipefail, lsof dies of SIGPIPE on
# the first match and the pipeline reads as "nothing open".
open_files="$(lsof -w -Fn 2>/dev/null || true)"
if grep -q "^n$dir/" <<<"$open_files"; then
    err "files in $dir are open (close Steam etc. first)"
    exit 1
fi

log "Converting $dir into a subvolume (reflink, no data copied)..."
mv "$dir" "$old"
btrfs subvolume create "$dir"
cp -a --reflink=always "$old/." "$dir/"

before="$(find "$old" | wc -l)"
after="$(find "$dir" | wc -l)"
if [[ "$before" != "$after" ]]; then
    err "entry count differs ($before vs $after); leaving both in place, check before deleting $old"
    exit 1
fi
log "Done: $after entries. Once you've checked it works, remove the original:"
log "  rm -rf '$old'"
