# camarena-arch-setup

Single source of truth for my Arch Linux desktop environment.

Automates full reproduction of a Hyprland + Quickshell desktop, from a bare Arch base install through a fully configured, themed, running system. Idempotent and staged: re-running `install.sh` at any point should be safe and should converge the machine toward what the repo describes.

## Stack

- **WM**: Hyprland (official package), configured in Lua (`hyprland.lua`, `hl.*` API) rather than the older keyword-file config
- **Shell**: Quickshell (QML), built from source — dashboard, taskbar, notifications, OSDs, rice switching
- **Session**: UWSM for systemd-managed session lifecycle, SDDM for login (custom retrowave QML theme, reads `theme.json` live)
- **GPU**: NVIDIA (`nvidia-open`), PRIME hybrid graphics on the laptop target
- **Filesystem**: btrfs on both root drives, `@`/`@home`/`@log`/`@pkg`/`@snapshots` subvolume layout, snapper-managed, systemd-boot
- **Terminal/editor**: Kitty, Neovim (see Editor below)
- **Shell environment**: zsh as the login shell, oh-my-zsh + powerlevel10k (both pinned), `ZDOTDIR` relocated to `~/.config/zsh`
- **Languages**: C, C++ (gcc, clang) and Python everywhere; Haskell, Go, Node.js, PowerShell with the `languages` profile
- **File management**: Yazi (terminal), Thunar (GUI)
- **Browsers**: Vivaldi, LibreWolf, qutebrowser
- **Launcher**: Rofi, custom retrowave-themed launcher (Alt + h/j/k/l, Alt + d/u vim motions, matching Kitty) and power menu
- **Communication**: Teams (Flatpak), Discord and Spotify (`personal` profile)
- **Gaming**: Steam, MangoHud, gamescope (multilib, `gaming` profile)
- **VPN**: Surfshark via raw WireGuard configs — no GUI/CLI client installed
- **Peripherals**: Xbox controller support via xpadneo, built from source (DKMS)

Official Arch repos, source builds, or GitHub release tarballs only — no AUR helper anywhere in the install path. Everything from outside pacman/Flatpak is pinned to an exact commit or release in `packages/sources.txt`.

## Structure

- **`scripts/`** — staged install scripts (`00`–`06`), run in order by `install.sh`. Each stage is independently idempotent.
  - `00-preflight.sh` — connectivity/sudo checks
  - `01-pacman-packages.sh` — multilib, snapper bootstrap (so everything after is snapshot-protected), `base.txt` + active profiles via pacman, then Flatpak
  - `02-build-from-source.sh` — Quickshell (rebuilt when its pin or Qt changes), grimblast, xpadneo, then each active profile's `scripts/lib/builds/<profile>.sh` (security: Burp, Metasploit; languages: PowerShell). All at their `sources.txt` pins.
  - `03-nix-install.sh` — Determinate Systems installer, flakes/devShells only (never used for system/DE management); upgrades only when a new release is out
  - `04-fonts.sh` — Departure Mono
  - `05-dotfiles-copy.sh` — whole config directories (git-tracked files only), zsh as login shell, pinned oh-my-zsh + powerlevel10k, rice activation + theme generation, prunes files the repo no longer ships
  - `06-services.sh` — SDDM theme deployment, service enablement, `/home` snapper config + timers
- **`config/`** — dotfiles copied into place. Mostly mirrors real `~/.config` paths; `config/rices/` holds the switchable themes.
- **`packages/`** — what gets installed:
  - `base.txt` (every machine) and `profiles/<name>.txt` (on by default, skippable per machine, see Usage): pacman lists, comment/blank-line filtered, installed with `--needed`
  - `flatpak-packages.txt`
  - `ignored.txt`: installed on purpose but not reproduced (written by `tools/sync-packages.sh`)
  - `sources.txt`: pinned commit/release of everything built or downloaded from outside pacman (see Pinned sources and CI)
- **`hosts/`** — one `<hostname>.conf` per machine recording which profiles it skips. Written by `install.sh`/`update.sh` `--skip`/`--only`, read by every later run.
- **`scripts/lib/`** — shared by the stages and tools:
  - `common.sh`: logging, `copy_plain` + the managed-files manifest
  - `profiles.sh`: profile selection (`--skip`/`--only`, host files)
  - `sources.sh`: pinned checkouts (`packages/sources.txt`)
  - `snapshots.sh`: snapper/snap-pac/rollback/backup mechanism (configs, hooks, tools, timers), used by `01`, `06` and `tools/setup-snapshots.sh`
  - `builds/<profile>.sh`: per-profile build steps, run by `02`
  - `verify-repo.sh`: the repo linter (below)
