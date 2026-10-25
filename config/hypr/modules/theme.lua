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

-- Active rice first (a symlink, see config/rices/scripts/switch.sh), then
-- the default rice's own file if that link is broken. No hardcoded palette
-- here: a second copy of the colors would only drift from theme.json.
local THEME_JSON_PATHS = {
  os.getenv("HOME") .. "/.config/hypr/theme.json",
  os.getenv("HOME") .. "/.config/rices/retrowave/theme.json",
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

local function loadFromJson(path)
  -- jq flattens every scalar leaf in the JSON into "dotted.path = value"
  -- lines, e.g. "colors.bg = 1e2060" or "terminal_opacity = 0.85".
  -- One process spawn, one parse pass, no per-field popen calls.
  local cmd = string.format(
    "jq -r 'paths(scalars) as $p | \"\\($p | join(\".\")) = \\(getpath($p))\"' %q 2>/dev/null",
    path
  )

  local handle = io.popen(cmd)
  if not handle then
    print("[theme.lua] Warning: could not spawn jq for " .. path)
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
    print("[theme.lua] Warning: jq produced no output for " .. path)
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
    print("[theme.lua] Warning: " .. path .. " parsed but yielded no fields")
    return nil
  end

  return data
end

local data
for _, path in ipairs(THEME_JSON_PATHS) do
  data = loadFromJson(path)
  if data then break end
end
if not data then
  error("[theme.lua] no readable theme.json (tried " .. table.concat(THEME_JSON_PATHS, ", ")
    .. "); rerun update.sh or config/rices/scripts/switch.sh <rice>")
end

-- --------------------------------------------------------
-- RAW COLOR TABLE
-- Same field names as theme.json's "colors" object, unwrapped.
-- --------------------------------------------------------
local c = data.colors

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
M.bevel  = data.bevel
M.layout = data.layout
M.font   = data.font

-- --------------------------------------------------------
-- TERMINAL OPACITY
-- jq emits this as a string ("0.85"), cast back to a Lua number
-- since kitty.conf generation / any numeric use expects a number.
-- --------------------------------------------------------
M.terminal_opacity = tonumber(data.terminal_opacity)

return M
