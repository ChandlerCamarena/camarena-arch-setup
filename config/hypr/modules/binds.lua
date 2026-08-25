-- binds.lua
-- All keybindings and mouse binds.
-- Modifier: SUPER

local M = "SUPER"

-- --------------------------------------------------------
-- APPLICATIONS
-- --------------------------------------------------------
hl.bind(M .. " + Return", hl.dsp.exec_cmd("kitty"))


hl.bind(M .. " + R",      hl.dsp.exec_cmd("steam"))
hl.bind(M .. " + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/cliphist-rofi.sh"))

hl.bind(M .. " + E",      hl.dsp.exec_cmd("thunar"))
--               D is Dashboard
hl.bind(M .. " + C",      hl.dsp.exec_cmd("~/.config/rofi/launchers/type-1/launcher.sh"))

--w is wallpaper
hl.bind(M .. " + S",      hl.dsp.exec_cmd("spotify-launcher"))

hl.bind(M .. " + Q",      hl.dsp.exec_cmd("discord"))
hl.bind(M .. " + z",      hl.dsp.exec_cmd("qs ipc call powermenu toggle"))

hl.bind(M .. " + semicolon", hl.dsp.exec_cmd("sh -c 'GDK_BACKEND=wayland vivaldi --ozone-platform=wayland --enable-features=WaylandFractionalScaleV1'"))
-- --------------------------------------------------------
-- WINDOW MANAGEMENT
-- --------------------------------------------------------
hl.bind(M .. " + A",     hl.dsp.window.close())
hl.bind(M .. " + F",     hl.dsp.window.fullscreen())
hl.bind(M .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))


-- --------------------------------------------------------
-- CONTEXT-AWARE FOCUS & COLUMN MOVEMENT (HJKL)
-- --------------------------------------------------------
-- Left Action: Move column if scrolling layout, otherwise change focus left
hl.bind(M .. " + H", function()
  local ws = hl.get_active_workspace()
  if ws and (ws.tiled_layout == "scrolling" or ws.tiled_layout == "scroller") then
    hl.dispatch(hl.dsp.layout("move -col"))
  else
    hl.dispatch(hl.dsp.focus({ direction = "l" }))
  end
end)


-- Right Action: Move column if scrolling layout, otherwise change focus right
hl.bind(M .. " + L", function()
  local ws = hl.get_active_workspace()
  if ws and (ws.tiled_layout == "scrolling" or ws.tiled_layout == "scroller") then
    hl.dispatch(hl.dsp.layout("move +col"))
  else
    hl.dispatch(hl.dsp.focus({ direction = "r" }))
  end
end)


-- Down / Up focus mappings (No layout conflicts)
hl.bind(M .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(M .. " + K", hl.dsp.focus({ direction = "u" }))


-- --------------------------------------------------------
-- WINDOW MOVEMENT
-- --------------------------------------------------------
hl.bind(M .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(M .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind(M .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(M .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))


-- --------------------------------------------------------
-- SCREENSHOT (Explicit destination path with timestamp)
-- --------------------------------------------------------
hl.bind(M .. " + SHIFT + S", function()
  hl.dispatch(hl.dsp.exec_cmd("sh -c 'sleep 0.1 && $HOME/.local/bin/grimblast copysave area $HOME/Pictures/Screenshots/$(date +%Y%m%d_%H%M%S).png'"))
end)


-- --------------------------------------------------------
-- WORKSPACES (Custom Task-Oriented Layout Map)
-- --------------------------------------------------------
local custom_workspaces = {
  { key = "W",     id = "1" }, -- Wallpaper Setup
  { key = "grave", id = "2", layout = "scrolling" }, -- Scrolling Scratchpad (The `~` key)
  { key = "1",     id = "3", default = true }, -- Terminal Hub
  { key = "2",     id = "4" }, -- Browser Environment
  { key = "3",     id = "5" }, -- Spotify / Audio Control
  { key = "4",     id = "6" }, -- Dwindle Scratchpad
  { key = "5",     id = "7", layout = "scrolling" }, --Main Scrolling Layout
}


for _, ws in ipairs(custom_workspaces) do
  -- Enforce a specific layout engine on this workspace if one is specified
  if ws.layout then
    hl.workspace_rule({ workspace = ws.id, layout = ws.layout })
  end

  -- SUPER + Key to jump to workspace
  hl.bind(M .. " + " .. ws.key, hl.dsp.focus({ workspace = ws.id }))
  -- SUPER + SHIFT + Key to throw active window to workspace
  hl.bind(M .. " + SHIFT + " .. ws.key, hl.dsp.window.move({ workspace = ws.id }))
end


-- --------------------------------------------------------
-- TOUCHPAD GESTURE
-- --------------------------------------------------------
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })


-- --------------------------------------------------------
-- MOUSE BINDS
-- --------------------------------------------------------
hl.bind(M .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- --------------------------------------------------------
-- MEDIA KEYS
-- --------------------------------------------------------
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("sh -c 'brightnessctl -e4 -n2 set 5%+; qs ipc call brightness sync'"), { repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("sh -c 'brightnessctl -e4 -n2 set 5%-; qs ipc call brightness sync'"), { repeating = true })


hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"), { locked = true })


-- --------------------------------------------------------
-- LID SWITCH
-- --------------------------------------------------------
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("loginctl lock-session"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl dispatch dpms on"), { locked = true })


-- --------------------------------------------------------
-- DASHBOARD TOGGLE
-- --------------------------------------------------------
hl.bind(M .. " + D", hl.dsp.exec_cmd("qs ipc call dashboard toggle"))

-- ── NOTIFICATION CENTER ──────────────────────────────────
hl.bind(M .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"))

-- ── MEDIA PAUSE ──────────────────────────────────────────
hl.bind(M .. " + P", hl.dsp.exec_cmd("playerctl play-pause"))

-- ── MEDIA PREV / NEXT ─────────────────────────────────────
hl.bind(M .. " + comma",  hl.dsp.exec_cmd("playerctl previous"))
hl.bind(M .. " + period", hl.dsp.exec_cmd("playerctl next"))



-- ── STAT GRAPH TOGGLES ───────────────────────────────────
hl.bind(M .. " + 6", hl.dsp.exec_cmd("qs ipc call cpugraph toggle"))
hl.bind(M .. " + 7", hl.dsp.exec_cmd("qs ipc call ramgraph toggle"))
hl.bind(M .. " + 8", hl.dsp.exec_cmd("qs ipc call gpugraph toggle"))

-- ── AUDIO MIXER TOGGLE ───────────────────────────────────
hl.bind(M .. " + 0", hl.dsp.exec_cmd("qs ipc call mixer toggle"))

-- ── CALENDAR TOGGLE ──────────────────────────────────────
hl.bind(M .. " + apostrophe", hl.dsp.exec_cmd("qs ipc call calendar toggle"))

-- ── NET GRAPH TOGGLE ─────────────────────────────────────
hl.bind(M .. " + 9", hl.dsp.exec_cmd("qs ipc call netgraph toggle"))

-- ── RICE SWITCHER TOGGLE ────────────────────────
hl.bind(M .. " + Delete", hl.dsp.exec_cmd("qs ipc call ricepicker toggle"))
