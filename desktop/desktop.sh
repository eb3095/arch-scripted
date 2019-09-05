#!/bin/bash

# Desktop Installaltion Script
# Version: 1.0
# Author: Eric Benner

# Set the time and date
timedatectl set-ntp true

# Check for UEFI
EFI=false
EFIVARS=/sys/firmware/efi/efivars
if [ -d "$EFIVARS" ]; then
    EFI=true
fi

echo
echo "WARNING: THIS WILL WIPE THE DRIVE"
echo "What drive do you want to install to? (/dev/sda) [ENTER]:"
read drive

# Partition drive
if [ "$EFI" = true ] ; then
  parted --script $drive mklabel gpt
  parted --script $drive mkpart primary fat32 1MiB 261MiB
  parted --script $drive set 1 esp on
  parted --script $drive mkpart primary linux-swap 261MiB 8.3GiB
  parted --script $drive mkpart primary ext4 8.3GiB 100%
  mkfs.fat -F32 "$drive"1
else
  parted --script $drive mklabel msdos
  parted --script $drive set 1 boot on
  parted --script $drive mkpart primary linux-swap 1MiB 8GiB
  parted --script $drive mkpart primary ext4 8GiB 100%
  mkfs.ext4 -F "$drive"1
fi

# Format drive
if [ "$EFI" = true ] ; then
  mkswap "$drive"2
  swapon "$drive"2
  mkfs.ext4 -F "$drive"3
  mount "$drive"3 /mnt
  mkdir -p /mnt/boot/efi
  mount "$drive"1 /mnt/boot/efi
else
  mkswap "$drive"1
  swapon "$drive"1
  mkfs.ext4 -F "$drive"2
  mount "$drive"2 /mnt
fi

# Install base
pacstrap /mnt base

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Download script
wget https://raw.githubusercontent.com/eb3095/arch-scripted/master/desktop/desktop-chroot-installer.sh
mv desktop-chroot-installer.sh /mnt/root/desktop-chroot-installer.sh
chmod +x /mnt/root/desktop-chroot-installer.sh

# Download package list
wget https://raw.githubusercontent.com/eb3095/arch-scripted/master/desktop/packages.txt
wget https://raw.githubusercontent.com/eb3095/arch-scripted/master/desktop/dev-packages.txt
wget https://raw.githubusercontent.com/eb3095/arch-scripted/master/desktop/virt-packages.txt
mv packages.txt /mnt/root/packages.txt
mv dev-packages.txt /mnt/root/dev-packages.txt
mv virt-packages.txt /mnt/root/virt-packages.txt

# Create bootstrap
echo '#!/bin/bash' >> /mnt/root/bootstrap.sh
echo "/root/desktop-chroot-installer.sh $drive" >> /mnt/root/bootstrap.sh
chmod +x /mnt/root/bootstrap.sh

# Chroot in and run second part
arch-chroot /mnt /root/bootstrap.sh
