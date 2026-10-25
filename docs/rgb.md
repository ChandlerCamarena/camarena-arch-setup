# RGB (OpenRGB)

Declarative profiles on top of the OpenRGB SDK server. Deployed only when
`openrgb` is installed (`rgb` profile).

## Use

```
rgb             # toggle off <-> purple
rgb off         # alias: lightsoff
rgb purple      # alias: lightson
rgb theme       # colors from the current rice's theme.json
rgb apply       # re-apply the last profile (e.g. after a rice switch)
rgb status      # last applied profile
rgb list        # available profiles
```

The last profile is remembered in `~/.config/rgb/active` and re-applied
whenever `openrgb.service` starts (login).

## Files

| Path                                       | What                                         |
| ------------------------------------------ | -------------------------------------------- |
| `~/.config/rgb/profiles/*.json`            | profiles (repo: `config/rgb/profiles/`)      |
| `~/.config/rgb/rgb.py`                     | applier                                      |
| `~/.local/bin/rgb`                         | wrapper, runs rgb.py in `~/.config/rgb/venv` (openrgb-python) |
| `~/.config/systemd/user/openrgb.service`   | `openrgb --server`, then `rgb apply`         |
| `/etc/modules-load.d/i2c-rgb.conf`         | i2c modules the RAM (ENE DRAM) needs         |

## Writing a profile

```json
{
  "default": {"mode": "static", "color": "bg"},
  "devices": {
    "Commander Core": {"mode": "direct", "zones": {"Pump": "error"}},
    "NVIDIA":         {"mode": "direct", "color": "#ffffff"},
    "K100":           {"mode": "direct", "leds": {"Key: W": "error"}}
  }
}
```

- `default` applies to every device. A `devices` entry whose key appears in the
  device name (case-insensitive, first match wins) is layered on top.
- `mode`: any mode the device has (`rgb` falls back to Direct if it lacks it).
  `"off"` is special. It uses the device's Off mode, else Static black, else
  Direct black. Override per device when a controller needs something specific
  (`off.json` pins Corsair to Direct black).
- `color`: a `theme.json` role (`bg`, `coral`, `error`, ...) or `#rrggbb`.
- `zones`: per-zone colors, zone name substring → color.
- `leds`: per-LED colors, exact LED name → color.

Device, zone and LED names: `~/.config/rgb/venv/bin/python -c "from openrgb import
OpenRGBClient; [print(d.name, [z.name for z in d.zones]) for d in OpenRGBClient().devices]"`

Add a profile by dropping a new JSON file in `config/rgb/profiles/` and
adding a `copy_plain` line for it in `scripts/05-dotfiles-copy.sh`.

## Gotchas

- **Never use the `openrgb` CLI while the service runs.** It does its own
  hardware detection, and when it exits the Corsair Commander Core / Lighting Node
  fall back to their firmware rainbow. Use `rgb`, which talks to the server.
- **Gigabyte IT5701 motherboard (Z790 AORUS) ignores Direct-mode black.** That's why
  the old OpenRGB-profile `off` left it lit. `"off"` uses Static black for it.
- Corsair mode switches can stall the server for a second or two. `rgb`
  reconnects and retries the device once, and the output shows `(retried)`.
