#!/usr/bin/env bash
# verify-repo.sh - repo-level sanity checks, NOT part of install.sh.
# Run manually or via the pre-commit hook before committing.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

fail=0
log()   { echo "[verify-repo] $*"; }
error() { echo "[verify-repo] ERROR: $*" >&2; fail=1; }
warn()  { echo "[verify-repo] WARN:  $*" >&2; }

log "Checking every copy_plain source in 06-dotfiles-copy.sh actually exists..."
missing=0
while read -r p; do
    if [[ ! -e "config/$p" ]]; then
        error "missing config/$p (referenced by 06-dotfiles-copy.sh)"
        missing=1
    fi
done < <(grep -oP '(?<=copy_plain "\$CONFIG_SRC/)[^"]+' scripts/06-dotfiles-copy.sh)
[[ "$missing" -eq 0 ]] && log "  all copy_plain sources present."

log "Checking package lists for AUR-suspicious naming (-bin/-git/-dkms)..."
for pkglist in packages/pacman-packages.txt packages/vulkan-datum-packages.txt; do
    [[ -f "$pkglist" ]] || continue
    while read -r pkg; do
        case "$pkg" in
            *-bin|*-git|*-dkms)
                warn "$pkg in $pkglist looks AUR-suspicious — confirm it's actually in an official repo"
                ;;
        esac
    done < <(grep -vE '^\s*#|^\s*$' "$pkglist")
done

log "Checking README stage range matches the actual scripts/ directory..."
highest="$(basename "$(ls scripts/0*.sh 2>/dev/null | sort | tail -1)" 2>/dev/null | cut -c1-2)"
if [[ -n "$highest" ]]; then
    if ! grep -q "\`00\`–\`${highest}\`" README.md; then
        error "README doesn't say \`00\`-\`${highest}\` — highest actual stage is ${highest}, Structure section is stale"
    else
        log "  README stage range matches (00-${highest})."
    fi
fi

log "Checking every scripts/0*.sh is executable and has set -euo pipefail..."
for s in scripts/0*.sh; do
    [[ -x "$s" ]] || warn "$s is not executable (chmod +x)"
    head -n3 "$s" | grep -q 'set -euo pipefail' || error "$s missing 'set -euo pipefail'"
done

if [[ "$fail" -ne 0 ]]; then
    log "FAILED — fix the above before committing."
    exit 1
fi
log "All checks passed."
