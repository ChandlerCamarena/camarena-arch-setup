#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

require_not_root

CONFIG_SRC="$SCRIPT_DIR/../config"

log "Setting system-wide ZDOTDIR..."
if ! grep -q 'ZDOTDIR' /etc/zsh/zshenv 2>/dev/null; then
    echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a /etc/zsh/zshenv
fi

log "Copying Quickshell config..."
copy_plain "$CONFIG_SRC/quickshell/shell.qml"                       "$HOME/.config/quickshell/shell.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/qmldir"                  "$HOME/.config/quickshell/modules/qmldir"
copy_plain "$CONFIG_SRC/quickshell/modules/Theme.qml"                "$HOME/.config/quickshell/modules/Theme.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/BevelPanel.qml"           "$HOME/.config/quickshell/modules/BevelPanel.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Clock.qml"                "$HOME/.config/quickshell/modules/Clock.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Calendar.qml"             "$HOME/.config/quickshell/modules/Calendar.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/WorkspaceIndicator.qml"   "$HOME/.config/quickshell/modules/WorkspaceIndicator.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Battery.qml"              "$HOME/.config/quickshell/modules/Battery.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Volume.qml"               "$HOME/.config/quickshell/modules/Volume.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/VolumeState.qml"          "$HOME/.config/quickshell/modules/VolumeState.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/VolumeOSD.qml"            "$HOME/.config/quickshell/modules/VolumeOSD.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Brightness.qml"           "$HOME/.config/quickshell/modules/Brightness.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/BrightnessState.qml"      "$HOME/.config/quickshell/modules/BrightnessState.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/BrightnessOSD.qml"        "$HOME/.config/quickshell/modules/BrightnessOSD.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/NotificationBell.qml"     "$HOME/.config/quickshell/modules/NotificationBell.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/NotificationCenter.qml"   "$HOME/.config/quickshell/modules/NotificationCenter.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/NotificationToast.qml"    "$HOME/.config/quickshell/modules/NotificationToast.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/NotificationDaemon.qml"   "$HOME/.config/quickshell/modules/NotificationDaemon.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/SystemStats.qml"          "$HOME/.config/quickshell/modules/SystemStats.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/StatGraph.qml"            "$HOME/.config/quickshell/modules/StatGraph.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/MiniMeter.qml"            "$HOME/.config/quickshell/modules/MiniMeter.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Media.qml"                "$HOME/.config/quickshell/modules/Media.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/MediaCompact.qml"         "$HOME/.config/quickshell/modules/MediaCompact.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/Mixer.qml"                "$HOME/.config/quickshell/modules/Mixer.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/MixerEntry.qml"           "$HOME/.config/quickshell/modules/MixerEntry.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/MixerDaemon.qml"          "$HOME/.config/quickshell/modules/MixerDaemon.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/WifiState.qml"            "$HOME/.config/quickshell/modules/WifiState.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/PowerMenu.qml"            "$HOME/.config/quickshell/modules/PowerMenu.qml"
copy_plain "$CONFIG_SRC/quickshell/modules/RiceSwitcher.qml"         "$HOME/.config/quickshell/modules/RiceSwitcher.qml"

log "Copying Hyprland config..."
copy_plain "$CONFIG_SRC/hypr/hyprland.lua"          "$HOME/.config/hypr/hyprland.lua"
copy_plain "$CONFIG_SRC/hypr/hypridle.conf"         "$HOME/.config/hypr/hypridle.conf"
copy_plain "$CONFIG_SRC/hypr/hyprlock.conf"         "$HOME/.config/hypr/hyprlock.conf"
copy_plain "$CONFIG_SRC/hypr/hyprpaper.conf"        "$HOME/.config/hypr/hyprpaper.conf"
copy_plain "$CONFIG_SRC/hypr/theme.json"            "$HOME/.config/hypr/theme.json"

copy_plain "$CONFIG_SRC/hypr/modules/theme.lua"     "$HOME/.config/hypr/modules/theme.lua"
copy_plain "$CONFIG_SRC/hypr/modules/monitors.lua"  "$HOME/.config/hypr/modules/monitors.lua"
copy_plain "$CONFIG_SRC/hypr/modules/options.lua"   "$HOME/.config/hypr/modules/options.lua"
copy_plain "$CONFIG_SRC/hypr/modules/autostart.lua" "$HOME/.config/hypr/modules/autostart.lua"
copy_plain "$CONFIG_SRC/hypr/modules/binds.lua"     "$HOME/.config/hypr/modules/binds.lua"
copy_plain "$CONFIG_SRC/hypr/modules/rules.lua"     "$HOME/.config/hypr/modules/rules.lua"

log "Copying Hyprland scripts..."
copy_plain "$CONFIG_SRC/hypr/scripts/idle/idle-action.sh"    "$HOME/.config/hypr/scripts/idle/idle-action.sh"
copy_plain "$CONFIG_SRC/hypr/scripts/media/media-priority.sh" "$HOME/.config/hypr/scripts/media/media-priority.sh"
copy_plain "$CONFIG_SRC/hypr/scripts/clipboard/cliphist-rofi.sh"  "$HOME/.config/hypr/scripts/clipboard/cliphist-rofi.sh"

