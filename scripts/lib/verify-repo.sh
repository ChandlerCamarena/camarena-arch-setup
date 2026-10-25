#!/usr/bin/env bash
# verify-repo.sh - repo-level sanity checks, NOT part of install.sh.
# Run manually or via the pre-commit hook before committing.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
fail=0
log()   { echo "[verify-repo] $*"; }
error() { echo "[verify-repo] ERROR: $*" >&2; fail=1; }
warn()  { echo "[verify-repo] WARN:  $*" >&2; }

DOTFILES_SCRIPT="$(ls scripts/*-dotfiles-copy.sh 2>/dev/null | head -1)"
if [[ -z "$DOTFILES_SCRIPT" ]]; then
    error "no scripts/*-dotfiles-copy.sh found"
else
    log "Checking every copy_plain source in $DOTFILES_SCRIPT actually exists..."
    missing=0
    while read -r p; do
        if [[ ! -e "config/$p" ]]; then
            error "missing config/$p (referenced by $DOTFILES_SCRIPT)"
            missing=1
        fi
    done < <(grep -oP '(?<=copy_plain "\$CONFIG_SRC/)[^"$]+(?=")' "$DOTFILES_SCRIPT")
    # Whole directories copied in a loop: CONFIG_DIRS=(a b c)
    for d in $(grep -oP '(?<=^CONFIG_DIRS=\()[^)]+' "$DOTFILES_SCRIPT"); do
        if [[ ! -d "config/$d" ]]; then
            error "missing config/$d/ (CONFIG_DIRS in $DOTFILES_SCRIPT)"
            missing=1
        fi
    done
    [[ "$missing" -eq 0 ]] && log "  all copy_plain sources present."
fi

log "Checking every listed package exists in the official repos (no AUR)..."
if command -v pacman &>/dev/null; then
    # Names from the local sync databases (core, extra, multilib if enabled);
    # anything else is AUR, a typo, or a package that was dropped upstream.
    official="$(pacman -Slq)"
    unknown=0
    for pkglist in packages/base.txt packages/profiles/*.txt; do
        while read -r pkg; do
            if ! grep -qxF "$pkg" <<<"$official"; then
                error "$pkg ($pkglist) is not in any official repo (AUR? typo? multilib not enabled?)"
                unknown=1
            fi
        done < <(grep -vE '^\s*#|^\s*$' "$pkglist")
    done
    [[ "$unknown" -eq 0 ]] && log "  all listed packages are official."
else
    warn "pacman not available, skipping official-repo check."
fi

log "Checking hosts/*.conf only name existing profiles..."
for conf in hosts/*.conf; do
    [[ -f "$conf" ]] || continue
    for p in $(sed -n 's/^skip=//p' "$conf" | tr ',' ' '); do
        [[ -f "packages/profiles/$p.txt" ]] || error "$conf skips '$p', but packages/profiles/$p.txt doesn't exist"
    done
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