- **`tools/`** — standalone helpers, not run by `install.sh`:
  - `sync-packages.sh`: package lists vs. what's installed (also run by `update.sh`)
  - `bump-sources.sh`: move `sources.txt` pins to upstream's latest, keeping only what passes the VM test
  - `vm/`: throwaway QEMU/KVM test VM. `vm.sh` drives it, `guest-install.sh` scripts the "Before you start" steps inside it (packages from `base-packages.txt`), `checks.sh` holds the post-install assertions
  - snapshot setup, subvolume conversion, Vivaldi capture
- **`.github/workflows/`** — CI: `lint.yml` on every push, `bump-sources.yml` weekly (see Pinned sources and CI).
- **`fonts/`** — Departure Mono (OFL-licensed).
- **`docs/`** — how-to docs for RGB, snapshots/rollback/backups, and VM testing.
- **`TODO.md`** — open work: next steps, features, testing, polish.
- **`install.sh`** — entry point. Sets `core.hooksPath` so the linter runs on commit, runs all staged scripts in order, takes a clean-install baseline snapshot. Keeps the clone (`update.sh` runs from it) unless given `--delete-repo`.
- **`update.sh`** — reconciles an installed machine with the repo, see "Updating an existing machine".

`scripts/lib/verify-repo.sh` is a repo linter wired into the `pre-commit` git hook (and CI) — checks `copy_plain` sources and `CONFIG_DIRS` exist, every listed package exists in the official repos (catches AUR names, typos, and packages dropped upstream), `hosts/*.conf` only name existing profiles, README stage-range accuracy, and script header conventions.

## Before you start

This repo assumes you're picking up *after* a working, booted, networked Arch base install. It does not partition disks, run `pacstrap`, or configure a bootloader.

**Prerequisites, in order:**

1. **Partition and format** — btrfs on the root partition with a `@`/`@home`/`@log`/`@pkg`/`@snapshots` subvolume layout, FAT32 EFI partition, swap.
2. **`pacstrap` the base system** — `base linux linux-firmware btrfs-progs sudo vim networkmanager intel-ucode` at minimum.
3. **`genfstab` + `arch-chroot`.**
4. **Inside chroot:** locale, hostname, root password, timezone (`ln -sf /usr/share/zoneinfo/<zone> /etc/localtime && hwclock --systohc` — `timedatectl` does not work inside a chroot), NVIDIA driver + `mkinitcpio` modules, systemd-boot (**double-check `rootflags=subvol=@` uses an equals sign, not a hyphen** — this exact typo has broken a boot before), user creation with `wheel` + `visudo`.
5. **Reboot, remove install media, log in as the created user.**
6. **Connectivity** — confirm before doing anything else: `ping -c 3 archlinux.org` (on Wi-Fi, connect first with `nmcli device wifi connect <SSID> password <password>`).

`tools/vm/guest-install.sh` is a scripted version of steps 1–4, used for the test VM. Read it as a reference, but don't run it on real hardware: it wipes the disk without asking.

## Usage

    git clone https://github.com/ChandlerCamarena/camarena-arch-setup.git
    cd camarena-arch-setup
    ./install.sh                         # everything
    ./install.sh --skip gaming,security  # everything except those
    ./install.sh --only personal,nvidia  # just those (plus base)

Run from a fresh Arch base install (post-`pacstrap`, post-chroot, already booted) with network access. Will prompt for sudo where needed.

`base.txt` always installs. Every profile in `packages/profiles/` is **on by default**; skip the ones a machine doesn't need:

| Profile | Adds |
| ------- | ---- |
| `nvidia` | NVIDIA driver stack (`nvidia-open`, utils, VA-API, PRIME offload) |
| `personal` | Discord, Spotify |
| `rgb` | OpenRGB, plus the RGB config and service (`docs/rgb.md`) |
| `gaming` | Steam, gamescope, gamemode, MangoHud, Prism Launcher, Wine |
| `datum` | Vulkan / Project Datum graphics-driver toolchain (incl. pinned clang21/llvm21) |
| `languages` | languages beyond base's C/C++/Python: Haskell (ghc, cabal, HLS), Go, Node.js (+ TS language server), PowerShell (Microsoft's release tarball) |
| `dev` | dev tooling: Docker, valgrind, PostgreSQL, SQLite, gh, direnv |
| `security` | recon/RE/pentest tooling, Burp Suite, Metasploit (built from source; `msfconsole`/`msfvenom`/`msfdb` on PATH) |
| `media` | recording/streaming tooling |
| `virt` | QEMU/libvirt/virt-manager, plus what `tools/vm/` needs |

