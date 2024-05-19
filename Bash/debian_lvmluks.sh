#!/bin/bash

<< DISABLEAUTOMOUNT-XFCE
xfconf-query -c thunar-volman -p /automount-drives/enabled -s false # disable drive automount
xfconf-query -c thunar-volman -p /automount-media/enabled -s false # disable media automount
xfconf-query -c thunar-volman -p /autobrowse/enabled -s false # disable thunar popping up
DISABLEAUTOMOUNT-XFCE

# << DESTROYPARTITION
dd if=/dev/zero of=/dev/nvme0n1 bs=4M status=progress count=256
dd if=/dev/zero of=/dev/mmcblk0 bs=4M status=progress count=256
# DESTROYPARTITION

# << PARTITION
wipefs -a /dev/nvme0n1
parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 mkpart primary fat32 0% 501MB
parted /dev/nvme0n1 mkpart primary ext4 501MB 2000MB
parted /dev/nvme0n1 mkpart primary btrfs 2000MB 100%
parted /dev/nvme0n1 name 1 EFI
parted /dev/nvme0n1 name 2 BOOT
parted /dev/nvme0n1 name 3 THINKPAD
parted /dev/nvme0n1 set 1 esp on
parted /dev/nvme0n1 unit MB print

wipefs -a /dev/mmcblk0
parted /dev/mmcblk0 mklabel gpt
parted /dev/mmcblk0 mkpart primary btrfs 0% 100%
parted /dev/mmcblk0 name 1 SDCARD
parted /dev/mmcblk0 unit MB print

lsblk
# PARTITION

# <<ENCRYPT
echo Enter passphrase to encrypt/decrypt disks
read cryptpass
echo -n $cryptpass | cryptsetup luksFormat --type luks2 --hash=sha512 --key-size=512 --cipher=aes-xts-plain64 /dev/nvme0n1p3 -d -
echo -n $cryptpass | cryptsetup luksOpen /dev/nvme0n1p3 crypt_thinkpad -d -
echo -n $cryptpass | cryptsetup luksFormat --type luks2 --hash=sha512 --key-size=512 --cipher=aes-xts-plain64 /dev/mmcblk0p1 -d -
echo -n $cryptpass | cryptsetup luksOpen /dev/mmcblk0p1 crypt_sdcard -d -

ls /dev/mapper/
# ENCRYPT

# << LVMONLUKS
pvcreate /dev/mapper/crypt_thinkpad
vgcreate vg_thinkpad /dev/mapper/crypt_thinkpad
lvcreate -L 4000000000B -n lv_swap vg_thinkpad
lvcreate -l 100%FREE -n lv_root vg_thinkpad

pvcreate /dev/mapper/crypt_sdcard
vgcreate vg_sdcard /dev/mapper/crypt_sdcard
lvcreate -l 100%FREE -n lv_data vg_sdcard

pvs
vgs
lvs
# LVMONLUKS

# << FORMAT
mkfs.fat -n EFI -F 32 /dev/nvme0n1p1
mkfs.ext4 -F -L BOOT /dev/nvme0n1p2
mkswap -L SWAP /dev/mapper/vg_thinkpad-lv_swap
# FORMAT

<< EXTFORMAT
mkfs.ext4 -L ROOT /dev/mapper/vg_thinkpad-lv_root
mkfs.ext4 -F -L DATA /dev/mapper/vg_sdcard-lv_data
EXTFORMAT

# << BTRFSFORMAT
mkfs.btrfs -f -L ROOT /dev/mapper/vg_thinkpad-lv_root
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvolid=5 /dev/mapper/vg_thinkpad-lv_root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@tmp

mkdir -p /mnt/@/media/sdcard
mkfs.btrfs -f -L DATA /dev/mapper/vg_sdcard-lv_data
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvolid=5 /dev/mapper/vg_sdcard-lv_data /mnt/@/media/sdcard
btrfs subvolume create /mnt/@/media/sdcard/@data

btrfs subvolume list /mnt
btrfs subvolume list /mnt/@/media/sdcard
umount -R /mnt
# BTRFSFORMAT

# << INSTALLER-UBUNTU
ubiquity
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@ /dev/mapper/vg_thinkpad-lv_root /mnt
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvolid=@data /dev/mapper/vg_sdcard-lv_data /mnt/@/media/sdcard
for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done # if not running as sudo user then run - for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done

export UUIDCRYPT1=$(blkid -s UUID -o value /dev/nvme0n1p3) #this is an environmental variable
echo "crypt_thinkpad UUID=${UUIDCRYPT1} none luks,discard" >> /mnt/etc/crypttab
export UUIDCRYPT2=$(blkid -s UUID -o value /dev/mmcblk0p1) #this is an environmental variable
echo "crypt_sdcard UUID=${UUIDCRYPT2} none luks,discard" >> /mnt/etc/crypttab
nano /mnt/etc/crypttab

nano /mnt/etc/fstab # remove extra entries

chroot /mnt <<END
mkdir -p /.snapshots

echo '# / was on /dev/nvme0n1p3 during installation' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_swap   none          swap    sw                                                                               0   0' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /             btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@           0   0' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /home         btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@home       0   0' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /.snapshots   btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@snapshots  0   0' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /var/log      btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@log        0   0' >> /etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /tmp          btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@tmp        0   0' >> /etc/fstab
echo '/dev/mapper/vg_sdcard-lv_data     /media/sdcard btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@data       0   0' >> /etc/fstab

mount -av
btrfs subvolume list /
btrfs subvolume list /media/sdcard/

echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

apt install -y --reinstall grub-efi-amd64-signed
# apt install -y --reinstall linux-generic-hwe-22.04 linux-headers-generic-hwe-22.04
update-initramfs -c -k all
grub-install /dev/nvme0n1
update-grub
END

