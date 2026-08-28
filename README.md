# camarena-arch-setup

Single source of truth for my Arch Linux desktop environment.

Automates full reproduction of a Hyprland + Quickshell desktop, from a bare Arch base install through a fully configured, themed, running system. Idempotent and staged: re-running `install.sh` at any point should be safe and should converge the machine toward what the repo describes.

## Stack

- **WM**: Hyprland, custom fork with a Lua config layer (`hl.*` namespace) instead of the stock keyword-file config
- **Shell**: Quickshell (QML), built from source — dashboard, taskbar, notifications, OSDs, rice switching
- **Session**: UWSM for systemd-managed session lifecycle, SDDM for login (custom retrowave QML theme, reads `theme.json` live)
- **GPU**: NVIDIA (`nvidia-open`), PRIME hybrid graphics on the laptop target; discrete NVIDIA (RTX 4080) on the desktop target (`prometheus`)
- **Filesystem**: btrfs on both root drives, `@`/`@home`/`@log`/`@pkg`/`@snapshots` subvolume layout, snapper-managed, systemd-boot
- **Terminal/editor**: Kitty, Neovim (lazy.nvim, native `vim.lsp.config`)
- **Shell environment**: zsh via oh-my-zsh, powerlevel10k prompt, `ZDOTDIR` relocated to `~/.config/zsh`
- **File management**: Yazi (terminal), Thunar (GUI)
- **Browser**: Vivaldi
- **Launcher**: Rofi, custom retrowave-themed launcher and power menu
- **Communication**: Discord, Teams (Flatpak), Spotify (Flatpak)
- **Gaming**: Steam, MangoHud (multilib)
- **VPN**: Surfshark via raw WireGuard configs — no GUI/CLI client installed
- **Peripherals**: Xbox controller support via xpadneo, built from source (DKMS)

Official Arch repos, source builds, or GitHub release tarballs only — no AUR helper anywhere in the install path.

## Structure

- **`scripts/`** — staged install scripts (`00`–`06`), run in order by `install.sh`. Each stage is independently idempotent.
  - `00-preflight.sh` — connectivity/sudo checks, snapper pre-transaction hook install
  - `01-package-preparation.sh` — pacman (incl. multilib enablement), flatpak, and Vulkan/Datum aux packages, in three logged sections
  - `02-build-from-source.sh` — Quickshell, grimblast, xpadneo
  - `03-nix-install.sh` — Determinate Systems installer, flakes/devShells only (never used for system/DE management)
  - `04-fonts.sh` — Departure Mono
  - `05-dotfiles-copy.sh` — all config, oh-my-zsh + powerlevel10k, theme generation
  - `06-services.sh` — SDDM theme deployment, service enablement
- **`config/`** — dotfiles copied into place. Mirrors real `~/.config` paths.
- **`packages/`** — plain-text package lists (`pacman-packages.txt`, `flatpak-packages.txt`, `vulkan-datum-packages.txt`), comment/blank-line filtered, installed with `--needed`.
- **`fonts/`** — Departure Mono (OFL-licensed).
- **`install.sh`** — entry point. Sets `core.hooksPath` automatically, runs all staged scripts in order. Self-deletes only after every stage passes, gated behind a safety check.

`scripts/lib/verify-repo.sh` is a repo linter wired into the `pre-commit` git hook — checks `copy_plain` sources exist, package-list naming for AUR-suspicious patterns, README stage-range accuracy, and script header conventions.

## Before you start

This repo assumes you're picking up *after* a working, booted, networked Arch base install. It does not partition disks, run `pacstrap`, or configure a bootloader — that's manual, deliberate, and done once per machine before this repo ever gets cloned.

**Prerequisites, in order:**

1. **Partition and format** — btrfs on the root partition with a `@`/`@home`/`@log`/`@pkg`/`@snapshots` subvolume layout (see Hardware targets below for per-machine partition assignments), FAT32 EFI partition, swap.
2. **`pacstrap` the base system** — `base linux linux-firmware btrfs-progs sudo vim networkmanager intel-ucode` at minimum.
3. **`genfstab` + `arch-chroot`.**
4. **Inside chroot:** locale, hostname, root password, timezone (`ln -sf /usr/share/zoneinfo/<zone> /etc/localtime && hwclock --systohc` — `timedatectl` does not work inside a chroot), NVIDIA driver + `mkinitcpio` modules, systemd-boot (**double-check `rootflags=subvol=@` uses an equals sign, not a hyphen** — this exact typo has broken a boot before), user creation with `wheel` + `visudo`.
5. **Reboot, remove install media, log in as the created user.**
6. **Connectivity** — confirm before doing anything else:
## Usage

    git clone https://github.com/ChandlerCamarena/camarena-arch-setup.git
    cd camarena-arch-setup
    ./install.sh

Run from a fresh Arch base install (post-`pacstrap`, post-chroot, already booted) with network access. Will prompt for sudo where needed.

## Updating an existing machine

