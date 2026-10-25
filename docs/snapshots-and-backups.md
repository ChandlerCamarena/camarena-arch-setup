# Snapshots, rollback, and backups

An installed copy of this file lives at
`/usr/local/share/doc/camarena-arch-setup/snapshots-and-backups.md`, so it's
still there if the repo was removed with `install.sh --delete-repo`.

## The short version

| I want to…                                  | Run                                          |
| ------------------------------------------- | -------------------------------------------- |
| See my restore points                       | `sudo snap-rollback --list`                  |
| Mark "this state is good, keep it forever"  | `sudo snap-baseline "after nvidia setup"`    |
| Go back to the clean install / last baseline | `sudo snap-rollback --baseline`, then reboot |
| Undo the last pacman upgrade                | `sudo snap-rollback <pre-number>`, then reboot |
| Get one file back from /home                | `cp /home/.snapshots/<N>/snapshot/<path> ~/<path>` |
| Back up to the external drive now           | `sudo snap-backup`                           |
| See what's on the backup drive              | `sudo snap-backup --status`                  |

Always try `-n` (dry run) on `snap-rollback` first. It prints every step
without touching anything.

## What's running and why

Snapshots are **not backups**. They live on the same disk, so if the disk dies
they die with it. They protect against *you* (bad upgrade, deleted file, broken
config). The backup drive protects against *hardware*. You want both.

| Layer                    | When                         | Kept                     | Where                    |
| ------------------------ | ---------------------------- | ------------------------ | ------------------------ |
| pacman pre/post pairs (root) | every pacman transaction (snap-pac) | last 10 pairs | `/.snapshots`            |
| timeline (root + home)   | daily                        | 7 daily + 4 weekly       | `/.snapshots`, `/home/.snapshots` |
| baselines                | when you run `snap-baseline` (and once at the end of `install.sh`) | forever | same |
| backups                  | weekly (`snap-backup.timer`), or `sudo snap-backup` any time | mirrors the above | drive labelled `CAS-BACKUP` |

Retention lives in `config/snapper/root.conf` and `home.conf`. `snapper-cleanup.timer`
enforces it. Without that timer nothing ever gets deleted, which is how the
old setup piled up 670 snapshots.

Btrfs snapshots are copy-on-write, so a snapshot costs only the space of data
that has *changed or been deleted* since it was taken. Daily snapshots of an
idle system are nearly free. Deleting a 50 GB game frees nothing until every
snapshot that still references it has aged out (up to ~4 weeks with the
weekly limit). See "Large churny directories" below.

### Pieces

- `snap-pac` (official package): pacman hooks, pre/post snapshot pair per transaction.
- `/etc/pacman.d/hooks/00-boot-backup.hook` and `95-boot-backup-post.hook` run
  `snap-boot-backup`, which mirrors the kernel, initramfs and ucode from `/boot`
  (vfat, outside btrfs) into `/.bootbackup`. That way every root snapshot knows
  which kernel matches its `/usr/lib/modules`.
- `snap-rollback`: the rollback (see below).
- `snap-baseline`: tagged snapshots that are never pruned.
- `snap-backup`: snapshot + incremental `snbk` transfer to the backup drive.
- `/etc/snapper/backup-configs/{root,home}.json`: snbk targets (`/mnt/backup/{root,home}`).
- `snap-backup.timer`: weekly backup, enabled. If the drive isn't connected it
  exits quietly, and `Persistent=true` makes it run at the next boot after a missed week.

Source for all of it: `config/snapper/`, `config/pacman-hooks/`,
`scripts/lib/snapshots.sh`.

## Rollback

```
sudo snap-rollback --list          # * marks baselines
sudo snap-rollback -n 412          # dry run
sudo snap-rollback 412             # do it
reboot
```

What it does, at the btrfs top level (`subvolid=5`):

1. Makes a writable copy of `@snapshots/412/snapshot` named `@.rollback-new`.
2. Renames the current `@` to `@.pre-rollback-<timestamp>`. Nothing is deleted.
3. Renames `@.rollback-new` to `@`.
4. Copies the snapshot's kernel/initramfs from `/.bootbackup` into `/boot`,
   after saving the current ones into the old root's `.bootbackup-at-rollback/`.

The running system is unaffected until you reboot. fstab and the
systemd-boot entry mount `@` *by name*, so the next boot uses the restored copy.

**Only `/` rolls back.** `/home`, `/var/log` and the pacman cache are separate
subvolumes and stay as they are. That's usually what you want: roll the OS back,
keep your files. To restore something in `/home`, copy it out of
`/home/.snapshots/<N>/snapshot/`.

**Rolled back and regret it?** The old root is still there as
`@.pre-rollback-<timestamp>`. Roll "forward" by swapping it back the same way, or
just leave it until you're sure, then delete it:

```
sudo mount -o subvolid=5 /dev/nvme1n1p3 /mnt
sudo btrfs subvolume delete /mnt/@.pre-rollback-20261101-120000
sudo umount /mnt
```

Leftover `@.pre-rollback-*` subvolumes hold disk space, so clean them up.

**System won't boot at all?** Boot the Arch ISO and run the same script from
there. Copy it onto a USB stick, or read it from the broken root (it's just
bash). Then:

```
mount /dev/nvme1n1p1 /mnt/boot   # the ESP
bash snap-rollback --device /dev/nvme1n1p3 --boot /mnt/boot --list
bash snap-rollback --device /dev/nvme1n1p3 --boot /mnt/boot 412
```

Why not `snapper rollback`? It needs a "rollback ambit" that snapper can't
detect on systemd-boot + a flat `@` layout. This script does what it would
have done.