df -h
# INSTALLER-UBUNTU

<<BOOTSTRAP-DEBIAN
# << MOUNTBOOTSTRAP
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@ /dev/mapper/vg_thinkpad-lv_root /mnt
mkdir -p /mnt/home
mkdir -p /mnt/.snapshots
mkdir -p /mnt/var/log
mkdir -p /mnt/tmp
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@home /dev/mapper/vg_thinkpad-lv_root /mnt/home
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@snapshots /dev/mapper/vg_thinkpad-lv_root /mnt/.snapshots
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@log /dev/mapper/vg_thinkpad-lv_root /mnt/var/log
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@tmp /dev/mapper/vg_thinkpad-lv_root /mnt/tmp
mount -o defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvolid=@data /dev/mapper/vg_sdcard-lv_data /mnt/@/media/sdcard
mkdir -p /mnt/boot
mount /dev/nvme0n1p2 /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi

for i in /dev /dev/pts /proc /sys /run; do mount -B $i /mnt$i; done # if not running as sudo user then run - for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done
# for dir in sys dev proc; do mount --rbind /$dir /mnt/$dir && mount --make-rslave /mnt/$dir ; done

lsblk
# MOUNTBOOTSTRAP

# << INSTALLBOOTSTRAP
apt install debootstrap
debootstrap stable /mnt http://deb.debian.org/debian/

cp /etc/apt/sources.list /mnt/etc/apt
nano /mnt/etc/apt/sources.list
echo 'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '# deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '' >> /mnt/etc/apt/sources.list
echo 'deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '# deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '' >> /mnt/etc/apt/sources.list
echo 'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '# deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '' >> /mnt/etc/apt/sources.list
echo 'deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
echo '# deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware' >> /mnt/etc/apt/sources.list
nano /mnt/etc/apt/sources.list

export UUIDCRYPT1=$(blkid -s UUID -o value /dev/nvme0n1p3) #this is an environmental variable
echo "crypt_thinkpad UUID=${UUIDCRYPT1} none luks,discard" >> /mnt/etc/crypttab
export UUIDCRYPT2=$(blkid -s UUID -o value /dev/mmcblk0p1) #this is an environmental variable
echo "crypt_sdcard UUID=${UUIDCRYPT2} none luks,discard" >> /mnt/etc/crypttab
nano /mnt/etc/crypttab

cp /etc/resolv.conf /mnt/etc/
cp /proc/mounts /mnt/etc/fstab

echo '# / was on /dev/nvme0n1p3 during installation' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_swap   none          swap    sw                                                                               0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /             btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@           0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /home         btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@home       0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /.snapshots   btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@snapshots  0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /var/log      btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@log        0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_thinkpad-lv_root   /tmp          btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@tmp        0   0' >> /mnt/etc/fstab
echo '/dev/mapper/vg_sdcard-lv_data     /media/sdcard btrfs   defaults,noatime,space_cache=v2,compress=zstd:1,discard=async,subvol=@data       0   0' >> /mnt/etc/fstab

nano /mnt/etc/fstab # remove extra entries

chroot /mnt <<END

mount -av
btrfs subvolume list /
btrfs subvolume list /media/sdcard/

apt update
apt install btrfs-progs
apt install locales
dpkg-reconfigure locales
apt install linux-image-amd64 sudo ntp network-manager vim nano intel-microcode
nano /etc/hostname
echo 'CAP-PF1L2UF0' >> /etc/hostname
nano /etc/hostname
nano /etc/hosts
echo '127.0.0.1 localhost' >> /etc/hosts
echo '::1       localhost' >> /etc/hosts
echo '127.0.1.1 CAP-PF1L2UF0.capellan.lan    CAP-PF1L2UF0' >> /etc/hosts
nano /etc/hosts
dpkg-reconfigure tzdata
useradd -mG sudo begster
passwd begster
systemctl enable NetworkManager

# echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

apt install grub-efi-amd64
update-initramfs -c -k all
grub-install /dev/nvme0n1
update-grub
END

df -h
# INSTALLBOOTSTRAP
BOOTSTRAP-DEBIAN


<< URL
https://linuxconfig.org/how-to-install-debian-on-an-existing-luks-container
https://mutschler.dev/linux/ubuntu-btrfs-20-04/
https://leo3418.github.io/collections/gentoo-config-luks2-grub-systemd/tune-parameters.html
https://help.ubuntu.com/community/Full_Disk_Encryption_Howto_2019
https://www.reddit.com/r/linuxquestions/comments/9unyl8/multiple_drives_encryption_with_lvm_over_luks/
https://linuxconfig.org/install-debian-server-in-a-linux-chroot-environment
https://github.com/aomgiwjc/Unix-Bootstrap-Installs/wiki/Debian-Bootstrap-Chroot-Install---Ext4,-one-drive
https://www.linuxquestions.org/questions/linux-security-4/how-to-pass-password-to-cryptsetup-from-a-memory-variable-4175528760/
URL


<< FSTAB

# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/mapper/vg_thinkpad-lv_root /               btrfs   defaults,subvol=@ 0       1
# /boot was on /dev/nvme0n1p2 during installation
UUID=2c83b6fb-3f50-4b0c-ad81-be85c87851f4 /boot           ext4    defaults        0       2
# /boot/efi was on /dev/nvme0n1p1 during installation
UUID=0D89-10FB  /boot/efi       vfat    umask=0077      0       1
/dev/mapper/vg_thinkpad-lv_root /home           btrfs   defaults,subvol=@home 0       2
/dev/mapper/vg_sdcard-lv_data /media/sdcard     btrfs   defaults        0       2
/dev/mapper/vg_thinkpad-lv_swap none            swap    sw              0       0

FSTAB
