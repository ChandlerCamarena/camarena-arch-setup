#!/usr/bin/env bash
# sync-packages.sh - bring packages/*.txt in line with what this machine
# actually has installed. update.sh runs it before installing anything
# (otherwise update.sh would reinstall whatever you removed); it can also be
# run by hand at any time.
#
#   tools/sync-packages.sh          interactive review (needs a terminal)
#   tools/sync-packages.sh --report report only, change nothing
#
# Interactive mode asks, per package:
#   installed but in no list   -> add to base / a profile, ignore for good, or skip
#   listed but not installed   -> drop from its list, or keep (update.sh reinstalls)
# Same for Flatpak apps. Software from outside pacman/Flatpak is reported
# only, since it can't go into a package list.
#
# "Listed" for removal purposes means base.txt plus this machine's active
# profiles (hosts/<hostname>.conf, see scripts/lib/profiles.sh). Edits land in
# the repo working tree; review and commit them like any other change.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$REPO_ROOT/scripts/lib/common.sh"
require_not_root
require_arch

# update.sh exports CAS_PROFILES; run by hand, read this machine's selection
if [[ -z "${CAS_PROFILES+set}" ]]; then
    source "$REPO_ROOT/scripts/lib/profiles.sh"
    resolve_profiles
fi

PKG_DIR="$REPO_ROOT/packages"
BASE="$PKG_DIR/base.txt"
PROFILE_DIR="$PKG_DIR/profiles"
FLATPAK_LIST="$PKG_DIR/flatpak-packages.txt"
IGNORED="$PKG_DIR/ignored.txt"

interactive=1
case "${1:-}" in
    "") ;;
    --report) interactive=0 ;;
    *) err "usage: $0 [--report]"; exit 1 ;;
esac
if [[ ! -t 0 || -n "${CAS_NONINTERACTIVE:-}" ]]; then
    interactive=0
fi

changed=0

# Package names in a list file: no comments, no blanks
names() {
    [[ -f "$1" ]] && grep -vE '^\s*#|^\s*$' "$1" | awk '{print $1}' || true
}

