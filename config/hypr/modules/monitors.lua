-- monitors.lua
-- Detects connected outputs and configures them automatically.
-- No output names are hardcoded. Works on laptop, TV, and desktop.
--
-- PPI DETECTION: as of Hyprland 0.56, hl.get_monitors() exposes
-- physical_width / physical_height directly on the monitor object
-- (confirmed against /usr/share/hypr/stubs/hl.meta.lua and live
-- values matching the real panel). This means real PPI math can
-- run entirely in-process, no io.popen()/hyprctl round-trip, so
-- the IPC-deadlock-from-inside-reload problem that previously
-- forced a hardcoded resolution table no longer applies here.

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

-- Real PPI-derived scale, computed in-process from mon.physical_width
-- / mon.physical_height (mm) and mon.width / mon.height (px). No
-- hardcoded per-resolution table: any monitor with sane EDID physical
-- dimensions gets a correct scale automatically.
--
-- Thresholds match the previous manually-tuned table: >150 PPI -> 1.5,
-- >110 PPI -> 1.25, else 1.0. Verified against the real desktop panel
-- (MSI MAG321CQR, 700x390mm, 2560x1440): computes to 93.1 PPI -> 1.0,
-- matching the value that was previously hardcoded after the 0.8
-- fractional-scale experiment broke things.
-- Manual calibration override. Live-tuned by eye against the
-- laptop, not derived from PPI/distance math -- multiple attempts
-- at a deterministic PPI-based or distance-based formula were
-- tried and none reproduced this value (see git history / chat
-- notes), so this is stored as a direct calibrated constant. Keyed
-- by output name since DP-2 is this specific monitor's stable
-- connector name.
local SCALE_OVERRIDES = {
  -- DP-2 was tuned to 0.67 for higher density, but Hyprland has a
  -- known unresolved bug (hyprwm/Hyprland discussion #12609) where
  -- scale < 1.0 renders window content smaller than its tile,
  -- leaving blank space -- reproduced exactly with Vivaldi not
  -- filling its half-screen tile. This monitor's own EDID-advertised
  -- modes cap at native 2560x1440, so a custom higher-resolution
  -- mode (to get density via scale-up instead of scale-down) isn't
  -- a safe option either -- would require forcing an unsupported
  -- custom timing. Reverted to 1.0, which is also what auto_scale's
  -- PPI math computes on its own for this panel (93.1 PPI), so this
  -- override is currently redundant but left in place as a documented
  -- decision in case scale-down gets fixed upstream later.
  ["DP-2"] = 1.0,
}

local function auto_scale(mon)
  if SCALE_OVERRIDES[mon.name] then
    local scale = SCALE_OVERRIDES[mon.name]
    debug_log(tostring(mon.name) .. " -> scale " .. scale .. " (manual override)")
    return scale
  end

  local w  = mon.width
  local h  = mon.height
  local pw = mon.physical_width
  local ph = mon.physical_height

  if not pw or not ph or pw == 0 or ph == 0 then
    debug_log(tostring(mon.name) .. " missing/zero physical dimensions, defaulting to scale 1.0")
    return 1.0
  end

  local diagonal_mm     = math.sqrt(pw * pw + ph * ph)
  local diagonal_inches = diagonal_mm / 25.4
  local ppi             = math.sqrt(w * w + h * h) / diagonal_inches

  local scale
  if ppi > 150 then
    scale = 1.5
  elseif ppi > 110 then
    scale = 1.25
  else
    scale = 1.0
  end

  debug_log(tostring(mon.name) .. " " .. tostring(w) .. "x" .. tostring(h)
    .. " physical " .. tostring(pw) .. "x" .. tostring(ph) .. "mm"
    .. " -> ppi " .. string.format("%.1f", ppi) .. " -> scale " .. scale)

  return scale
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
      -- No lookup table anymore (removed with the resolution-keyed
      -- approach), so the safe fallback is just a flat 1.0 rather
      -- than a per-resolution value.
      local safe = 1.0
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

-- Regenerate hyprlock.conf for the new resolution/scale after any
-- monitor change. Safe to call here: this runs from the
-- monitor.added/removed event handler, not from inside a config
-- reload, so it does not hit the hyprctl-from-reload IPC deadlock
-- documented above for auto_scale.
local function regenerate_hyprlock()
  hl.exec_cmd("bash ~/.config/hypr/scripts/generation/generate-hyprlock.sh >/tmp/generate-hyprlock.log 2>&1")
end

-- Run when a monitor is plugged in
hl.on("monitor.added", function(mon)
  configure_monitors()
  regenerate_hyprlock()
end)

-- Run when a monitor is unplugged
hl.on("monitor.removed", function(mon)
  configure_monitors()
  regenerate_hyprlock()
end)
