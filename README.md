# camarena-arch-setup

Automates reproduction of my Arch Linux desktop environment after a manual base install. Hyprland (custom Lua-config fork) + Quickshell (QML), retrowave/Win95-never-went-away aesthetic. Idempotent, staged, meant to be re-run safely.

## Stack

- **WM**: Hyprland 0.55.4, custom fork with a Lua config layer (`hl.*` namespace) instead of the stock keyword-file config
- **Shell**: Quickshell (QML), built from source — dashboard, taskbar, notifications, OSDs, rice switching
- **Session**: UWSM for systemd-managed session lifecycle, SDDM for login (custom retrowave theme)
- **GPU**: NVIDIA (nvidia-open), PRIME hybrid graphics with Intel iGPU on the laptop; discrete NVIDIA (RTX 4080) on the desktop
- **Terminal/editor**: Kitty, Neovim (lazy.nvim, native `vim.lsp.config`)
- **Other**: Yazi, Thunar, Vivaldi, Steam, Spotify (Flatpak), Discord, Teams (Flatpak), Surfshark (raw WireGuard, no client), cliphist+rofi, Xbox controller support (xpadneo, built from source)

Official Arch repos, source builds, or GitHub release tarballs only — no AUR helper anywhere in the install path.

## Structure

Layout will keep shifting as the project grows — treat directory *purpose* as the stable contract, not the exact file tree:

- **`scripts/`** — staged install scripts (`00`–`06`), run in order by `install.sh`. Each stage is independently idempotent; re-running `install.sh` after a partial or full install should be safe.
- **`config/`** — dotfiles copied into place by the dotfiles-copy stage. Mirrors real `~/.config` paths (`hypr/`, `quickshell/`, `sddm/`, etc.).
- **`packages/`** — plain-text package lists (`pacman-packages.txt`, `flatpak-packages.txt`, `vulkan-datum-packages.txt`), comment/blank-line filtered, installed with `--needed` so re-runs don't reinstall unchanged packages. All three lists are installed together by `01-package-preparation.sh`, in three logged sections (pacman → flatpak → aux/Vulkan-Datum) so a failure clearly reports which section it died in. `vulkan-datum-packages.txt` covers the Vulkan/graphics-driver toolchain for the separate Project Datum work; Project Datum's own code and flake live in their own repo, this one only installs its system-level package dependencies.
- **`fonts/`** — Departure Mono (OFL-licensed), installed to the system font path.
- **`install.sh`** — entry point, runs all staged scripts in order and sets `core.hooksPath` for the repo automatically. Self-deletes only after every stage passes, gated behind a safety check.

`scripts/lib/verify-repo.sh` is a repo linter, wired into the `pre-commit` git hook (`scripts/git-hooks/pre-commit`) so it runs automatically on every commit. Run it directly any time with `bash scripts/lib/verify-repo.sh`.

## Usage

    git clone https://github.com/ChandlerCamarena/camarena-arch-setup.git
    cd camarena-arch-setup
    ./install.sh

Run from a fresh Arch install with network access. Expect it to prompt for sudo where package installation or system-level file placement requires it.

## Theme

Everything visual — Hyprland borders/gaps, Quickshell panels, Yazi file manager, Kitty, Neovim, GTK apps (Thunar), and the SDDM login theme — reads from a single source of truth: `config/hypr/theme.json`. Each consumer has its own thin generator/loader that reads this file and produces its native config format (`theme.lua` for Hyprland, a `FileView`-backed singleton for QML, `jq`-driven template substitution for Yazi and GTK CSS, an `XMLHttpRequest`-based loader for the SDDM QML theme).

### Palette

| Name         | Hex       | Role                         |
| ------------ | --------- | ---------------------------- |
| `bg_dark`    | `#0d0f1a` | Base background              |
| `bg`         | `#1e2060` | Primary background           |
| `bg_surface` | `#252870` | Panel/surface background     |
| `bg_float`   | `#1a1c2e` | Floating panel background    |
| `coral`      | `#e8505b` | Primary accent               |
| `purple`     | `#9b6eb5` | Secondary accent             |
| `cyan`       | `#06afc7` | Tertiary / functional accent |
| `error`      | `#ff3fa4` | Error state                  |
| `warning`    | `#f0a050` | Warning state                |
| `fg`         | `#c8cae8` | Primary text                 |
| `fg_dim`     | `#8890b8` | Secondary text               |
| `fg_subtle`  | `#555880` | Tertiary text / disabled     |

Layout: flat, square, unrounded panels (`rounding: 0`), two-tone raised/sunken bevel borders instead of drop shadows or blur. Font: Departure Mono throughout, `Symbols Nerd Font` for icon glyphs.

### Rice switching

Multiple visual profiles ("rices") can coexist under `~/.config/rices/<name>/`, each with its own `theme.json` + `wallpaper.png` and an optional `apply.sh` for anything that needs more than a config regen (live-pushing colors to an already-running Kitty instance, for example). Switching repoints the active `theme.json`/wallpaper symlinks, regenerates every derived config, and reloads Hyprland. See `config/rices/scripts/switch.sh` for the actual sequencing — that script is the definitive list of what gets regenerated on every switch, more reliable than this README staying in sync with it.

## Hardware targets

Two machines currently tracked, both from the same repo without forking:

- **Laptop**: NVIDIA GTX 1650 Mobile + Intel iGPU (PRIME hybrid), 4K 15" panel at 1.5x scale
- **Desktop (`prometheus`)**: Intel Core i9-13900K, discrete NVIDIA RTX 4080, 1440p

PRIME/NVIDIA environment variables are gated behind a hostname check in `uwsm/env-hyprland`, so the same config works unmodified across both.

## License

See `LICENSE`. Departure Mono is separately licensed under the OFL — see `fonts/OFL.txt`. The SDDM theme (`config/sddm/retrowave/`) is derived from Sanjeev Premi's "maya" theme, MIT-licensed — original license retained at `config/sddm/retrowave/LICENSE`.
