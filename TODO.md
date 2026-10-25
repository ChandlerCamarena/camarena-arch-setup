# TODO

Open work for this repo, roughly in priority order within each section.
Tick items off here (or delete them) in the same commit that does them.

## Next up (manual, outside the repo)

- [ ] Enable **Settings → Actions → General → Workflow permissions → "Allow GitHub Actions to create and approve pull requests"**, then run **Actions → bump-sources → Run workflow** once by hand to confirm CI works on GitHub's runners (first run ever; expect a fix or two).
- [ ] Desktop (`prometheus`): `git pull && ./update.sh`. Walk the package-list review (vim, wireguard-tools, zoxide, fwupd → lists; cuda, liquidctl, debootstrap, ... → `ignored.txt`), let Quickshell rebuild at its new pin, commit the list changes. Then remove the AUR PowerShell: `sudo pacman -Rns powershell-bin powershell-bin-debug`.
- [ ] Laptop: `sudo hostnamectl hostname prometheus-laptop` **before** its first `update.sh` (otherwise it picks up the desktop's `hosts/prometheus.conf`), then `./update.sh`.
- [ ] Laptop GPU check: `hyprctl systeminfo | grep -i gpu` (Hyprland should render on the Intel iGPU) and `nvidia-smi` (no processes while idle).
- [ ] Vivaldi: re-capture the laptop's current profile with `tools/capture-vivaldi.sh`, review the diff, commit.

## Features

- [ ] **Second rice.** Switching works but there's only retrowave: copy `config/rices/retrowave/`, change palette + wallpaper.
- [ ] **Pin Burp Suite and the Nix installer** in `packages/sources.txt`; both still download "latest" at install time, the last unpinned installs.
- [ ] **Neovim plugins in the bump pipeline.** `config/nvim/lazy-lock.json` is pinned but never bumped; add a `Lazy update` + VM test step to `tools/bump-sources.sh`.
- [ ] **Per-host Hyprland settings.** Let `hosts/` carry more than `skip=`: a per-host Lua overlay (monitors, env) loaded by `hyprland.lua`, starting with the laptop's 4K panel.
- [ ] **NVIDIA runtime power management on the laptop** (dGPU fully off when idle), if battery life needs it after the GPU check.
- [ ] **PPI-aware `monitors.lua`** — deferred until validated on a real two-display setup. Approach: read EDID from `/sys/class/drm/*/edid` directly, since `hl.get_monitors()` has no physical size fields and `io.popen("hyprctl ...")` from inside a config reload deadlocks against Hyprland's own IPC socket.
- [ ] **Custom icon theme** matching the sharp/bevel aesthetic. Multi-session scope.

## Testing

- [ ] **Session test in the VM.** The checks stop at "installed and configured": add SDDM autologin for `tester`, then assert Hyprland and Quickshell are running with no QML errors in the Quickshell log, and grab a screenshot (`grim`) as a run artifact.
- [ ] **Rollback + backup test in the VM.** Attach a throwaway disk labelled `CAS-BACKUP`, run `snap-backup`, break something, `snap-rollback --baseline`, reboot, verify.
- [ ] **Preflight checks in `00-preflight.sh`**: btrfs root on `@`, the expected subvolumes, systemd-boot, NetworkManager — fail before stage 01 instead of halfway through.

## Polish

- [ ] `config/hypr/modules/monitors.lua` still writes a debug log to `/tmp/monitor-scale-debug.log` on every monitor event; remove it or gate it behind a flag.
- [ ] Run Quickshell as a systemd user service (via uwsm) instead of `quickshell &` in `autostart.lua`, so it restarts if it crashes.
- [ ] Move fixed `/tmp/*.log` paths (`qs.log`, `generate-hyprlock.log`) to `$XDG_RUNTIME_DIR`.
- [ ] Quickshell polling: `WorkspaceIndicator.qml` polls every 1s where Hyprland IPC events could drive it, and ~10 other timers poll; worth a pass for laptop battery.
- [ ] `config/hypr/modules/theme.lua`: decide on the active border (gradient vs flat bevel) and drop the stale "needs updating" comment.
- [ ] Jazz autoplay in `autostart.lua` assumes `~/Music/jazz` exists; skip it when it doesn't.
- [ ] The VM's persistent package cache (`~/.cache/camarena-arch-setup/vm/pkgcache.qcow2`) grows forever; prune it with `paccache` from `vm.sh` now and then.
