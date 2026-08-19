-- theme.lua
-- Thin loader over ~/.config/hypr/theme.json. This file has no
-- hardcoded color values of its own -- theme.json is the single
-- source of truth, this just reads it and wraps values in the
-- rgb()/rgba() string forms Hyprland's Lua config expects.
--
-- Runs once per require() (Hyprland startup / hyprctl reload), so
-- the io.popen + jq cost here is irrelevant -- this is not a hot path
-- like SystemStats.qml's timers.

local M = {}

local THEME_JSON_PATH = os.getenv("HOME") .. "/.config/hypr/theme.json"

-- Hardcoded fallback so a missing/malformed theme.json can't take
-- down the entire Hyprland config load. Mirrors the values that were
-- in theme.json at the time this loader was written; if you change
-- the palette, these will drift out of date but the shell.qml/QML
-- side reads theme.json directly and doesn't have this problem, so
-- only theme.lua is exposed to this risk.
local DEFAULTS = {
  colors = {
    bg = "1e2060", bg_dark = "0d0f1a", bg_surface = "252870",
    bg_float = "1a1c2e", border_inactive = "2e328055",
    coral = "e8505b", coral_dim = "a03840",
    purple = "9b6eb5", purple_dim = "6b4e80",
    cyan = "06afc7", cyan_dim = "047a8c",
    error = "ff3fa4", warning = "f0a050",
    fg = "c8cae8", fg_dim = "8890b8", fg_subtle = "555880",
    shadow = "0d0f1a99",
  },
  bevel = {
    raised_light = "3a3e9c", raised_dark = "10122a",
    sunken_light = "10122a", sunken_dark = "3a3e9c", width = 4,
  },
  layout = { border_size = 3, rounding = 0, gaps_in = 2, gaps_out = 2 },
  font = { family = "Departure Mono", icon_family = "Symbols Nerd Font", size_base = 14 },
  terminal_opacity = 0.85,
}