Caveat: nested subvolumes *inside* `@` (e.g. `/var/lib/machines`,
`/var/lib/portables`) aren't part of snapshots, so after a rollback they
remain in the old `@.pre-rollback-*`.

## Baselines (the clean-install restore point)

`install.sh` ends by running `snap-baseline "clean install (camarena-arch-setup)"`.
That creates a root + home snapshot tagged `baseline=yes` with no cleanup
algorithm, so it's never pruned and the backup drive keeps it too.

```
sudo snap-baseline "before trying emacs"   # make another one any time
sudo snap-rollback --baseline              # newest baseline
sudo snap-rollback --list                  # pick an older one by number
```

Delete a baseline you no longer want with `sudo snapper -c root delete <N>`
(and the matching `-c home` one).

On a machine that wasn't installed from scratch (this one), clean it up first, then run
`sudo snap-baseline "clean"` once to get the same thing.

## Backups to an external drive

### Recommendation: incremental, via btrfs send/receive

`snap-backup` uses snapper's own `snbk`. The **first** run sends a full copy
of each snapshot chain. Every run after that sends only the blocks that
changed since a snapshot already on the drive. That's incremental in cost
and size, but each snapshot on the drive is still a complete, browsable
filesystem tree, so there's no "full + chain of diffs" to replay on restore.
That's the best of both, and it's why there's no "incremental vs full"
choice to make here.

The drive mirrors local retention (`transfer-and-delete`): 7 daily + 4 weekly +
pacman pairs + all baselines.

### One-time drive setup

The backup drive must be **btrfs** (send/receive needs it) and must be a
**different physical disk** from the system. Formatting destroys its contents:

```
lsblk -f                                   # find the right partition!
sudo wipefs --no-act /dev/sdXN             # lists existing signatures, changes nothing
sudo mkfs.btrfs -L CAS-BACKUP /dev/sdXN
sudo snap-backup --init                    # creates root/ and home/ subvolumes on it
```

On `prometheus` the backup partition is `sda1`: the first ~931 GiB of the 4 TB
Seagate (`ST4000DM004`), in front of the existing `sda2`.

The script finds the drive by label, so you can swap drives freely. Plug in a
new one, format it with the same label, and `--init` it.

### Running it

```
sudo snap-backup            # mounts /dev/disk/by-label/CAS-BACKUP on /mnt/backup if needed,
                            # snapshots root+home, transfers, unmounts
sudo snap-backup --status   # snbk list: what's local vs on the drive
```

It also runs automatically every week (`snap-backup.timer`, enabled by the
installer). Check it with `systemctl list-timers snap-backup.timer` and
`journalctl -u snap-backup`.

### Restoring from the drive

Lost a snapshot locally (or the whole disk) but it's on the backup:

```
sudo snap-backup --status            # find the number
sudo mount /dev/disk/by-label/CAS-BACKUP /mnt/backup
sudo snbk -b root restore 412        # copies it back into /.snapshots
sudo systemctl restart snapperd
sudo snap-rollback 412
```

New/blank system disk: install the Arch base with the same `@`/`@home`/… layout
(README, "Before you start"), install snapper, create the configs, then
`snbk restore` + `snap-rollback` as above. For `/home`, `btrfs send` the home
snapshot back and swap it in as `@home` the same way `snap-rollback` swaps `@`.

### Later: NAS

Change `target-mode` to `ssh-push` in `/etc/snapper/backup-configs/*.json` (see
`man snapper-backup-configs`). The NAS side needs a btrfs filesystem and root
ssh access via `ssh-identity`.

## What is NOT snapshotted or backed up

Btrfs snapshots don't descend into nested subvolumes. A directory that is its
own subvolume is therefore excluded from `/home` snapshots, and with them from
`snap-backup`.

| Directory                  | Why excluded                       |
| -------------------------- | ---------------------------------- |
| `~/.local/share/Steam`     | ~1.5T of re-downloadable games (only with the `gaming` profile) |
| `~/AI/models`              | re-downloadable model weights      |

The list is `SNAPSHOT_EXCLUDED_DIRS` in `scripts/lib/snapshots.sh`. On a fresh
install these are created as subvolumes before anything is put in them. If one
already exists as a plain directory, setup prints an error. Convert it in place
(no data copied, close Steam first):

```
tools/make-subvolume.sh ~/.local/share/Steam
# check Steam still works, then:
rm -rf ~/.local/share/Steam.pre-subvolume
```

To exclude something else, add it to the list and run the tool on it.

`~/Gaming` (decomps, retro, non-Steam) is deliberately **included**, so it gets daily
snapshots and the weekly backup like the rest of `/home`. After the first
backup, unchanged files cost nothing, so there's no reason to back it up less
often. If it ever grows into hundreds of GB of ROMs/ISOs, split it out into its own
subvolume with a separate snapper config and a monthly or quarterly timer.

## Clearing old snapshots / setting this up on an existing machine

```
tools/setup-snapshots.sh                    # install everything, keep existing snapshots
tools/setup-snapshots.sh --purge-existing   # delete ALL existing snapshots first (asks)
```

Neither creates snapshots itself. The daily timer starts the next day, and
you make the baseline when you're ready.

## Useful snapper commands

```
snapper -c root list                    # all root snapshots (with userdata/cleanup columns)
snapper -c root status 412..413         # files changed by one pacman transaction
snapper -c root diff 412..413 /etc/x    # diff of one file
sudo snapper -c root undochange 412..413 /etc/x   # revert individual files, no reboot
```
