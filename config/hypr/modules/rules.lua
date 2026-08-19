-- rules.lua
-- Window rules, workspace rules.
-- Add discovered misbehaving windows to the DISCOVERED RULES section.
--
-- To find a window's class and title:
--   hyprctl clients -j | jq '.[] | {class: .class, title: .title}'

-- --------------------------------------------------------
-- WORKSPACE LAYOUT OVERRIDES
-- Workspaces 4 and 5 use scrolling (scratch pads)
-- --------------------------------------------------------
hl.workspace_rule({ workspace = "4", layout = "scrolling" })
hl.workspace_rule({ workspace = "5", layout = "scrolling" })

-- --------------------------------------------------------
-- SUPPRESS MAXIMIZE
-- Ignore maximize requests from all apps.
-- --------------------------------------------------------
hl.window_rule({
  match  = { class = ".*" },
  suppress_event = "maximize",
})

-- --------------------------------------------------------
-- XWAYLAND DRAG FIX
-- Fixes dragging issues with XWayland floating windows.
-- Affects Steam, Vivaldi, Teams (all XWayland apps).
-- --------------------------------------------------------
hl.window_rule({
  match  = {
    class     = "^$",
    title     = "^$",
    xwayland  = true,
    float     = true,
    fullscreen = false,
    pin       = false,
  },
  no_focus = true,
})

-- --------------------------------------------------------
-- TEARING
-- Master toggle is set in options.lua (allow_tearing = true)
-- immediate rule required per-window for tearing to activate.
-- Covers all Steam games regardless of app ID.
-- --------------------------------------------------------
hl.window_rule({
  match     = { class = "^steam_app_.*" },
  immediate = true,
})

-- --------------------------------------------------------
-- FLOAT RULES
-- Windows that should never tile.
-- --------------------------------------------------------

-- Polkit agent
hl.window_rule({
  match = { class = "hyprpolkitagent" },
  float = true,
})

-- File dialogs (common classes)
hl.window_rule({
  match = { title = ".*Open File.*" },
  float = true,
})
hl.window_rule({
  match = { title = ".*Save As.*" },
  float = true,
})

-- wlogout
hl.window_rule({
  match = { class = "wlogout" },
  float = true,
})

-- swaync control center
hl.window_rule({
  match = { class = "swaync" },
  float = true,
})

-- Disable animations for opacity change (For Dashboard animation)
hl.window_rule({
  name = "dashboard-hide-no-anim",
  match = { class = ".*" },
  enabled = false,
  no_anim = true,
})

-- --------------------------------------------------------
-- DISCOVERED RULES
-- Add misbehaving windows here as you find them.
-- Format:
--   hl.window_rule({
--     match = { class = "classname", title = "optional" },
--     float = true,  -- or whatever fix is needed
--   })
-- --------------------------------------------------------
-- Batman: Arkham Asylum GOTY — opens floating by default, force tiled
hl.window_rule({
  match = { class = "^steam_app_35140$" },
  float = false,
})

-- --------------------------------------------------------
-- DASHBOARD HIDE (Quickshell-driven, via dynamic tag)
-- --------------------------------------------------------
hl.window_rule({ match = { tag = "dashboard_hidden" }, opacity = "0 override 0 override" })

-- --------------------------------------------------------
-- VIVALDI NATIVE NOTIFICATION FLOAT FIX
-- Vivaldi's native notification popups render as anonymous
-- Hyprland windows (empty class, empty title). Without this,
-- they get inserted into the tiling layout as a real window
-- instead of floating as a popup.
-- --------------------------------------------------------
hl.window_rule({
  match = { class = "^$", title = "^$" },
  float = true,
  move = {"monitor_w-320", "20"},
  size = {"300", "100"},
})