-- Sets t[a][b][...] = value, creating intermediate tables as needed.
-- keyPath is e.g. {"colors", "bg"} or {"terminal_opacity"} for a
-- top-level scalar.
local function setPath(t, keyPath, value)
  local node = t
  for i = 1, #keyPath - 1 do
    local k = keyPath[i]
    node[k] = node[k] or {}
    node = node[k]
  end
  node[keyPath[#keyPath]] = value
end

-- Splits "a.b.c" into {"a", "b", "c"}.
local function splitDots(s)
  local parts = {}
  for part in string.gmatch(s, "[^.]+") do
    table.insert(parts, part)
  end
  return parts
end

local function loadFromJson()
  -- jq flattens every scalar leaf in the JSON into "dotted.path = value"
  -- lines, e.g. "colors.bg = 1e2060" or "terminal_opacity = 0.85".
  -- One process spawn, one parse pass, no per-field popen calls.
  local cmd = string.format(
    "jq -r 'paths(scalars) as $p | \"\\($p | join(\".\")) = \\(getpath($p))\"' %q 2>/dev/null",
    THEME_JSON_PATH
  )

  local handle = io.popen(cmd)
  if not handle then
    print("[theme.lua] Warning: could not spawn jq, falling back to built-in defaults")
    return nil
  end

  local output = handle:read("*a")
  -- Deliberately NOT gating on handle:close()'s return value here.
  -- Stock PUC-Lua's io.popen():close() returns true/exit-status on
  -- success, but Hyprland's embedded Lua sandboxes/wraps io.popen
  -- and its close() does not reliably return that same tuple shape
  -- (confirmed: jq produces correct output standalone, but close()
  -- was reporting failure even then). The actual line count parsed
  -- out of `output` below is the real success signal, not close().
  handle:close()

  if not output or output == "" then
    print("[theme.lua] Warning: jq produced no output for "
      .. THEME_JSON_PATH .. ", falling back to built-in defaults")
    return nil
  end

  local data = {}
  local lineCount = 0
  for line in string.gmatch(output, "[^\r\n]+") do
    local keyPart, valuePart = string.match(line, "^(.-)%s=%s(.*)$")
    if keyPart then
      setPath(data, splitDots(keyPart), valuePart)
      lineCount = lineCount + 1
    end
  end

  if lineCount == 0 then
    print("[theme.lua] Warning: theme.json parsed but yielded no fields, falling back to built-in defaults")
    return nil
  end

  return data
end

local data = loadFromJson() or DEFAULTS

-- --------------------------------------------------------
-- RAW COLOR TABLE
-- Same field names as theme.json's "colors" object, unwrapped.
-- --------------------------------------------------------
local c = data.colors or DEFAULTS.colors

-- --------------------------------------------------------
-- BACKGROUND FAMILY
-- --------------------------------------------------------
M.bg         = "rgb(" .. c.bg .. ")"
M.bg_dark    = "rgb(" .. c.bg_dark .. ")"
M.bg_surface = "rgb(" .. c.bg_surface .. ")"
M.bg_float   = "rgb(" .. c.bg_float .. ")"

-- --------------------------------------------------------
-- BORDER COLORS
-- NOTE: border_active still produces a coral->purple gradient here,
-- matching the pre-flat-bevel-pivot behavior. Your notes say the
-- gradient active border was explicitly dropped in favor of flat
-- bevel edges only -- if options.lua's active_border usage has since
-- moved to a flat bevel color instead of this gradient, this block
-- needs updating to match (and is a rules/options.lua-level decision,
-- not something this loader should silently guess at).
-- --------------------------------------------------------
M.border_active = {
  colors = { "rgba(" .. c.coral .. "ee)", "rgba(" .. c.purple .. "ee)" },
  angle  = 45,
}
M.border_inactive = "rgba(" .. c.border_inactive .. ")"

-- --------------------------------------------------------
-- PRIMARY ACCENT -- coral
-- --------------------------------------------------------
M.coral     = "rgb(" .. c.coral .. ")"
M.coral_dim = "rgb(" .. c.coral_dim .. ")"

-- --------------------------------------------------------
-- SECONDARY ACCENT -- purple
-- --------------------------------------------------------
M.purple     = "rgb(" .. c.purple .. ")"
M.purple_dim = "rgb(" .. c.purple_dim .. ")"

-- --------------------------------------------------------
-- TERTIARY / FUNCTIONAL -- cyan
-- --------------------------------------------------------
M.cyan     = "rgb(" .. c.cyan .. ")"
M.cyan_dim = "rgb(" .. c.cyan_dim .. ")"

-- --------------------------------------------------------
-- FUNCTIONAL COLORS
-- --------------------------------------------------------
M.error   = "rgb(" .. c.error .. ")"
M.warning = "rgb(" .. c.warning .. ")"
M.success = M.cyan

-- --------------------------------------------------------
-- NEUTRALS
-- --------------------------------------------------------
M.fg        = "rgb(" .. c.fg .. ")"
M.fg_dim    = "rgb(" .. c.fg_dim .. ")"
M.fg_subtle = "rgb(" .. c.fg_subtle .. ")"

-- --------------------------------------------------------
-- SHADOW
-- --------------------------------------------------------
M.shadow = "rgba(" .. c.shadow .. ")"

-- --------------------------------------------------------
-- LAYOUT / BEVEL / FONT
-- Exposed raw (not string-wrapped) since options.lua and rules.lua
-- consume these as numbers/strings directly, not as color literals.
-- --------------------------------------------------------
M.bevel  = data.bevel  or DEFAULTS.bevel
M.layout = data.layout or DEFAULTS.layout
M.font   = data.font   or DEFAULTS.font

-- --------------------------------------------------------
-- TERMINAL OPACITY
-- jq emits this as a string ("0.85"), cast back to a Lua number
-- since kitty.conf generation / any numeric use expects a number.
-- --------------------------------------------------------
M.terminal_opacity = tonumber(data.terminal_opacity) or DEFAULTS.terminal_opacity

return M
