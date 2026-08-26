-- autostart.lua
-- All exec-once equivalents.
hl.on("hyprland.start", function()
  -- Wallpaper
  hl.exec_cmd("hyprpaper")
  -- Polkit agent
  hl.exec_cmd("hyprpolkitagent")
  -- Idle daemon
  hl.exec_cmd("hypridle -c ~/.config/hypr/hypridle.conf")
  -- Resolve hyprlock.conf from its template now that a live
  -- session (and hyprctl) actually exists. monitors.lua's
  -- monitor.added/removed hooks keep it in sync after this.
  hl.exec_cmd("bash ~/.config/hypr/scripts/generation/generate-hyprlock.sh >/tmp/generate-hyprlock.log 2>&1")
  -- Clipboard backend
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  -- Bluetooth tray
  hl.exec_cmd("blueman-applet")
  -- Media priority daemon (pauses mpv when other audio plays)
  hl.exec_cmd("~/.config/hypr/scripts/media-priority.sh")
  -- Jazz autoplay
  hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.2")
  hl.exec_cmd("playerctld daemon")
  hl.exec_cmd("mpv --no-video --shuffle --loop-playlist=inf --script=/usr/lib/mpv/mpris.so ~/Music/jazz/")
  -- Quickshell shell (dashboard, taskbar, notifications, replaces AGS entirely)
  hl.exec_cmd("quickshell > /tmp/qs.log 2>&1 &")
  --Start on Workspace id 3 (Bind 1)
  hl.dispatch(hl.dsp.focus({ workspace = "3" }))
end)
