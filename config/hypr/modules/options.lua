local theme = require("modules/theme")

hl.config({

  -- --------------------------------------------------------
  -- GENERAL
  -- --------------------------------------------------------
  general = {
    gaps_in      = 2,
    gaps_out     = 2,
    border_size  = 3,

    ["col.active_border"]   = theme.border_active,
    ["col.inactive_border"] = theme.border_inactive,

    resize_on_border = false,
    allow_tearing    = true,
    layout           = "dwindle",
  },


  -- --------------------------------------------------------
  -- DECORATION
  -- --------------------------------------------------------
  decoration = {
    rounding       = 4,
    rounding_power = 2,

    active_opacity   = 1.0,
    inactive_opacity = 0.85,

    shadow = {
      enabled      = true,
      range        = 6,
      render_power = 4,
      color        = theme.shadow,
    },

    blur = {
      enabled   = true,
      size      = 2,
      passes    = 1,
      vibrancy  = 0.1,
    },
  },

  -- --------------------------------------------------------
  -- ANIMATIONS
  -- --------------------------------------------------------
  animations = {
    enabled = true,

    -- Modern retrowave curves (active)
    beziers = {
      easeOutQuint    = { 0.23, 1,    0.32, 1    },
      quick           = { 0.15, 0,    0.1,  1    },
      almostLinear    = { 0.5,  0.5,  0.75, 1    },
    },

    -- Snappy/mechanical (commented out)
    -- beziers = {
    --   linear        = { 0,    0,    1,    1    },
    --   quick         = { 0.15, 0,    0.1,  1    },
    --   snappy        = { 0.25, 0,    0.05, 1    },
    -- },

    animations = {
      -- Global fallback
      { event = "global",        enabled = true, speed = 8,    curve = "quick"        },

      -- Borders: near instant
      { event = "border",        enabled = true, speed = 8,    curve = "quick"        },

      -- Windows
      { event = "windows",       enabled = true, speed = 5,    curve = "easeOutQuint" },
      { event = "windowsIn",     enabled = true, speed = 4,    curve = "easeOutQuint", style = "popin 90%" },
      { event = "windowsOut",    enabled = true, speed = 3,    curve = "quick",        style = "popin 90%" },

      -- Fades
      { event = "fadeIn",        enabled = true, speed = 4,    curve = "almostLinear" },
      { event = "fadeOut",       enabled = true, speed = 3,    curve = "almostLinear" },
      { event = "fade",          enabled = true, speed = 5,    curve = "quick"        },

      -- Layers (swaync, rofi, wlogout)
      { event = "layers",        enabled = true, speed = 5,    curve = "easeOutQuint" },
      { event = "layersIn",      enabled = true, speed = 4,    curve = "easeOutQuint", style = "fade" },
      { event = "layersOut",     enabled = true, speed = 2,    curve = "quick",        style = "fade" },

      -- Workspaces: fast crossfade, no slide
      { event = "workspaces",    enabled = true, speed = 3,    curve = "easeOutQuint", style = "fade" },
      { event = "workspacesIn",  enabled = true, speed = 2.5,  curve = "easeOutQuint", style = "fade" },
      { event = "workspacesOut", enabled = true, speed = 2.5,  curve = "quick",        style = "fade" },
    },

    -- Snappy/mechanical animation rules (swap beziers block above to use)
    -- animations = {
    --   { event = "global",        enabled = true, speed = 12,   curve = "quick"   },
    --   { event = "border",        enabled = true, speed = 15,   curve = "linear"  },
    --   { event = "windows",       enabled = true, speed = 8,    curve = "snappy"  },
    --   { event = "windowsIn",     enabled = true, speed = 6,    curve = "snappy",  style = "popin 95%" },
    --   { event = "windowsOut",    enabled = true, speed = 5,    curve = "linear",  style = "popin 95%" },
    --   { event = "fadeIn",        enabled = true, speed = 6,    curve = "linear"  },
    --   { event = "fadeOut",       enabled = true, speed = 5,    curve = "linear"  },
    --   { event = "fade",          enabled = true, speed = 8,    curve = "quick"   },
    --   { event = "layers",        enabled = true, speed = 8,    curve = "snappy"  },
    --   { event = "layersIn",      enabled = true, speed = 6,    curve = "snappy",  style = "fade" },
    --   { event = "layersOut",     enabled = true, speed = 4,    curve = "linear",  style = "fade" },
    --   { event = "workspaces",    enabled = true, speed = 5,    curve = "snappy",  style = "fade" },
    --   { event = "workspacesIn",  enabled = true, speed = 4,    curve = "snappy",  style = "fade" },
    --   { event = "workspacesOut", enabled = true, speed = 4,    curve = "linear",  style = "fade" },
    -- },
  },

  -- --------------------------------------------------------
  -- INPUT
  -- --------------------------------------------------------
  input = {
    kb_layout    = "us",
    follow_mouse = 1, --0 click to focus, 1 focus follows mouse, 2 ffm clicking doesnt raise window, 3 ffm click focsus but does not pass click through
    sensitivity  = 0,

    repeat_rate  = 50,
    repeat_delay = 250,

    touchpad = {
      natural_scroll = false,
    },
  },

  -- --------------------------------------------------------
  -- MISC
  -- --------------------------------------------------------
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo   = true,
    disable_splash_rendering = true,
    vrr                     = 0,
  },

  -- --------------------------------------------------------
  -- DWINDLE
  -- --------------------------------------------------------
  dwindle = {
    preserve_split = true,
  },

  -- --------------------------------------------------------
  -- SCROLLING
  -- --------------------------------------------------------
  scrolling = {
    column_width            = 0.5,
    fullscreen_on_one_column = true,
    follow_focus            = true,
    follow_min_visible      = 0.4,
  },

})
