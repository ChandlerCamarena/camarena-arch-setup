#!/usr/bin/env bash
# security.sh - profile build-from-source steps for --security / -S
# sourced by 02-build-from-source.sh, not executed directly
# expects log(), err(), command_exists() from lib/common.sh

BURP_INSTALL_DIR="$HOME/.local/opt/burpsuite"
BURP_URL="https://portswigger.net/burp/releases/download?product=community&type=linux"

METASPLOIT_SRC_DIR="$HOME/.local/src/metasploit-framework"
METASPLOIT_INSTALL_DIR="$HOME/.local/opt/metasploit-framework"

build_burpsuite() {
    if command_exists burpsuite || [[ -d "$BURP_INSTALL_DIR" ]]; then
        log "Burp Suite Community already installed at $BURP_INSTALL_DIR, skipping"
        return 0
    fi

    log "Downloading Burp Suite Community installer (latest)..."
    local tmp_installer
    tmp_installer="$(mktemp --suffix=.sh)"
    curl -fsSL "$BURP_URL" -o "$tmp_installer"
    chmod +x "$tmp_installer"

    log "Running Burp Suite installer in unattended mode, installing to $BURP_INSTALL_DIR..."
    # install4j installer: -q = unattended, -dir = target install path
    "$tmp_installer" -q -dir "$BURP_INSTALL_DIR"
    rm -f "$tmp_installer"

    log "Burp Suite Community installed to $BURP_INSTALL_DIR"
    log "NOTE: verify the launcher script name under $BURP_INSTALL_DIR after first run and symlink it into PATH if you want a bare 'burpsuite' command."
}

build_metasploit() {
    if command_exists msfconsole || [[ -d "$METASPLOIT_INSTALL_DIR" ]]; then
        log "Metasploit already installed at $METASPLOIT_INSTALL_DIR, skipping"
        return 0
    fi

    # Rapid7's official omnibus installer (msfinstall) only supports .deb/.rpm
    # systems -- it shells out to apt-get directly and fails hard on Arch.
    # This is Rapid7's own documented fallback for unsupported distros:
    # clone source, build with the project's own Ruby/Bundler setup.
    log "Building Metasploit from source (Rapid7 omnibus installer does not support Arch)..."

    if ! command_exists ruby || ! command_exists bundle; then
        err "ruby and bundler are required to build Metasploit from source."
        err "Add ruby to base.txt/security.txt and 'gem install bundler' before this stage runs."
        return 1
    fi

    if [[ ! -d "$METASPLOIT_SRC_DIR" ]]; then
        log "Cloning metasploit-framework..."
        git clone --depth 1 https://github.com/rapid7/metasploit-framework.git "$METASPLOIT_SRC_DIR"
    else
        log "metasploit-framework source already present, pulling latest..."
        git -C "$METASPLOIT_SRC_DIR" pull --ff-only
    fi

    log "Installing gem dependencies via bundler..."
    (cd "$METASPLOIT_SRC_DIR" && bundle install)

    mkdir -p "$METASPLOIT_INSTALL_DIR"
    ln -sfn "$METASPLOIT_SRC_DIR" "$METASPLOIT_INSTALL_DIR/current"

    log "Metasploit built from source at $METASPLOIT_SRC_DIR"
    log "Run via: bundle exec ./msfconsole from that directory, or wrap in a launcher script."
    log "First run will prompt to set up a local postgres database (msfdb init)."
}

run_security_builds() {
    log "Running security profile build-from-source steps..."
    build_burpsuite
    build_metasploit
}