mapfile -t PROFILES < <(for f in "$PROFILE_DIR"/*.txt; do basename "$f" .txt; done)

# Insert $2 into list $1 in sorted position among the package lines,
# leaving the header comment block alone.
list_add() {
    local file="$1" pkg="$2" tmp
    tmp="$(mktemp)"
    awk -v pkg="$pkg" '
        !done && !/^[[:space:]]*#/ && !/^[[:space:]]*$/ && $1 > pkg { print pkg; done = 1 }
        { print }
        END { if (!done) print pkg }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
    changed=1
}

# Remove package line $2 from list $1, plus its "# name - description"
# header entry and that entry's indented continuation lines.
list_remove() {
    local file="$1" pkg="$2" tmp
    tmp="$(mktemp)"
    awk -v pkg="$pkg" '
        $0 == pkg { next }
        $1 == "#" && $2 == pkg && $3 == "-" { skipping = 1; next }
        skipping && /^#[[:space:]]{6,}/ { next }
        { skipping = 0; print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
    changed=1
}

ensure_ignored_file() {
    [[ -f "$IGNORED" ]] && return
    cat > "$IGNORED" <<'EOF'
# ignored.txt
# Installed on this machine on purpose, but deliberately NOT reproduced by
# install.sh/update.sh: hardware-specific drivers, one-off experiments,
# things installed from outside the official repos. tools/sync-packages.sh
# doesn't ask about anything listed here. Pacman and Flatpak names both go here.
EOF
}

pkg_desc() {
    pacman -Qi "$1" 2>/dev/null | awk -F': ' '/^Description/ {print $2; exit}'
}

# Prompt; reads from the terminal, returns the answer in $REPLY
ask() {
    read -rp "$1 " REPLY </dev/tty
}

section() {
    echo
    echo "===== $1 ====="
}

# ---------------------------------------------------------------------------
section "PACMAN: installed, but in no package list"

all_listed="$( { names "$BASE"; for p in "${PROFILES[@]}"; do names "$PROFILE_DIR/$p.txt"; done; } | sort -u)"
ignored="$(names "$IGNORED" | sort -u)"
# pacman -Qm exits 1 when there are no foreign packages
foreign="$(pacman -Qqm || true)"

# Foreign packages are reported further down; they can't go in a list
mapfile -t untracked < <(comm -23 <(pacman -Qqe | sort -u) <(printf '%s\n%s\n%s\n' "$all_listed" "$ignored" "$foreign" | sort -u))

if [[ ${#untracked[@]} -eq 0 ]]; then
    log "None."
else
    menu="[b]ase"
    for i in "${!PROFILES[@]}"; do
        menu+="  [$((i + 1))] ${PROFILES[$i]}"
    done
    menu+="  [i]gnore  [s]kip  [q]uit"
    for pkg in "${untracked[@]}"; do
        echo "  $pkg - $(pkg_desc "$pkg")"
        [[ $interactive -eq 1 ]] || continue
        while true; do
            ask "    add to: $menu >"
            case "$REPLY" in
                b) list_add "$BASE" "$pkg"; log "    + base.txt"; break ;;
                i) ensure_ignored_file; list_add "$IGNORED" "$pkg"; log "    + ignored.txt"; break ;;
                s|"") break ;;
                q) interactive=0; break ;;
                *)
                    if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= ${#PROFILES[@]} )); then
                        p="${PROFILES[$((REPLY - 1))]}"
                        list_add "$PROFILE_DIR/$p.txt" "$pkg"
                        if [[ " ${CAS_PROFILES:-} " != *" $p "* ]]; then
                            log "    + profiles/$p.txt (not an active profile here, so update.sh won't manage it on this machine)"
                        else
                            log "    + profiles/$p.txt"
                        fi
                        break
                    fi
                    echo "    ?"
                    ;;
            esac
        done
    done
fi

# ---------------------------------------------------------------------------
section "PACMAN: in base/active profiles, but not installed"

declare -A owner=()
while read -r pkg; do owner[$pkg]="base.txt"; done < <(names "$BASE")
for p in ${CAS_PROFILES:-}; do
    while read -r pkg; do owner[$pkg]="profiles/$p.txt"; done < <(names "$PROFILE_DIR/$p.txt")
done

installed="$(pacman -Qq | sort -u)"
missing=()
for pkg in "${!owner[@]}"; do
    grep -qxF "$pkg" <<<"$installed" || missing+=("$pkg")
done

if [[ ${#missing[@]} -eq 0 ]]; then
    log "None."
else
    for pkg in $(printf '%s\n' "${missing[@]}" | sort); do
        echo "  $pkg (${owner[$pkg]})"
        [[ $interactive -eq 1 ]] || continue
        ask "    [r]emove from ${owner[$pkg]}  [k]eep (update.sh reinstalls it) >"
        if [[ "$REPLY" == r ]]; then
            list_remove "$PKG_DIR/${owner[$pkg]}" "$pkg"
            log "    - ${owner[$pkg]}"
        fi
    done
fi

# ---------------------------------------------------------------------------
if command_exists flatpak; then
    section "FLATPAK"
    apps="$(flatpak list --app --columns=application | sort -u)"
    listed_apps="$(names "$FLATPAK_LIST" | sort -u)"
    mapfile -t new_apps < <(comm -23 <(echo "$apps") <(printf '%s\n%s\n' "$listed_apps" "$ignored" | sort -u) | grep -v '^$' || true)
    mapfile -t gone_apps < <(comm -13 <(echo "$apps") <(echo "$listed_apps") | grep -v '^$' || true)
    [[ ${#new_apps[@]} -eq 0 && ${#gone_apps[@]} -eq 0 ]] && log "In sync."
    for app in "${new_apps[@]}"; do
        echo "  installed, not listed: $app"
        [[ $interactive -eq 1 ]] || continue
        ask "    [a]dd to flatpak-packages.txt  [i]gnore  [s]kip >"
        case "$REPLY" in
            a) list_add "$FLATPAK_LIST" "$app"; log "    + flatpak-packages.txt" ;;
            i) ensure_ignored_file; list_add "$IGNORED" "$app"; log "    + ignored.txt" ;;
        esac
    done
    for app in "${gone_apps[@]}"; do
        echo "  listed, not installed: $app"
        [[ $interactive -eq 1 ]] || continue
        ask "    [r]emove from flatpak-packages.txt  [k]eep (update.sh reinstalls it) >"
        if [[ "$REPLY" == r ]]; then
            list_remove "$FLATPAK_LIST" "$app"
            log "    - flatpak-packages.txt"
        fi
    done
fi

# ---------------------------------------------------------------------------
section "OUTSIDE PACMAN/FLATPAK (report only)"

if [[ -n "$foreign" ]]; then
    echo "  Not from the official repos (AUR / manual makepkg), pacman -Qm:"
    pacman -Qm | sed 's/^/    /'
fi

# Things the repo itself puts outside pacman, so they're labelled, not flagged
declare -A repo_installed=(
    [/usr/local/bin/quickshell]="Quickshell, 02-build-from-source.sh"
    [/usr/local/bin/qs]="Quickshell, 02-build-from-source.sh"
    [/usr/local/bin/snap-backup]="scripts/lib/snapshots.sh"
    [/usr/local/bin/snap-baseline]="scripts/lib/snapshots.sh"
    [/usr/local/bin/snap-boot-backup]="scripts/lib/snapshots.sh"
    [/usr/local/bin/snap-rollback]="scripts/lib/snapshots.sh"
    [/usr/local/bin/determinate-nixd]="Nix, 03-nix-install.sh"
    [/usr/local/bin/pwsh]="PowerShell, languages profile"
    [$HOME/.local/bin/grimblast]="02-build-from-source.sh"
    [$HOME/.local/bin/rgb]="05-dotfiles-copy.sh"
    [$HOME/.local/bin/msfconsole]="Metasploit, security profile"
    [$HOME/.local/bin/msfvenom]="Metasploit, security profile"
    [$HOME/.local/bin/msfdb]="Metasploit, security profile"
)

echo "  Unowned by any package in /usr/local/bin, /usr/local/sbin, /opt:"
for f in /usr/local/bin/* /usr/local/sbin/* /opt/*; do
    [[ -e "$f" ]] || continue
    pacman -Qoq "$f" &>/dev/null && continue
    echo "    $f${repo_installed[$f]:+  (this repo: ${repo_installed[$f]})}"
done

if [[ -d "$HOME/.local/bin" ]]; then
    echo "  ~/.local/bin:"
    for f in "$HOME"/.local/bin/*; do
        [[ -e "$f" ]] || continue
        echo "    ${f/#$HOME/\~}${repo_installed[$f]:+  (this repo: ${repo_installed[$f]})}"
    done
fi

if command_exists pipx && [[ -n "$(pipx list --short 2>/dev/null)" ]]; then
    echo "  pipx:"
    pipx list --short | sed 's/^/    /'
fi
if [[ -d "$HOME/.cargo/bin" ]]; then
    echo "  cargo (~/.cargo/bin):"
    ls -1 "$HOME/.cargo/bin" | sed 's/^/    /'
fi
if command_exists npm; then
    npm_globals="$(npm ls -g --depth=0 --parseable 2>/dev/null | tail -n +2 | xargs -r -n1 basename)"
    if [[ -n "$npm_globals" ]]; then
        echo "  npm -g:"
        sed 's/^/    /' <<<"$npm_globals"
    fi
fi
if command_exists nix; then
    nix_pkgs="$(nix profile list --json 2>/dev/null | jq -r '.elements | keys[]' 2>/dev/null || true)"
    if [[ -n "$nix_pkgs" ]]; then
        echo "  nix profile:"
        sed 's/^/    /' <<<"$nix_pkgs"
    fi
fi

# ---------------------------------------------------------------------------
echo
if [[ $changed -eq 1 ]]; then
    log "Package lists changed. Review and commit:"
    git -C "$REPO_ROOT" --no-pager diff --stat -- packages/
fi
