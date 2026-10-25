#!/usr/bin/env bash
# guest-install.sh - README "Before you start" steps 1-4, scripted, for the
# test VM only. vm.sh base boots the official Arch ISO with this script on a
# cloud-init seed disk; the ISO's cloud-init runs it as root.
#
# WIPES /dev/vda WITHOUT ASKING. Never run it on real hardware.
#
# Differences from a real install: no NVIDIA driver/mkinitcpio modules (no
# card in the VM), passwordless sudo and sshd so vm.sh can drive it.
set -euo pipefail
SEED="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SEED/vm.env"   # VM_USER, VM_PASS, VM_HOST

# vm.sh follows progress and looks for the OK/FAILED marker on the serial log
exec > >(tee /dev/ttyS0) 2>&1
trap 'echo "VM-INSTALL-FAILED (line $LINENO)"; sync; poweroff' ERR

DISK=/dev/vda
[[ -b "$DISK" ]] || { echo "no $DISK, refusing to guess a disk"; false; }

echo "[guest] Waiting for the live ISO's keyring and mirrorlist..."
systemctl start pacman-init.service
systemctl start reflector.service || echo "[guest] reflector failed, using the ISO's default mirrorlist"

echo "[guest] Partitioning $DISK: 1G EFI, 4G swap, rest btrfs..."
sfdisk --wipe always --wipe-partitions always "$DISK" <<EOF
label: gpt
size=1G, type=uefi
size=4G, type=swap
type=linux
EOF
mkfs.fat -F32 "${DISK}1"
mkswap "${DISK}2"
mkfs.btrfs -f "${DISK}3"

echo "[guest] Creating @ @home @log @pkg @snapshots..."
mount "${DISK}3" /mnt
for sv in @ @home @log @pkg @snapshots; do
    btrfs subvolume create "/mnt/$sv"
done
umount /mnt

OPTS=noatime,compress=zstd
mount -o "$OPTS,subvol=@" "${DISK}3" /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o "$OPTS,subvol=@home"      "${DISK}3" /mnt/home
mount -o "$OPTS,subvol=@log"       "${DISK}3" /mnt/var/log
mount -o "$OPTS,subvol=@pkg"       "${DISK}3" /mnt/var/cache/pacman/pkg
mount -o "$OPTS,subvol=@snapshots" "${DISK}3" /mnt/.snapshots
mount "${DISK}1" /mnt/boot
swapon "${DISK}2"

echo "[guest] pacstrap..."
# README minimum, plus what vm.sh needs to get the repo in and drive it
mapfile -t BASE_PACKAGES < <(grep -vE '^\s*#|^\s*$' "$SEED/base-packages.txt")
pacstrap -K /mnt "${BASE_PACKAGES[@]}"
genfstab -U /mnt >> /mnt/etc/fstab
# README step 3: mount subvolumes by name only, or snap-rollback's swap
# would leave fstab pointing at the old root's subvolid
sed -i -E 's/,subvolid=[0-9]+//; s/subvolid=[0-9]+,//' /mnt/etc/fstab

ROOT_UUID="$(blkid -s UUID -o value "${DISK}3")"
PUBKEY="$(cat "$SEED/authorized_keys")"

echo "[guest] Configuring inside chroot..."
arch-chroot /mnt /bin/bash -euo pipefail -s <<CHROOT
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo '$VM_HOST' > /etc/hostname

bootctl install
cat > /boot/loader/loader.conf <<LOADER
default arch.conf
timeout 0
LOADER
# rootflags=subvol=@ with an equals sign, see README step 4
cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux (camarena test VM)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rootflags=subvol=@ rw console=ttyS0 console=tty0
ENTRY

passwd -l root
useradd -m -G wheel '$VM_USER'
echo '$VM_USER:$VM_PASS' | chpasswd
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/10-vm-wheel
chmod 440 /etc/sudoers.d/10-vm-wheel
install -d -m700 -o '$VM_USER' -g '$VM_USER' /home/'$VM_USER'/.ssh
echo '$PUBKEY' > /home/'$VM_USER'/.ssh/authorized_keys
chown '$VM_USER:$VM_USER' /home/'$VM_USER'/.ssh/authorized_keys
chmod 600 /home/'$VM_USER'/.ssh/authorized_keys

systemctl enable NetworkManager sshd
CHROOT

swapoff "${DISK}2"
umount -R /mnt
echo "VM-INSTALL-OK"
sync
poweroff
