#!/usr/bin/env bash
# profiles.sh - which package profiles (packages/profiles/*.txt) are active on
# this machine. Sourced by install.sh, update.sh and tools/sync-packages.sh;
# needs common.sh. Sourced, not executed directly.
#
# Every profile is on unless skipped. A machine's selection is recorded in
# hosts/<hostname>.conf ("skip=a,b"), written whenever --skip/--only is given,
# so later runs (plain ./update.sh) need no flags and a reinstall of the same
# machine gets the same selection back. Commit the file.

PROFILES_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOST_CONF="$PROFILES_REPO/hosts/$(uname -n).conf"

all_profiles() {
    local f
    for f in "$PROFILES_REPO"/packages/profiles/*.txt; do
        basename "$f" .txt
    done
}

profile_usage() {
    cat <<USAGE
Profiles (all installed unless skipped; base.txt always installs):
  $(all_profiles | paste -sd' ')

  --skip a,b    everything except a and b   (--skip all: base only)
  --only a,b    just a and b                (--skip none: everything)

Either flag is recorded in hosts/<hostname>.conf, so later runs on this
machine need no flags. Without either, that file is used if it exists.
USAGE
}

# Comma list -> one valid profile name per line. "all"/"none" expand.
# Exits on an unknown name; call it directly, not inside $(...), so that
# exit actually stops the script.
PROFILE_LIST=()
expand_profiles() {
    local csv="$1" p known
    known="$(all_profiles)"
    PROFILE_LIST=()
    case "$csv" in
        all) mapfile -t PROFILE_LIST <<<"$known"; return ;;
        none|"") return ;;
    esac
    for p in ${csv//,/ }; do
        if ! grep -qxF "$p" <<<"$known"; then
            err "Unknown profile '$p'. Profiles: $(paste -sd' ' <<<"$known")"
            exit 1
        fi
        PROFILE_LIST+=("$p")
    done
}

# resolve_profiles [--skip csv | --only csv]
# Exports CAS_PROFILES (space-separated active profiles). With a flag, the
# selection is written to the host file; without, the host file is read.
resolve_profiles() {
    local mode="${1:-}" csv="${2:-}" skip=() p
    case "$mode" in
        --skip)
            expand_profiles "$csv"
            skip=("${PROFILE_LIST[@]}")
            ;;
        --only)
            expand_profiles "$csv"
            for p in $(all_profiles); do
                [[ " ${PROFILE_LIST[*]} " == *" $p "* ]] || skip+=("$p")
            done
            ;;
        "")
            if [[ -f "$HOST_CONF" ]]; then
                csv="$(sed -n 's/^skip=//p' "$HOST_CONF" | tail -1)"
                # Tolerate names of profiles deleted from the repo since
                for p in ${csv//,/ }; do
                    if [[ -f "$PROFILES_REPO/packages/profiles/$p.txt" ]]; then
                        skip+=("$p")
                    else
                        log "Ignoring unknown profile '$p' in ${HOST_CONF#"$PROFILES_REPO"/}"
                    fi
                done
                log "Profile selection from ${HOST_CONF#"$PROFILES_REPO"/}"
            fi
            ;;
    esac

    if [[ -n "$mode" ]]; then
        mkdir -p "$(dirname "$HOST_CONF")"
        cat > "$HOST_CONF" <<EOF
# Package profiles NOT installed on $(uname -n). Written by install.sh /
# update.sh --skip/--only; edit by hand or rerun with new flags. Commit it.
skip=$(IFS=,; echo "${skip[*]}")
EOF
        log "Recorded profile selection in ${HOST_CONF#"$PROFILES_REPO"/}"
    fi

    local active=()
    for p in $(all_profiles); do
        [[ " ${skip[*]} " == *" $p "* ]] || active+=("$p")
    done
    export CAS_PROFILES="${active[*]}"
    log "Active profiles: ${CAS_PROFILES:-none (base only)}"
    if [[ ${#skip[@]} -gt 0 ]]; then
        log "Skipped profiles: ${skip[*]}"
    fi
}
