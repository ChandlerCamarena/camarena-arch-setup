#!/usr/bin/env bash
# languages.sh - non-pacman installs for the languages profile.
# Sourced by 02-build-from-source.sh, not executed directly; expects
# common.sh and sources.sh.

PWSH_DIR="/usr/local/lib/powershell"
PWSH_MARKER="$PWSH_DIR/.installed-tag"

# PowerShell: Microsoft's official linux-x64 release tarball (self-contained,
# bundles its .NET runtime) instead of the AUR's powershell-bin.
build_powershell() {
    local tag version url tmp tarball
    tag="$(source_get powershell pin)"
    if [[ "$(cat "$PWSH_MARKER" 2>/dev/null)" == "$tag" ]]; then
        log "PowerShell already at pinned $tag."
        return 0
    fi
    version="${tag#v}"
    url="$(source_get powershell url)/releases/download/$tag/powershell-$version-linux-x64.tar.gz"

    log "Installing PowerShell $tag from $url..."
    tmp="$(mktemp -d)"
    tarball="$(mktemp --suffix=.tar.gz)"
    curl -fL --progress-bar -o "$tarball" "$url"
    tar -xzf "$tarball" -C "$tmp"
    rm -f "$tarball"
    chmod +x "$tmp/pwsh"

    sudo rm -rf "$PWSH_DIR"
    sudo mkdir -p "$(dirname "$PWSH_DIR")"
    sudo mv "$tmp" "$PWSH_DIR"
    sudo chmod 755 "$PWSH_DIR"
    sudo ln -sfn "$PWSH_DIR/pwsh" /usr/local/bin/pwsh
    echo "$tag" | sudo tee "$PWSH_MARKER" >/dev/null
    log "PowerShell $tag installed: /usr/local/bin/pwsh"
}

run_languages_builds() {
    log "Running languages profile install steps..."
    build_powershell
}