The selection is recorded in `hosts/<hostname>.conf` (e.g. `skip=dev,media,security`), so `update.sh` and later installs on the same machine need no flags. Commit that file; a reinstall of the machine then gets the same selection back automatically. `--skip all` installs base only, `--skip none` everything.

The clone is kept afterwards, since `update.sh` runs from it. Add `--delete-repo` to remove it once every stage has passed.

## Updating an existing machine

    ./update.sh                     # uses hosts/<hostname>.conf
    ./update.sh --skip dev,media    # change this machine's selection

`update.sh` reconciles a live machine against the repo, in this order: fast-forward pull, package-list review, `pacman -Syu`, package and pinned-source sync, then the dotfiles and services stages.

**Package-list review** (`tools/sync-packages.sh`; run it alone any time, `--report` changes nothing). It runs before anything is installed, since the sync after it reinstalls every listed package:
- installed but in no list: add it to `base.txt` or a profile, or to `packages/ignored.txt` (installed on purpose, never reproduced, never asked about again)
- listed but no longer installed: drop it from its list, or keep it (and have it reinstalled)
- the same for Flatpak
- a report of software from outside pacman/Flatpak: AUR/foreign packages, unowned files in `/usr/local` and `/opt`, `~/.local/bin`, pipx/cargo/npm/nix

List edits land in the working tree; commit them (the next `update.sh` refuses a dirty tree).

