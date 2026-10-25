#!/usr/bin/env bash
# checks.sh - post-install assertions, run INSIDE the test VM as the normal
# user (vm.sh check pipes it over ssh). One line per check, non-zero exit if
# any failed. Covers what can be verified without a logged-in session;
# Hyprland/Quickshell themselves still get eyeballed with vm.sh start.
set -uo pipefail
fail=0

# The VM's own clone: profile selection (hosts/<hostname>.conf) and pins
REPO="$HOME/camarena-arch-setup"
source "$REPO/scripts/lib/common.sh"
source "$REPO/scripts/lib/profiles.sh"
source "$REPO/scripts/lib/sources.sh"
resolve_profiles >/dev/null
active() { profile_active "$1"; }
pass()  { echo "[check] PASS  $*"; }
fails() { echo "[check] FAIL  $*"; fail=1; }

# check <description> <command...>
check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fails "$desc"; fi
}

no_failed_units() {
    local failed
    failed="$(systemctl --failed --no-legend --plain | awk '{print $1}')"
    [[ -z "$failed" ]] || { echo "$failed" >&2; return 1; }
}

theme_is_rice_symlink() {
    local t="$HOME/.config/hypr/theme.json"
    [[ -L "$t" ]] && [[ "$(readlink -f "$t")" == "$HOME/.config/rices/"*/theme.json ]] \
        && jq empty "$t"
}

active_rice_exists() {
    local r
    r="$(cat "$HOME/.config/rices/.active")"
    [[ -f "$HOME/.config/rices/$r/theme.json" ]]
}

no_backups() {
    [[ -z "$(find "$HOME/.config" -name '*.bak.*' -print -quit)" ]]
}

# Fresh nvim: plugins from lazy-lock, the cpp parser compiled, and then
# Treesitter (not regex syntax) actually highlighting a C++ buffer.
nvim_treesitter_highlights() {
    local f out
    f="$(mktemp --suffix=.cpp)"
    echo 'int main() { return 0; }' > "$f"
    timeout 600 nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1
    timeout 600 nvim --headless "+lua require('nvim-treesitter').install({ 'cpp' }):wait(300000)" +qa >/dev/null 2>&1
    out="$(timeout 60 nvim --headless \
        -c 'lua io.write(tostring(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil))' \
        -c 'qa!' "$f" 2>&1)"
    rm -f "$f"
    [[ "$out" == *true* ]]
}

# Every package in a list is installed
list_installed() {
    local missing
    missing="$(grep -vE '^\s*#|^\s*$' "$1" | while read -r p; do pacman -Qq "$p" &>/dev/null || echo "$p"; done)"
    [[ -z "$missing" ]] || { echo "missing: $missing" >&2; return 1; }
}

# No package of a skipped profile was explicitly installed, unless base or an
# active profile also lists it
skipped_not_installed() {
    local skipped="$1" wanted explicit p
    # base.txt, the active profiles, and what the VM's own base image brought
    # -h: with two files grep would prefix every line with its file name
    wanted="$( { grep -hvE '^\s*#|^\s*$' "$REPO/packages/base.txt" "$REPO/tools/vm/base-packages.txt"
                 for p in $CAS_PROFILES; do grep -vE '^\s*#|^\s*$' "$REPO/packages/profiles/$p.txt"; done; } | sort -u)"
    explicit="$(pacman -Qqe | sort -u)"
    # captured, not piped into grep -q (SIGPIPE under pipefail, see 04-fonts.sh)
    p="$(comm -12 <(grep -vE '^\s*#|^\s*$' "$REPO/packages/profiles/$skipped.txt" | sort -u) <(echo "$explicit") \
        | comm -23 - <(echo "$wanted"))"
    [[ -z "$p" ]] || { echo "installed anyway: $p" >&2; return 1; }
}

at_pin() {
    [[ "$(git -C "$2" rev-parse HEAD 2>/dev/null)" == "$(source_get "$1" pin)" ]]
}

pwsh_at_pin() {
    local v
    v="$(timeout 120 pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null)"
    [[ "v$v" == "$(source_get powershell pin)" ]]
}

baseline_exists() {
    sudo snapper -c "$1" list | grep -q 'clean install'
}

echo "[check] Failed units (if any):"
systemctl --failed --no-legend --plain | sed 's/^/[check]   /'

