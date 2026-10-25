#!/usr/bin/env bash
# sources.sh - pinned non-pacman sources (packages/sources.txt). Sourced by the
# stages and build scripts that fetch from git/GitHub, and by
# tools/bump-sources.sh. Needs common.sh. Sourced, not executed directly.

SOURCES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/packages/sources.txt"

# source_get <name> <field>: field is type, url, track or pin
source_get() {
    local name="$1" field="$2" col
    case "$field" in
        type) col=2 ;; url) col=3 ;; track) col=4 ;; pin) col=5 ;;
        *) err "source_get: unknown field $field"; return 1 ;;
    esac
    local value
    value="$(awk -v n="$name" -v c="$col" '!/^[[:space:]]*#/ && $1 == n { print $c; exit }' "$SOURCES_FILE")"
    if [[ -z "$value" ]]; then
        err "No '$name' in $SOURCES_FILE"
        return 1
    fi
    echo "$value"
}

source_names() {
    awk '!/^[[:space:]]*#/ && NF >= 5 { print $1 }' "$SOURCES_FILE"
}

# source_checkout <name> <dir> [--with-tags]: <dir> ends up at exactly the
# pinned commit (detached). Fetches just that commit, shallow, so huge
# histories (metasploit) stay small; works in an existing full clone too.
# --with-tags fetches full history and tags instead, for build scripts that
# version themselves with `git describe --tags` (xpadneo).
source_checkout() {
    local name="$1" dir="$2" with_tags="${3:-}" url pin
    url="$(source_get "$name" url)"
    pin="$(source_get "$name" pin)"
    if [[ ! -d "$dir/.git" ]]; then
        mkdir -p "$dir"
        git -C "$dir" init --quiet
        git -C "$dir" remote add origin "$url"
    fi
    if [[ "$with_tags" == --with-tags ]]; then
        if ! git -C "$dir" describe --tags "$pin" &>/dev/null; then
            log "Fetching $name @ ${pin:0:12} with history and tags..."
            if [[ "$(git -C "$dir" rev-parse --is-shallow-repository)" == true ]]; then
                git -C "$dir" fetch --quiet --tags --unshallow origin
            else
                git -C "$dir" fetch --quiet --tags origin
            fi
        fi
    elif ! git -C "$dir" cat-file -e "$pin^{commit}" 2>/dev/null; then
        log "Fetching $name @ ${pin:0:12}..."
        git -C "$dir" fetch --quiet --depth 1 origin "$pin"
    fi
    git -C "$dir" -c advice.detachedHead=false checkout --quiet --force "$pin"
}

# source_latest <name>: upstream's newest commit on the tracked branch, or
# newest release tag
source_latest() {
    local name="$1" type url track repo
    type="$(source_get "$name" type)"
    url="$(source_get "$name" url)"
    track="$(source_get "$name" track)"
    case "$type" in
        git)
            git ls-remote "$url" "refs/heads/$track" | cut -f1
            ;;
        release)
            repo="${url#https://github.com/}"
            curl -fsSL "https://api.github.com/repos/${repo%.git}/releases/latest" | jq -r .tag_name
            ;;
        *)
            err "Unknown source type '$type' for $name"
            return 1
            ;;
    esac
}

# source_set_pin <name> <pin>: rewrite that entry's pin column in place
source_set_pin() {
    local name="$1" pin="$2" tmp
    tmp="$(mktemp)"
    awk -v n="$name" -v p="$pin" '
        !/^[[:space:]]*#/ && $1 == n { sub(/[^[:space:]]+[[:space:]]*$/, p) }
        { print }
    ' "$SOURCES_FILE" > "$tmp"
    cat "$tmp" > "$SOURCES_FILE"
    rm -f "$tmp"
}