`update.sh` (planned — see Future Work) will reconcile a live machine against the repo: remove locally-managed config paths, re-copy from the repo, and re-run generators. Until it exists, re-running `install.sh` is the interim path — it's idempotent and will overwrite existing dotfiles with the repo's current versions, though it won't remove files the repo no longer manages.

## Theme

Everything visual — Hyprland borders/gaps, Quickshell panels, Yazi, Kitty, Neovim, GTK apps, and the SDDM login screen — reads from a single source of truth: `config/hypr/theme.json`. Each consumer has a thin generator/loader that reads this file and produces its native config format.

**Not yet on this pattern:** `config/rofi/colors/retrowave.rasi` still has hardcoded hex values rather than generating from `theme.json` — same drift risk the SDDM theme had before it was fixed. Tracked in Future Work.

### Palette

| Name         | Hex       | Role                         |
| ------------ | --------- | ----------------------------- |
| `bg_dark`    | `#0d0f1a` | Base background               |
| `bg`         | `#1e2060` | Primary background            |
| `bg_surface` | `#252870` | Panel/surface background      |
| `bg_float`   | `#1a1c2e` | Floating panel background     |
| `coral`      | `#e8505b` | Primary accent                |
| `purple`     | `#9b6eb5` | Secondary accent              |
| `cyan`       | `#06afc7` | Tertiary / functional accent  |
| `error`      | `#ff3fa4` | Error state                   |
| `warning`    | `#f0a050` | Warning state                 |
| `fg`         | `#c8cae8` | Primary text                  |
| `fg_dim`     | `#8890b8` | Secondary text                |
| `fg_subtle`  | `#555880` | Tertiary text / disabled      |

Layout: flat, square, unrounded panels (`rounding: 0`), two-tone raised/sunken bevel borders instead of drop shadows or blur. Font: Departure Mono throughout, `Symbols Nerd Font` for icon glyphs.

### Rice switching

Multiple visual profiles under `~/.config/rices/<name>/`, each with `theme.json` + `wallpaper.png` and an optional `apply.sh`. Switching repoints symlinks, regenerates every derived config, reloads Hyprland. See `config/rices/scripts/switch.sh` for the authoritative sequencing.

## Hardware targets

- **Laptop**: NVIDIA GTX 1650 Mobile + Intel iGPU (PRIME hybrid), 4K 15" panel at 1.5x scale
- **Desktop (`prometheus`)**: Intel Core i9-13900K, discrete NVIDIA RTX 4080, 1440p

PRIME/NVIDIA environment variables are hostname-gated in `uwsm/env-hyprland`, so the same config works unmodified across both.

## Known limitations

- **Snapper rollback is not functional on this setup.** Snapper 0.13.1 cannot auto-detect a rollback "ambit" with a systemd-boot + standard `@`-subvolume layout (no grub-btrfs-style integration). Setting a btrfs default subvolume and stripping explicit `subvol=` from fstab/boot entry makes ambit detection pass the precondition check but rollback still fails in practice. Treat snapper snapshots as manual diff/reference points only. A real reset requires the manual btrfs subvolume delete-and-recreate procedure from a live USB.
- **`00-preflight.sh` installs the snapshot pacman hook but does not run `snapper -c root create-config /`.** Without a snapper config already present, the hook is inert. Currently a manual step post-install.

## Future work

- **`update.sh`** — reconciliation script for already-installed machines. Deletes repo-managed config paths under `~/.config` and rebuilds from the current repo state, rather than requiring a fresh install to pick up changes.
- **Apply-live theme switching** — regenerate and push theme changes to already-running Hyprland/Quickshell/Kitty instances without a full reload, where the target supports it (Kitty already supports live color pushes via its remote-control socket; others don't yet).
- **Vivaldi config in-repo** — not currently tracked; profile/settings reproduction is manual.
- **Install profiles / flags** — `install.sh --profile gaming` / `--profile work` or similar, to include/exclude package sets (e.g. Steam/MangoHud vs. a leaner work-only install) without maintaining separate package lists by hand.
- **`retrowave.rasi` on the `theme.json` pattern** — currently hardcoded, should generate like every other consumer.
- **Automate snapper `create-config`** — fold into `00-preflight.sh` so the snapshot hook has something to act on immediately post-install, rather than requiring a manual step.
- **Custom icon theme** — full custom set matching the sharp/bevel aesthetic. Deferred, multi-session scope.
- **PPI-aware `monitors.lua`** — deferred until validated on a real two-display setup. Correct approach identified: read EDID from `/sys/class/drm/*/edid` directly, since `hl.get_monitors()` has no physical size fields and `io.popen("hyprctl ...")` from inside a config reload deadlocks against Hyprland's own IPC socket.

## License

See `LICENSE`. Departure Mono is separately licensed under the OFL — see `fonts/OFL.txt`. The SDDM theme (`config/sddm/retrowave/`) is derived from Sanjeev Premi's "maya" theme, MIT-licensed — original license retained at `config/sddm/retrowave/LICENSE`.