**Dotfiles.** Every file the dotfiles stage installs is recorded in `~/.local/state/camarena-arch-setup/managed-files`. On the next run those files are overwritten in place (no `.bak`), and any the repo no longer ships are deleted. Files the repo never installed (shell history, oh-my-zsh's cache, Vivaldi profile, GTK bookmarks) are never touched, and an unmanaged file that would be overwritten with different content is still backed up to `<path>.bak.<timestamp>`.

## Testing in a VM

    tools/vm/vm.sh test                      # base (if missing) -> install -> update -> reboot + checks, all profiles
    tools/vm/vm.sh test --skip all --gui     # base only, then open the desktop (login tester/tester)

Runs the repo as it is on disk, uncommitted changes included, against a clean install that follows the "Before you start" layout exactly. The checks cover services, snapshots, theme generation, pinned sources, every active profile's packages and extras, and that skipped profiles really were skipped. NVIDIA, RGB and real-monitor behaviour still need real hardware. See **[docs/vm-testing.md](docs/vm-testing.md)**.

## Pinned sources and CI

`packages/sources.txt` pins everything installed from outside pacman/Flatpak: Quickshell, grimblast (hyprwm/contrib), xpadneo, oh-my-zsh, powerlevel10k, Metasploit (git commits) and PowerShell (release tag). Install and update build exactly those versions, so a fresh install months from now gets what was tested.

Pins don't move by themselves; `tools/bump-sources.sh` moves them:

    tools/bump-sources.sh --check   # what's newer upstream
    tools/bump-sources.sh           # bump, VM-test, keep what passes

It pins everything to upstream's latest and runs the full VM pipeline (all profiles). If that fails, it tries each bump on its own and keeps only the passing ones; the rest stay at their old pin, and a desktop notification names them. If even the current pins fail, it reports a broken pipeline instead of blaming the bumps. Commit `packages/sources.txt` afterwards; the next `update.sh` builds the new versions.

On a rolling distro old pins rot too (Arch updates the libraries under them), so bump regularly. CI does it weekly:

| Workflow | When | What |
| -------- | ---- | ---- |
| `lint.yml` | every push / PR | `verify-repo.sh`, `shellcheck`, `bash -n` / `luac -p` over every script, in an Arch container |
| `bump-sources.yml` | Mondays 09:00 UTC, or by hand (Actions → bump-sources → Run workflow) | `bump-sources.sh` on a GitHub runner with KVM; passing bumps become a **"Bump pinned sources"** pull request, failing ones an issue. Logs are uploaded as run artifacts. |

The bump workflow needs **Settings → Actions → General → Workflow permissions → "Allow GitHub Actions to create and approve pull requests"** enabled on the repo to open its pull request.

## Editor

Neovim with lazy.nvim (plugins pinned in `config/nvim/lazy-lock.json`) and native `vim.lsp.config`; every language server and formatter comes from pacman, not Mason.

- **Language servers**: clangd (C/C++, background index + clang-tidy), pyright, bash-language-server, lua-language-server, qmlls (Quickshell QML), TypeScript and Haskell with `languages`
- **Treesitter** highlighting and indent for every installed language (`main` branch; parsers built with `tree-sitter-cli`)
- **Format on save** (conform.nvim): clang-format, ruff, stylua, shfmt, falling back to the language server
- **Debugger** (nvim-dap + dap-ui) over gdb's built-in DAP for C/C++
- Telescope, Neo-tree + Yazi float, which-key, gitsigns, inline diagnostics, absolute line numbers

| Keys | |
| ---- | --- |
| `<leader>` then wait | which-key: everything that follows |
| `<leader>ff` / `fg` / `fb` / `fr` | find files / grep / buffers / recent |
| `<leader>fs` / `fd` / `/` | symbols in file / all diagnostics / search this file |
| `gd`, `grr`, `K`, `<leader>rn`, `<leader>ca`, `<leader>d` | definition, references, hover, rename, code action, diagnostic float |
| `<leader>h` | switch C/C++ header ↔ source |
| `F5` / `F10` / `F11` / `F12`, `<leader>b`, `<leader>D` | debug: continue, step over/into/out, breakpoint, toggle UI |
| `<leader>e` / `<leader>-` | Neo-tree / Yazi |
| `gcc`, `gc` | comment line / motion (built in) |


## Theme

Everything visual — Hyprland borders/gaps, Quickshell panels, Yazi, Kitty, Neovim, GTK apps, Rofi (`generate-rofi.sh` → `retrowave.rasi`, plus the clipboard picker), RGB (`rgb theme`), and the SDDM login screen — reads from a single source of truth: the active rice's `theme.json` (default: `config/rices/retrowave/theme.json`). Each consumer has a thin generator/loader that reads this file and produces its native config format.

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

### RGB

Declarative OpenRGB profiles (`off`, `purple`, `theme`) driven by `rgb [toggle|off|purple|theme|apply]`, re-applied on login by `openrgb.service`. See **[docs/rgb.md](docs/rgb.md)**.

### Rice switching

Multiple visual profiles under `~/.config/rices/<name>/` (repo: `config/rices/`), each with `theme.json` + `wallpaper.png` and an optional `apply.sh`. `~/.config/hypr/theme.json` and `~/.config/hypr/wallpapers/wallpaper.png` are symlinks into the active rice. Switching repoints them, regenerates every derived config, then reloads Hyprland, restarts hyprpaper, and pushes the change to Quickshell, Kitty and RGB. Pick one with `Super + Delete` or `~/.config/rices/scripts/switch.sh <name>`. The active rice is kept in `~/.config/rices/.active` and survives `update.sh`. See `config/rices/scripts/switch.sh` for the authoritative sequencing.

To add a rice: copy `config/rices/retrowave/` to `config/rices/<name>/`, change the palette and wallpaper, run `update.sh`.

## Snapshots, rollback, backups

snap-pac pre/post pairs on every pacman run, daily timeline snapshots (7 daily + 4 weekly) for `/` and `/home`, a never-pruned **clean-install baseline** taken at the end of `install.sh`, `snap-rollback` to boot back into any of them, and `snap-backup` for incremental btrfs send/receive to an external drive labelled `CAS-BACKUP`. See **[docs/snapshots-and-backups.md](docs/snapshots-and-backups.md)**.

## Hardware targets

- **Desktop (`prometheus`)**: Intel Core i9-13900K, discrete NVIDIA RTX 4080, 1440p. Skips `dev`, `media`, `security` (`hosts/prometheus.conf`).
- **Laptop (`prometheus-laptop`)**: NVIDIA GTX 1650 Mobile + Intel iGPU (PRIME hybrid), 4K 15" panel at 1.5x scale. Skips `rgb` (`hosts/prometheus-laptop.conf`).

Both run the same config. On the laptop the Intel iGPU drives the display and nothing forces NVIDIA globally; run an app on the dGPU with `prime-run <app>` (`nvidia-prime`, in the `nvidia` profile).

## Known limitations

- **`snapper rollback` itself does not work on this setup.** Snapper cannot detect a rollback "ambit" with systemd-boot plus a flat `@` layout. Use `snap-rollback` instead (docs/snapshots-and-backups.md). It does the subvolume swap at the btrfs top level, which works because fstab and the boot entry mount `@` by name.
- **Rollback doesn't carry nested subvolumes inside `@`** (e.g. `/var/lib/machines`); they stay in the old `@.pre-rollback-*`.

## Future work

Open work — features, testing, polish, and the manual next steps after this round of changes — lives in **[TODO.md](TODO.md)**.

## License

See `LICENSE`. Departure Mono is separately licensed under the OFL — see `fonts/OFL.txt`. The SDDM theme (`config/sddm/retrowave/`) is derived from Sanjeev Premi's "maya" theme, MIT-licensed — original license retained at `config/sddm/retrowave/LICENSE`.
