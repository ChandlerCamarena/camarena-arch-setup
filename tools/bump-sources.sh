#!/usr/bin/env bash
# bump-sources.sh - move packages/sources.txt pins to upstream's latest, but
# only the ones that still pass the full VM pipeline (tools/vm/vm.sh test).
#
#   tools/bump-sources.sh            check, test, keep what passes
#   tools/bump-sources.sh --check    just list what's newer upstream
#
# Exit: 0 all kept (or nothing new), 1 some/all latest versions fail,
# 2 the pipeline fails even at the current pins (results meaningless)
#
# All newer pins are tried together first. If that fails, each is tried on
# its own, the passing ones are kept (and re-tested together), the failing
# ones stay at their old pin, and you get a desktop notification naming them:
# their latest version breaks something here and needs a fix in this repo.
#
# Kept bumps land in the working tree; commit packages/sources.txt and the
# next update.sh builds them. The VM tests the working tree as-is, so other
# uncommitted changes are part of the test too.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"
source "$REPO_ROOT/scripts/lib/sources.sh"
require_not_root

VM="$REPO_ROOT/tools/vm/vm.sh"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/camarena-arch-setup/bump"
mkdir -p "$LOG_DIR"
# Markdown summary of the run; CI (.github/workflows/bump-sources.yml) uses it
# as the pull request / issue body
SUMMARY="$LOG_DIR/summary.md"
: > "$SUMMARY"

check_only=0
case "${1:-}" in
    "") ;;
    --check) check_only=1 ;;
    *) err "usage: $0 [--check]"; exit 1 ;;
esac

notify() {
    log "$1: $2"
    if command_exists notify-send; then
        notify-send --app-name=camarena-arch-setup "$1" "$2" || true
    fi
}

# --- what's newer ----------------------------------------------------------
declare -A new_pin=()
changed=()
for name in $(source_names); do
    old="$(source_get "$name" pin)"
    if ! latest="$(source_latest "$name")" || [[ -z "$latest" || "$latest" == null ]]; then
        err "Couldn't look up the latest $name, leaving it alone."
        continue
    fi
    if [[ "$latest" != "$old" ]]; then
        new_pin[$name]="$latest"
        changed+=("$name")
        log "$name: ${old:0:12} -> ${latest:0:12}"
        echo "- \`$name\`: \`${old:0:12}\` → \`${latest:0:12}\`" >> "$SUMMARY"
    fi
done

if [[ ${#changed[@]} -eq 0 ]]; then
    log "All sources are at upstream's latest."
    exit 0
fi
[[ $check_only -eq 1 ]] && exit 0

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    log "Note: the working tree has uncommitted changes; they're part of the test."
fi

ORIG="$(mktemp)"
cp "$SOURCES_FILE" "$ORIG"
# Whatever happens (failure, Ctrl+C), never leave half-applied pins behind
# unless they were deliberately kept below
KEEP=0
trap '[[ $KEEP -eq 1 ]] || cp "$ORIG" "$SOURCES_FILE"; rm -f "$ORIG"' EXIT

# try <label> <name...>: pin those names to latest (others at their old
# pin), run the full pipeline, return its result
try() {
    local label="$1" n log_file
    shift
    cp "$ORIG" "$SOURCES_FILE"
    for n in "$@"; do
        source_set_pin "$n" "${new_pin[$n]}"
    done
    log_file="$LOG_DIR/$label.log"
    log "Testing latest $* (log: $log_file)..."
    "$VM" stop >/dev/null 2>&1 || true
    if "$VM" test >"$log_file" 2>&1; then
        log "  PASS"
        return 0
    fi
    log "  FAIL"
    return 1
}

# Nothing passed: is it the bumps, or is the pipeline itself broken (KVM,
# disk space, a mirror outage, or a bug already at the current pins)?
pipeline_broken() {
    if try current; then
        return 1
    fi
    printf '\n**The VM pipeline fails even at the current pins**, so these results say nothing about the bumps. See `current.log` in the run artifacts.\n' >> "$SUMMARY"
    notify "Source update: pipeline broken" "The VM test fails even at the current pins; fix that first. Log: $LOG_DIR/current.log"
    return 0
}

# --- all together ----------------------------------------------------------
if try all "${changed[@]}"; then
    KEEP=1
    printf '\nAll of these pass the full VM pipeline together.\n' >> "$SUMMARY"
    notify "Sources updated" "Latest passes the VM test: ${changed[*]}. Commit packages/sources.txt."
    exit 0
fi

if [[ ${#changed[@]} -eq 1 ]]; then
    pipeline_broken && exit 2
    printf '\n**Latest fails the VM pipeline, pin kept:** %s. See `all.log` in the run artifacts.\n' "${changed[0]}" >> "$SUMMARY"
    notify "Source update failed" "Latest ${changed[0]} fails the VM test, pin kept. Make the repo work with it. Log: $LOG_DIR/all.log"
    exit 1
fi

# --- one at a time ---------------------------------------------------------
passing=() failing=()
for name in "${changed[@]}"; do
    if try "$name" "$name"; then passing+=("$name"); else failing+=("$name"); fi
done

if [[ ${#passing[@]} -gt 0 ]] && try passing "${passing[@]}"; then
    KEEP=1
else
    # Individually fine but failing together (or a flaky re-test): keep none
    if [[ ${#passing[@]} -gt 0 ]]; then
        log "Individually passing bumps fail together; keeping none."
        failing+=("${passing[@]}")
        passing=()
    elif pipeline_broken; then
        exit 2
    fi
fi

{
    echo
    [[ ${#passing[@]} -gt 0 ]] && echo "**Pass the VM pipeline, pins updated:** ${passing[*]}"
    echo "**Latest fails the VM pipeline, pins kept:** ${failing[*]}"
    echo
    echo "These need a change in this repo before they can move to latest. Per-source logs: \`<name>.log\` in the run's artifacts."
} >> "$SUMMARY"

msg=""
[[ ${#passing[@]} -gt 0 ]] && msg+="Updated: ${passing[*]} (commit packages/sources.txt). "
msg+="Still pinned, latest breaks the VM test: ${failing[*]}. Logs: $LOG_DIR/<name>.log"
notify "Source update: some failed" "$msg"
exit 1
