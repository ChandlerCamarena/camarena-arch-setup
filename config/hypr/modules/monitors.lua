-- monitors.lua
-- Detects connected outputs and configures them automatically.
-- No output names are hardcoded. Works on laptop, TV, and desktop.
--
-- PPI DETECTION: hl.get_monitors() does NOT expose physical size
-- (confirmed via hl.meta.lua's HL.Monitor class -- no such field).
-- hyprctl monitors -j DOES have physicalWidth/physicalHeight, but
-- shelling out to hyprctl from inside a config reload deadlocks/
-- times out the Hyprland IPC -- confirmed reproducibly, not a
-- one-off. Reload holds the IPC while running this Lua; calling
-- back into hyprctl from inside that same reload fights itself for
-- the socket. Do NOT reintroduce an io.popen() call to hyprctl
-- here. If real PPI detection is wanted later, it needs a source
-- that doesn't round-trip through Hyprland's own IPC, e.g. reading
-- EDID directly from /sys/class/drm/*/edid via edid-decode.
--
-- Until that's built, this is a resolution-keyed lookup table, not
-- true PPI math. Documented as such rather than dressed up as
-- detection.

-- Guard clause: Prevent standalone CLI execution from crashing
if not hl then
  print("[Hyprland Config] Warning: 'hl' global not found. This file must be loaded by Hyprland, not the standard Lua CLI.")
  return
end

-- Debug file logging. print() output does not reach journald in
-- this fork (confirmed: fd 1/2 correctly wired to journald, but
-- Lua print() never lands there regardless of debug.enable_stdout_logs).
-- Write straight to a file instead.
local function debug_log(msg)
  local f = io.open("/tmp/monitor-scale-debug.log", "a")
  if f then
    f:write(os.date() .. " " .. msg .. "\n")
    f:close()
  end
end

-- Resolution-keyed scale table. Not PPI-derived -- see note above
-- on why real physical-size detection isn't safely available from
-- inside Hyprland's Lua config reload path.
local SCALE_BY_RESOLUTION = {
  ["3840x2160"] = 1.5,  -- prometheus 4K 15" laptop panel
  ["2560x1440"] = 1.0,  -- RTX 4080 desktop monitor (Aug 2026) -- verify against real panel size before trusting this
  ["1920x1080"] = 1.0,
}

local function auto_scale(mon)
  local w = mon.width
  local h = mon.height
  local key = tostring(w) .. "x" .. tostring(h)
  local scale = SCALE_BY_RESOLUTION[key]

  if scale then
    debug_log(tostring(mon.name) .. " " .. key .. " -> scale " .. scale .. " (table)")
    return scale
  end

  debug_log(tostring(mon.name) .. " " .. key .. " -> no table entry, defaulting to scale 1.0")
  return 1.0
end

local function configure_monitors()
  local monitors = hl.get_monitors()

  for _, mon in ipairs(monitors) do
    local target_scale = auto_scale(mon)

    local ok, err = pcall(function()
      hl.monitor({
        output   = mon.name,
        mode     = "preferred",
        position = "auto",
        scale    = target_scale,
      })
    end)

    if not ok then
      local key = tostring(mon.width) .. "x" .. tostring(mon.height)
      local safe = SCALE_BY_RESOLUTION[key] or 1.0
      debug_log("  -> DISPATCH ERROR for " .. tostring(mon.name) .. ": " .. tostring(err)
        .. ". Retrying with safe scale " .. safe .. ".")
      pcall(function()
        hl.monitor({
          output   = mon.name,
          mode     = "preferred",
          position = "auto",
          scale    = safe,
        })
      end)
    end
  end
end

-- Run on startup
configure_monitors()

-- Run when a monitor is plugged in
hl.on("monitor.added", function(mon)
  configure_monitors()
end)

-- Run when a monitor is unplugged
hl.on("monitor.removed", function(mon)
  configure_monitors()
end)