check "no failed systemd units"                    no_failed_units
check "sddm enabled"                               systemctl is-enabled sddm
check "NetworkManager active"                      systemctl is-active NetworkManager
check "snapper timeline timer enabled"             systemctl is-enabled snapper-timeline.timer
check "fstab mounts subvolumes by name (no subvolid)" test -z "$(grep -E '^[^#].*btrfs.*subvolid=' /etc/fstab)"
check "root clean-install baseline snapshot"       baseline_exists root
check "home clean-install baseline snapshot"       baseline_exists home
check "quickshell installed"                       command -v quickshell
check "Departure Mono registered"                  test -n "$(fc-list 'Departure Mono')"
check "theme.json symlinks into a rice"            theme_is_rice_symlink
check "wallpaper symlinks into a rice"             test -L "$HOME/.config/hypr/wallpapers/wallpaper.png" -a -f "$HOME/.config/hypr/wallpapers/wallpaper.png"
check "active rice recorded"                       active_rice_exists
check "kitty colors generated"                     test -s "$HOME/.config/kitty/colors-generated.conf"
check "yazi theme generated"                       test -s "$HOME/.config/yazi/theme.toml"
check "nvim colors generated"                      test -s "$HOME/.config/nvim/lua/theme-colors.lua"
check "gtk css generated"                          test -s "$HOME/.config/gtk-3.0/gtk.css"
check "rofi colors generated"                      test -s "$HOME/.config/rofi/colors/retrowave.rasi"
check "dotfile manifest written"                   test -s "${XDG_STATE_HOME:-$HOME/.local/state}/camarena-arch-setup/managed-files"
check "no .bak files left in ~/.config"            no_backups
check "login shell is zsh"                         test "$(getent passwd "$USER" | cut -d: -f7)" = /usr/bin/zsh
check "oh-my-zsh at pinned commit"                 at_pin ohmyzsh "$HOME/.config/zsh/ohmyzsh"
check "powerlevel10k at pinned commit"             at_pin powerlevel10k "$HOME/.config/zsh/ohmyzsh/custom/themes/powerlevel10k"
check "quickshell built at pinned commit"          test "$(cut -d' ' -f1 "$HOME/.local/src/quickshell/.last-built-commit")" = "$(source_get quickshell pin)"
check "grimblast installed"                        test -x "$HOME/.local/bin/grimblast"
for ls_bin in clangd lua-language-server pyright-langserver bash-language-server; do
    check "base language server: $ls_bin"         command -v "$ls_bin"
done
check "nvim: treesitter highlights C++"            nvim_treesitter_highlights

# --- profiles ---------------------------------------------------------------
echo "[check] Active profiles: ${CAS_PROFILES:-none}"
for p in $(all_profiles); do
    if active "$p"; then
        check "profile $p: all packages installed"     list_installed "$REPO/packages/profiles/$p.txt"
    else
        check "profile $p (skipped): not installed"    skipped_not_installed "$p"
    fi
done

if active gaming; then
    check "gaming: Steam dir is its own subvolume" test "$(stat -c %i "$HOME/.local/share/Steam")" = 256
else
    check "gaming skipped: no Steam subvolume"     test ! -e "$HOME/.local/share/Steam"
fi
if active rgb; then
    check "rgb: rgb command installed"             test -x "$HOME/.local/bin/rgb"
    check "rgb: openrgb.service enabled"           test -L "$HOME/.config/systemd/user/graphical-session.target.wants/openrgb.service"
else
    check "rgb skipped: no RGB config deployed"    test ! -e "$HOME/.local/bin/rgb"
fi
if active languages; then
    check "languages: pwsh at pinned version"      pwsh_at_pin
    check "languages: Haskell LSP installed"       command -v haskell-language-server-wrapper
fi
if active security; then
    check "security: Metasploit at pinned commit"  test "$(cat "$HOME/.local/src/metasploit-framework/.last-built-commit")" = "$(source_get metasploit pin)"
    check "security: msfconsole runs"              timeout 300 "$HOME/.local/bin/msfconsole" --version
    check "security: Burp Suite installed"         test -d "$HOME/.local/opt/burpsuite"
fi

if [[ "$fail" -ne 0 ]]; then
    echo "[check] FAILED"
    exit 1
fi
echo "[check] All checks passed."
