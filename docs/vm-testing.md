# Testing in a VM

`tools/vm/vm.sh` runs this repo end to end in a throwaway QEMU/KVM VM, so a
change to `install.sh`, `update.sh`, a config or a rice can be tried on a
clean Arch install before it touches real hardware.

Host requirements come with the `--virt` profile (`qemu-full`, `edk2-ovmf`,
`libisoburn`, `openssh`, `rsync`), plus KVM (`/dev/kvm` writable, i.e. you're
in the `kvm` group).

## Use

One command runs the whole pipeline and stops at the first failing stage:

```
tools/vm/vm.sh test                    # base (if missing) -> install -> update -> reboot + check
tools/vm/vm.sh test --skip gaming      # same profile flags as install.sh
tools/vm/vm.sh test --skip all --gui   # base only, then open the desktop to look around
```

| Stage | Passes when |
| ----- | ----------- |
| `base` | Base image exists, or was just built (skipped after the first run) |
| `install` | `install.sh <flags>` exits 0 on a fresh VM |
| `update` | `update.sh <flags>` exits 0 straight after, on the same VM |
| `check` | After a reboot, every assertion in `tools/vm/checks.sh` holds: no failed units, snapper baselines, theme symlinks and generated configs, font registered, no `.bak` files left by `update.sh`, ... |

It ends with a per-stage PASS/FAIL table with timings. Add a check by adding
one `check "<description>" <command>` line to `checks.sh`.

The individual steps are available on their own:

```
tools/vm/vm.sh base              # once: bare Arch base image (~3-10 min)
tools/vm/vm.sh install --skip all   # fresh VM from base, runs install.sh --skip all
tools/vm/vm.sh start             # boot it with a display, log in tester/tester
tools/vm/vm.sh start --headless  # boot it without a window, then use vm.sh ssh
tools/vm/vm.sh update --skip all    # copy the repo in again, run update.sh --skip all
tools/vm/vm.sh check             # run checks.sh in the current VM
tools/vm/vm.sh ssh               # shell in the running VM (or: ssh <cmd>)
tools/vm/vm.sh stop
tools/vm/vm.sh reset             # throw the VM away, next run starts from base
```

The repo is copied in as it is on disk, uncommitted changes included, so
there's no need to commit before testing. For `update`, the working tree goes
to `~/cas-upstream` in the VM, uncommitted changes are committed there, and
`~/camarena-arch-setup` is cloned from it. `update.sh` then does its real
`git pull` against exactly your local state, with no network or GitHub
credentials involved. Your real repo is never touched.

Typical loops:

- **Changed `install.sh` / a stage / a package list:** `vm.sh install <flags>`.
  Always starts from the clean base, like a real fresh install.
- **Changed a config, theme or `update.sh`:** `vm.sh update <flags>` on the
  existing VM, then `vm.sh start` to look. This is the path a real machine
  takes after a `git pull`.
- **Broke the VM:** `vm.sh reset`, or roll back inside it with
  `snap-rollback` like on real hardware.

## How it works

| Step | What happens |
| ---- | ------------ |
| `base` | Downloads the latest official Arch ISO (checksum + signature checked against the pacman keyring, or Arch's release key fetched by WKD where there is no pacman, e.g. CI), boots it headless with a cloud-init seed disk. The ISO's cloud-init runs `tools/vm/guest-install.sh`, which does README "Before you start" steps 1-4: GPT with EFI/swap/btrfs, the `@`/`@home`/`@log`/`@pkg`/`@snapshots` layout, `pacstrap` of `tools/vm/base-packages.txt`, systemd-boot with `rootflags=subvol=@`. Result: `base.qcow2`. Rebuild with `vm.sh base --force` after changing either file. |
| `install` | New copy-on-write overlay on `base.qcow2` (seconds, no copy), boots headless, rsyncs the repo in over ssh, runs `install.sh` with your flags, shuts down. |
| `update` | Boots the existing overlay if needed, rsyncs, runs `update.sh`. |
| `start` | Boots the overlay with a virtio-gpu (virgl) display in a QEMU window. |

Everything lives in `~/.cache/camarena-arch-setup/vm/`: images, the ISO,
the VM's ssh key, and logs (`install.log`, `update.log`, `check.log`,
`serial.log` for boot/console output, `qemu.log`).

`pkgcache.qcow2` is a second virtual disk that `reset` never touches. It's
mounted over the VM's pacman cache during `install`/`update`, so packages
download once rather than on every fresh VM.

Inside the QEMU window, press **Ctrl+Alt+G** to grab the keyboard so Super
shortcuts go to the VM instead of your host's Hyprland; again to release.

Tunables (environment): `VM_MEM` (default `8G`), `VM_CPUS` (`4`),
`VM_DISK_SIZE` (`80G`, sparse), `VM_SSH_PORT` (`2222`), `VM_DISPLAY`
(`gtk,gl=on`; try `sdl,gl=on` if the window is black), `ISO_MIRROR`.

## In CI

`.github/workflows/bump-sources.yml` runs this same pipeline weekly on a
GitHub runner (via `tools/bump-sources.sh`). Off Arch, point `OVMF_CODE` /
`OVMF_VARS` at the distro's UEFI firmware (Ubuntu:
`/usr/share/OVMF/OVMF_{CODE,VARS}_4M.fd`); the ISO signature is then checked
with `gpg` instead of `pacman-key`.

## What the VM can't test

No NVIDIA card (driver packages install but don't load), so PRIME/NVIDIA
env vars, RGB hardware, the Xbox controller driver beyond "it builds", and
real monitor/PPI behaviour need real hardware. The VM user is `tester`, not
your username, on purpose: a hardcoded `/home/<you>` path breaks there first.

`guest-install.sh` wipes `/dev/vda` without asking. It's only ever meant to
run inside the VM.
