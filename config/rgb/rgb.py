#!/usr/bin/env python3
"""rgb.py - declarative OpenRGB profiles applied over the SDK.

Talks to the long-running `openrgb --server` (openrgb.service) instead of
spawning the openrgb CLI, which does its own hardware detection and knocks
Direct-mode Corsair controllers back to their firmware lighting on exit.

Profiles live in ~/.config/rgb/profiles/<name>.json:

    {
      "default": {"mode": "static", "color": "bg"},
      "devices": {
        "Commander Core": {"mode": "direct", "zones": {"Pump": "error"}},
        "K100":           {"leds": {"Key: W": "error"}}
      }
    }

- "devices" keys are case-insensitive substrings of the device name; the
  first match wins and is layered over "default".
- "mode" is a mode name (case-insensitive). If the device lacks it, Direct
  is used. "off" is special: Off mode if present, else Static black, else
  Direct black (Gigabyte IT5701 boards ignore Direct black, hence Static).
- Colors are a theme.json role ("bg", "error", ...) or a literal "#rrggbb".
- "zones" / "leds" override colors per zone/LED name (substring / exact).
"""
import json
import sys
import time
from pathlib import Path

from openrgb import OpenRGBClient
from openrgb.utils import OpenRGBDisconnected, RGBColor

RGB_DIR = Path.home() / ".config/rgb"
PROFILES = RGB_DIR / "profiles"
ACTIVE = RGB_DIR / "active"
THEME = Path.home() / ".config/hypr/theme.json"
DEFAULT_PROFILE = "purple"
TOGGLE_ON = "purple"

BLACK = RGBColor(0, 0, 0)


def die(msg):
    print(f"rgb: {msg}", file=sys.stderr)
    sys.exit(1)


def available_profiles():
    return sorted(p.stem for p in PROFILES.glob("*.json"))


def read_active():
    try:
        return ACTIVE.read_text().strip() or DEFAULT_PROFILE
    except FileNotFoundError:
        return DEFAULT_PROFILE


def theme_colors():
    try:
        return json.loads(THEME.read_text())["colors"]
    except (FileNotFoundError, KeyError, json.JSONDecodeError):
        return {}


def resolve_color(value, theme):
    hexstr = value[1:] if value.startswith("#") else theme.get(value)
    if hexstr is None:
        die(f"unknown color role '{value}' (not in {THEME})")
    return RGBColor.fromHEX(hexstr[:6])


def find_mode(dev, name):
    for m in dev.modes:
        if m.name.lower() == name.lower():
            return m.name
    return None


def connect(retries=40):
    for _ in range(retries):
        try:
            client = OpenRGBClient(name="rgb.py")
            break
        except (ConnectionRefusedError, TimeoutError, OSError):
            time.sleep(0.5)
    else:
        die("could not reach OpenRGB server on localhost:6742 (is openrgb.service running?)")

    # At boot the SDK port opens before detection finishes; wait until the
    # device count is non-zero and unchanged across two polls.
    last = -1
    for _ in range(retries):
        count = len(client.devices)
        if count and count == last:
            return client
        last = count
        time.sleep(0.5)
        client.update()
    return client


def apply_device(dev, rule, theme):
    mode = rule.get("mode", "direct")

    if mode.lower() == "off":
        if find_mode(dev, "Off"):
            dev.set_mode("Off")
            return "Off"
        target = find_mode(dev, "Static") or find_mode(dev, "Direct")
        dev.set_mode(target)
        dev.set_color(BLACK)
        return f"{target} black"

    target = find_mode(dev, mode) or find_mode(dev, "Direct")
    if target is None:
        return "skipped (no usable mode)"
    dev.set_mode(target)

    if "color" in rule:
        dev.set_color(resolve_color(rule["color"], theme))
    for zname, col in rule.get("zones", {}).items():
        for z in dev.zones:
            if zname.lower() in z.name.lower():
                z.set_color(resolve_color(col, theme))
    leds = rule.get("leds", {})
    if leds:
        colors = list(dev.colors)
        for i, led in enumerate(dev.leds):
            if led.name in leds:
                colors[i] = resolve_color(leds[led.name], theme)
        dev.set_colors(colors)
    return target


def apply(name):
    path = PROFILES / f"{name}.json"
    if not path.exists():
        die(f"no profile '{name}' (have: {', '.join(available_profiles())})")
    profile = json.loads(path.read_text())
    theme = theme_colors()
    client = connect()

    for i in range(len(client.devices)):
        dev = client.devices[i]
        rule = dict(profile.get("default", {}))
        for key, override in profile.get("devices", {}).items():
            if key.lower() in dev.name.lower():
                rule.update(override)
                break
        try:
            result = apply_device(dev, rule, theme)
        except OpenRGBDisconnected:
            # Corsair hardware<->Direct mode switches can stall the server
            # past the SDK timeout; a fresh connection then succeeds.
            client = connect()
            dev = client.devices[i]
            result = apply_device(dev, rule, theme) + " (retried)"
        print(f"  {dev.name}: {result}")

    ACTIVE.write_text(name + "\n")
    print(f"rgb: {name}")


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if arg in ("-h", "--help"):
        print(f"usage: rgb [toggle|apply|status|list|<profile>]\nprofiles: {', '.join(available_profiles())}")
    elif arg == "toggle":
        apply(TOGGLE_ON if read_active() == "off" else "off")
    elif arg == "apply":
        apply(read_active())
    elif arg == "status":
        print(read_active())
    elif arg == "list":
        print("\n".join(available_profiles()))
    else:
        apply(arg)


if __name__ == "__main__":
    main()
