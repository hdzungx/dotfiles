#!/bin/bash
# Script 1: minimal Arch base install. Run as root from the Arch live ISO (UEFI).
set -euo pipefail
trap 'echo "Error on line $LINENO. Aborting." >&2' ERR

TIMEZONE="Asia/Ho_Chi_Minh"

[[ $EUID -eq 0 ]] || { echo "Run this as root."; exit 1; }
[[ -d /sys/firmware/efi/efivars ]] || { echo "Not booted in UEFI mode."; exit 1; }

ask() { read -rp "$1" "$2" </dev/tty; }

ask_pass() {
    local p1 p2
    while true; do
        IFS= read -rsp "$1: " p1 </dev/tty; echo
        IFS= read -rsp "Confirm: " p2 </dev/tty; echo
        [[ -n $p1 && $p1 == "$p2" ]] && break
        echo "Empty or mismatched password (typed ${#p1} vs ${#p2} characters), try again."
    done
    printf -v "$2" '%s' "$p1"
}

# ---------- Collect all input up front ----------
lsblk -dpno NAME,SIZE,MODEL
while true; do
    ask "Disk to format (e.g. /dev/nvme0n1, /dev/sda): " DISK
    [[ -b $DISK ]] && break
    echo "Cannot find $DISK."
done

while true; do
    ask "Hostname: " HOST_NAME
    [[ $HOST_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] && break
    echo "Invalid hostname."
done

while true; do
    ask "Username: " USER_NAME
    [[ $USER_NAME =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
    echo "Invalid username (lowercase letters, digits, _ or -)."
done

ask_pass "Root password" ROOT_PASS
ask_pass "Password for $USER_NAME" USER_PASS

ask "This will ERASE ALL DATA on $DISK. Type 'yes' to continue: " CONFIRM
[[ $CONFIRM == yes ]] || { echo "Cancelled."; exit 1; }

# ---------- Partitioning ----------
timedatectl set-ntp true

SWAP_MB=$(awk '/MemTotal/ {printf "%d", $2 / 1024 / 2}' /proc/meminfo)

wipefs -af "$DISK"
sgdisk -Z "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:EFI  "$DISK"
sgdisk -n 2:0:+"${SWAP_MB}M" -t 2:8200 -c 2:SWAP "$DISK"
sgdisk -n 3:0:0 -t 3:8300 -c 3:ROOT "$DISK"
partprobe "$DISK"
udevadm settle

# nvme0n1 -> nvme0n1p1, mmcblk0 -> mmcblk0p1, sda -> sda1
P=""
[[ $DISK == *[0-9] ]] && P="p"
PART_EFI="${DISK}${P}1"
PART_SWAP="${DISK}${P}2"
PART_ROOT="${DISK}${P}3"

mkfs.fat -F32 "$PART_EFI"
mkswap "$PART_SWAP"
mkfs.ext4 -F "$PART_ROOT"

mount "$PART_ROOT" /mnt
mount -o fmask=0077,dmask=0077 --mkdir "$PART_EFI" /mnt/boot
swapon "$PART_SWAP"

# ---------- Install ----------
UCODE=""
grep -q GenuineIntel /proc/cpuinfo && UCODE="intel-ucode"
grep -q AuthenticAMD /proc/cpuinfo && UCODE="amd-ucode"

pacstrap -K /mnt base linux linux-firmware $UCODE \
    networkmanager dosfstools sudo zsh zsh-completions neovim git

genfstab -U /mnt >> /mnt/etc/fstab

ROOT_PARTUUID=$(blkid -s PARTUUID -o value "$PART_ROOT")

# ---------- Configure inside chroot ----------
arch-chroot /mnt env \
    HOST_NAME="$HOST_NAME" USER_NAME="$USER_NAME" \
    TIMEZONE="$TIMEZONE" ROOT_PARTUUID="$ROOT_PARTUUID" UCODE="$UCODE" \
    bash -s <<'EOF'
set -euo pipefail

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "$HOST_NAME" > /etc/hostname

useradd -m -G wheel,audio,video -s /bin/zsh "$USER_NAME"
# Empty .zshrc so zsh does not launch its first-run wizard before script 2 runs
install -o "$USER_NAME" -g "$USER_NAME" -m 644 /dev/null "/home/$USER_NAME/.zshrc"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

bootctl install
cat > /boot/loader/loader.conf <<LOADER
default arch.conf
timeout 3
console-mode max
editor no
LOADER

mkdir -p /boot/loader/entries
{
    echo "title   Arch Linux"
    echo "linux   /vmlinuz-linux"
    [[ -n $UCODE ]] && echo "initrd  /$UCODE.img"
    echo "initrd  /initramfs-linux.img"
    echo "options root=PARTUUID=$ROOT_PARTUUID rw"
} > /boot/loader/entries/arch.conf

systemctl enable NetworkManager systemd-timesyncd systemd-boot-update.service
EOF

# Set passwords non-interactively (safe with special characters)
printf 'root:%s\n%s:%s\n' "$ROOT_PASS" "$USER_NAME" "$USER_PASS" | arch-chroot /mnt chpasswd

# bootctl inside a chroot can skip writing the UEFI boot entry; create it from the live system if missing
if ! efibootmgr | grep -qi "Linux Boot Manager"; then
    efibootmgr --create --disk "$DISK" --part 1 --label "Linux Boot Manager" \
        --loader '\EFI\systemd\systemd-bootx64.efi' >/dev/null \
        || echo "Warning: could not create UEFI entry; the firmware may still boot the fallback EFI/BOOT/BOOTX64.EFI."
fi

swapoff "$PART_SWAP"
umount -R /mnt

echo "Base install complete. Run 'reboot', remove the USB, log in as $USER_NAME,"
echo "connect to the network (nmtui), then run arch-post-install.sh."
