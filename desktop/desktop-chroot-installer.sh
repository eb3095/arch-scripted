#!/bin/bash

# Desktop Installaltion Script
# Version: 1.0
# Author: Eric Benner

# Assign arguments
drive={DRIVE}

# Check for UEFI
EFI=false
EFIVARS=/sys/firmware/efi/efivars
if [ -d "$EFIVARS" ]; then
    EFI=true
fi

# Set time zone
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime

# Set the clock
hwclock --systohc

# Configure locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen

# Generate locale
locale-gen

# Configure locale
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Set hostname
echo iMac > /etc/hostname

# Create Hosts file
echo "127.0.0.1      localhost" >> /etc/hosts
echo "::1            localhost" >> /etc/hosts
echo "127.0.1.1      arch.localdomain arch" >> /etc/hosts

# Make initramfs
mkinitcpio -p linux

# Install ABSOLUTE essentials
pacman -Sy wget git unzip zip base-devel grub zsh efibootmgr dosfstools os-prober mtools sudo --noconfirm

echo
echo "Enter a root password [ENTER]:"
read -s rootpw

# Set root password
echo root:"$rootpw" | chpasswd

echo
echo "Enter a user [ENTER]:"
read user

echo
echo "Enter a $user's password [ENTER]:"
read -s userpw

# Setup user
mkdir /home/$user
useradd -d /home/$user $user
echo $user:"$userpw" | chpasswd
chown -R $user:$user /home/$user
usermod -aG wheel $user

# Setup SUDOERS
sed -i -e 's/# %wheel ALL=(ALL) NOPASSWD\: ALL/%wheelnpw ALL=(ALL) NOPASSWD\: ALL/' /etc/sudoers
sed -i -e 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
groupadd wheelnpw

# Setup installer
useradd installer
usermod -aG wheelnpw installer
mkdir /home/installer
chown installer:installer /home/installer

# Install Grub
if [ "$EFI" = true ] ; then
  grub-install --target=x86_64-efi  --bootloader-id=grub_uefi
else
  grub-install --target=i386-pc $drive
fi

# Generate Grub
grub-mkconfig -o /boot/grub/grub.cfg

# Install trizen
pushd /tmp
git clone https://aur.archlinux.org/trizen.git
popd
chmod -R 777 /tmp/trizen
runuser -l installer -c 'cd /tmp/trizen;makepkg -si --noconfirm'
rm -rf /tmp/trizen

# Install packages
PACKAGES=`cat /root/packages.txt`
runuser -l installer -c "trizen -Sy --noconfirm ${PACKAGES}"
runuser -l installer -c 'trizen --remove --noconfirm kwrite konsole konqueror kmail'

# Fix permissions for iw
setcap cap_net_raw,cap_net_admin=eip /usr/bin/iwconfig

# Enable/Disable services
systemctl enable ufw
systemctl enable sddm
systemctl enable sshd
systemctl enable NetworkManager
systemctl disable dhcpcd


# Configure Firewall
ufw enable
ufw default deny incoming
ufw allow 22

# Dispose of installer user
userdel installer
rm -rf /home/installer

# Cleanup
rm /root/desktop-chroot-installer.sh
rm /root/bootstrap.sh
