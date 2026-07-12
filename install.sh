#!/usr/bin/env bash
set -e

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

echo "Available drives:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v loop

echo ""
read -p "Enter the drive to format (e.g. /dev/sda, /dev/vda, /dev/nvme0n1): " DRIVE

if [ -z "$DRIVE" ] || [ ! -b "$DRIVE" ]; then
  echo "Invalid drive: $DRIVE"
  exit 1
fi

echo "WARNING: This will ERASE ALL DATA on $DRIVE! Type 'YES' to continue."
read -p "> " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
  echo "Aborting."
  exit 1
fi

# Determine partition names (nvme drives have a 'p' before the partition number)
if [[ "$DRIVE" == *nvme* ]] || [[ "$DRIVE" == *mmcblk* ]]; then
  PART_BOOT="${DRIVE}p1"
  PART_ROOT="${DRIVE}p2"
else
  PART_BOOT="${DRIVE}1"
  PART_ROOT="${DRIVE}2"
fi

echo "==> Partitioning $DRIVE..."
# Wipe the partition table and create a new GPT one
parted -s "$DRIVE" -- mklabel gpt
# Create 1GB EFI boot partition
parted -s "$DRIVE" -- mkpart ESP fat32 1MiB 1024MiB
parted -s "$DRIVE" -- set 1 esp on
# Create root partition with the rest of the drive
parted -s "$DRIVE" -- mkpart primary ext4 1024MiB 100%

echo "==> Formatting partitions..."
mkfs.fat -F 32 -n BOOT "$PART_BOOT"
mkfs.ext4 -L nixos "$PART_ROOT"

echo "==> Mounting partitions..."
mount "$PART_ROOT" /mnt
mount --mkdir "$PART_BOOT" /mnt/boot

echo "==> Generating NixOS hardware config..."
nixos-generate-config --root /mnt

echo "==> Cloning dotfiles..."
git clone https://github.com/davidyusaku-13/nixos-dotfiles.git /mnt/etc/nixos-dotfiles

echo "==> Injecting hardware config..."
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos-dotfiles/hosts/nixos-btw/
cd /mnt/etc/nixos-dotfiles
git add hosts/nixos-btw/hardware-configuration.nix

echo "==> Installing NixOS..."
# We pass --no-root-passwd so it prompts you interactively for the password at the end
nixos-install --flake /mnt/etc/nixos-dotfiles#nixos-btw

echo "==> Setting password for user 'david'..."
nixos-enter --root /mnt -c 'passwd david'

echo "==> Done! You can now type 'reboot'."