log "Copying theme generator scripts (outputs are NOT committed, generated below)..."
copy_plain "$CONFIG_SRC/hypr/scripts/generation/generate-theme.sh"        "$HOME/.config/hypr/scripts/generation/generate-theme.sh"
copy_plain "$CONFIG_SRC/hypr/scripts/generation/generate-colors.sh"        "$HOME/.config/hypr/scripts/generation/generate-colors.sh"
copy_plain "$CONFIG_SRC/hypr/scripts/generation/generate-theme-colors.sh"  "$HOME/.config/hypr/scripts/generation/generate-theme-colors.sh"
copy_plain "$CONFIG_SRC/hypr/scripts/generation/generate-thunar-css.sh"    "$HOME/.config/hypr/scripts/generation/generate-thunar-css.sh"

chmod +x "$HOME/.config/hypr/scripts/idle/"*.sh
chmod +x "$HOME/.config/hypr/scripts/media/"*.sh
chmod +x "$HOME/.config/hypr/scripts/clipboard/"*.sh
chmod +x "$HOME/.config/hypr/scripts/generation/"*.sh

log "Copying wallpaper..."
copy_plain "$CONFIG_SRC/hypr/wallpapers/wallpaper.png" "$HOME/.config/hypr/wallpapers/wallpaper.png"

log "Copying Kitty config..."
copy_plain "$CONFIG_SRC/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"

log "Copying Neovim config..."
copy_plain "$CONFIG_SRC/nvim/init.lua"           "$HOME/.config/nvim/init.lua"
copy_plain "$CONFIG_SRC/nvim/lazy-lock.json"     "$HOME/.config/nvim/lazy-lock.json"
copy_plain "$CONFIG_SRC/nvim/lua/options.lua"    "$HOME/.config/nvim/lua/options.lua"
copy_plain "$CONFIG_SRC/nvim/lua/keymaps.lua"    "$HOME/.config/nvim/lua/keymaps.lua"
copy_plain "$CONFIG_SRC/nvim/lua/plugins.lua"    "$HOME/.config/nvim/lua/plugins.lua"
copy_plain "$CONFIG_SRC/nvim/lua/lsp.lua"        "$HOME/.config/nvim/lua/lsp.lua"

log "Copying Rofi config..."
copy_plain "$CONFIG_SRC/rofi/config.rasi"    "$HOME/.config/rofi/config.rasi"
copy_plain "$CONFIG_SRC/rofi/powermenu.rasi" "$HOME/.config/rofi/powermenu.rasi"
copy_plain "$CONFIG_SRC/rofi/colors/retrowave.rasi" "$HOME/.config/rofi/colors/retrowave.rasi"
copy_plain "$CONFIG_SRC/rofi/launchers/type-1/launcher.sh"        "$HOME/.config/rofi/launchers/type-1/launcher.sh"
copy_plain "$CONFIG_SRC/rofi/launchers/type-1/style-2.rasi"       "$HOME/.config/rofi/launchers/type-1/style-2.rasi"
copy_plain "$CONFIG_SRC/rofi/launchers/type-1/shared/colors.rasi" "$HOME/.config/rofi/launchers/type-1/shared/colors.rasi"
copy_plain "$CONFIG_SRC/rofi/launchers/type-1/shared/fonts.rasi"  "$HOME/.config/rofi/launchers/type-1/shared/fonts.rasi"
chmod +x "$HOME/.config/rofi/launchers/type-1/launcher.sh"

log "Copying Thunar config..."
copy_plain "$CONFIG_SRC/Thunar/uca.xml"    "$HOME/.config/Thunar/uca.xml"
copy_plain "$CONFIG_SRC/Thunar/accels.scm" "$HOME/.config/Thunar/accels.scm"

log "Copying GTK config..."
copy_plain "$CONFIG_SRC/gtk-3.0/settings.ini"      "$HOME/.config/gtk-3.0/settings.ini"
copy_plain "$CONFIG_SRC/gtk-3.0/gtk-template.css"  "$HOME/.config/gtk-3.0/gtk-template.css"
copy_plain "$CONFIG_SRC/gtk-4.0/settings.ini"      "$HOME/.config/gtk-4.0/settings.ini"

copy_plain "$CONFIG_SRC/mimeapps.list" "$HOME/.config/mimeapps.list"
copy_plain "$CONFIG_SRC/git/."         "$HOME/.config/git"
copy_plain "$CONFIG_SRC/zsh/."         "$HOME/.config/zsh"

log "Installing oh-my-zsh framework (not vendored, reinstalled fresh)..."
if [[ ! -d "$HOME/.config/zsh/oh-my-zsh" ]]; then
    ZDOTDIR="$HOME/.config/zsh" RUNZSH=no CHSH=no \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    log "oh-my-zsh already present, skipping."
fi

log "Installing powerlevel10k theme..."
P10K_DIR="$HOME/.config/zsh/ohmyzsh/custom/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    log "powerlevel10k already present, skipping."
fi

copy_plain "$CONFIG_SRC/yazi/."        "$HOME/.config/yazi"

log "Running theme generators to produce initial derived configs..."
bash "$HOME/.config/hypr/scripts/generation/generate-theme.sh"
bash "$HOME/.config/hypr/scripts/generation/generate-colors.sh"
bash "$HOME/.config/hypr/scripts/generation/generate-theme-colors.sh"
bash "$HOME/.config/hypr/scripts/generation/generate-thunar-css.sh"

log "Dotfiles copy stage complete."
