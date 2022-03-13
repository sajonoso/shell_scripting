#!/bin/sh

# Minimal Debian/Centos system installer
## NOTE: Set target disk before running this script


# REDHAT/CENTOS BOOT
# In grub boot menu add boot option `rescue ip=dhcp inst.sshd=1`

# DEBIAN BOOT
# Boot into rescue mode, hit enter a few times to go past language, keyboard selection

# OS installer script.  Get this file into your shell and run
# cd /tmp
# wget http://192.168.56.1/inst.sh
# chmod +arx inst.sh
# ./inst.sh debsetup | rhsetup
# ./inst.sh umount
# reboot


##### update variables here for your environment #####
export TARGET='/mnt/target'
export TARGET_DISK=sda
export TARGET_BOOT=${TARGET_DISK}1
export TARGET_OS=${TARGET_DISK}2
export CDROM_MOUNT=/media/cdrom
# export NETWORK_SOURCE=http://192.168.56.1
export NETWORK_SOURCE=http://10.0.2.2



##### DO NOT CHANGE BELOW #####

echo "Target Partition: $TARGET_OS"

disk_partition() {
  (
  echo o # Create a new empty DOS partition table
  echo w # Write changes
  ) | fdisk /dev/$TARGET_DISK

  # Partition disk
  (
  echo o # Create a new empty DOS partition table
  echo n # Add a new partition
  echo p # Primary partition
  echo 1 # Partition number
  echo   # First sector (Accept default: 1)
  echo +100M  # Last sector (Accept default: varies)
  echo a # make partition bootable
  echo n # Add a new partition
  echo p # Primary partition
  echo 2 # Partition number
  echo   # First sector (Accept default: 1)
  echo   # Last sector (Accept default: varies)
  echo w # Write changes
  ) | fdisk /dev/$TARGET_DISK

  # Format disk
  mkfs.ext4 -F -L BOOT /dev/$TARGET_BOOT
  mkfs.ext4 -F -L OS /dev/$TARGET_OS
}

mount_cd() {
  echo "# Mounting CD"
  mkdir -p $CDROM_MOUNT
  mount /dev/sr0 $CDROM_MOUNT
}

disk_mount() {
  if [ ! -e $TARGET ]; then mkdir $TARGET; fi
  mount -t ext4 /dev/sda2 $TARGET
  if [ ! -e $TARGET/boot ]; then mkdir $TARGET/boot; fi
  mount -t ext4 /dev/sda1 $TARGET/boot

  mkdir $TARGET/dev $TARGET/sys $TARGET/proc
  mkdir -p ${TARGET}${CDROM_MOUNT}

  mount -t proc proc $TARGET/proc
  mount -t sysfs sys $TARGET/sys
  mount -o bind /dev $TARGET/dev
  mount -o bind $CDROM_MOUNT ${TARGET}${CDROM_MOUNT}

  echo "Target disk mounted"
}

disk_umount() {
  umount ${TARGET}${CDROM_MOUNT} $TARGET/dev $TARGET/sys $TARGET/proc $TARGET/boot $TARGET

  echo "Target disk unmounted"
}

common_setup() {
  if [ ! -e $TARGET/etc ]; then mkdir $TARGET/etc; fi

  # add fstab file
  echo -e "UUID=$(blkid -s UUID -o value /dev/$TARGET_OS) / ext4 errors=remount-ro 0 1\n" > $TARGET/etc/fstab
  echo -e "UUID=$(blkid -s UUID -o value /dev/$TARGET_BOOT) /boot ext4 errors=remount-ro 0 2\n" >> $TARGET/etc/fstab

  # add hostname
  echo "localhost" > $TARGET/etc/hostname
  echo -e "127.0.0.1\tlocalhost" > $TARGET/etc/hosts
}

update_script() {
  wget $NETWORK_SOURCE/inst.sh -O inst.sh
}

do_chroot() {
  chroot $TARGET /bin/bash
}

#########  Debain setup

dsetup1() {
  export DEBIAN_FRONTEND=noninteractive

  # Setup CD source
  mkdir -p $TARGET/etc/apt/sources.list.d
  echo "deb [trusted=yes] file://$CDROM_MOUNT buster main" > $TARGET/etc/apt/sources.list.d/netinstcd.list

  # Install packages into target system
  # --variant=minbase --include=locales,tzdata    perl-base,mawk,bash,dash,tar,gzip
  # --exclude="bash,perl-base"
  debootstrap --no-check-gpg --variant=minbase --include=busybox buster $TARGET file://$CDROM_MOUNT

  # Bug fix
  echo "file://$CDROM_MOUNT" > $TARGET/debootstrap/mirror
  
  # Complete debootstrap second stage
  chroot $TARGET /bin/dash /debootstrap/debootstrap --second-stage
}

dsetup2() {
chroot $TARGET /bin/busybox ash <<EOF
  apt install --no-install-recommends -y linux-image-amd64 systemd init
  apt install --no-install-recommends -y ifupdown dhcp-client openssh-server
  echo -e "\nauto enp0s3\niface enp0s3 inet dhcp\n" >> /etc/network/interfaces
  echo "root:changeme" | chpasswd
  useradd -m user
  echo "user:changeme" | chpasswd
EOF
}

dsetup3() {
chroot $TARGET /bin/busybox ash <<EOF
  apt install --no-install-recommends -y grub-pc
EOF
}

dsetup4() {
chroot $TARGET /bin/busybox ash <<EOF
  mkdir /boot/grub
  grub-mkconfig -o /boot/grub/grub.cfg
  grub-install /dev/$TARGET_DISK
EOF
}

debsetup() {
  cd /tmp
  disk_partition
  mount_cd
  disk_mount
  dsetup1
  common_setup
  dsetup2
  dsetup3
  dsetup4
}

debtest() {
  echo "apt install --no-install-recommends init systemd nano sudo initramfs-tools linux-image-amd64 openssh-server" > $TARGET/setup
  chmod a+rwx $TARGET/setup
  chroot $TARGET /bin/bash
}


#########  Redhat setup

rhsetup_one() {
  # set dnf repository
  mkdir /etc/yum.repos.d
  echo "[mirror.aarnet.edu.au_pub_centos_8_BaseOS]
name=mirror.aarnet.edu.au_BaseOS
baseurl=http://mirror.aarnet.edu.au/pub/centos/8.1.1911/BaseOS/x86_64/os/
enabled=1
" > /etc/yum.repos.d/aarnet.repo

  mkdir -p $TARGET/etc/yum.repos.d
  cp /etc/yum.repos.d/aarnet.repo $TARGET/etc/yum.repos.d/aarnet.repo
  
  rpm --root $TARGET --initdb
  rpm --root $TARGET --nodeps -ivh $NETWORK_SOURCE/centos-release-8.1-1.1911.0.9.el8.x86_64.rpm
  rpm --root $TARGET --nodeps -ivh $NETWORK_SOURCE1/centos-gpg-keys-8.1-1.1911.0.9.el8.noarch.rpm
  rpm --root $TARGET --import  $TARGET/etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
}

rhinstall() {
  cd /tmp
# dnf --installroot=$TARGET --downloadonly --downloaddir ./pkg/ --setopt=install_weak_deps=False install \
# glibc-minimal-langpack bash grub2-pc nano dnf openssh-server openssh-clients iputils iproute dhcp-client tar

  wget $NETWORK_SOURCE/pkg.tgz
  tar -zxvf pkg.tgz
  rm pkg.tgz
  cd pkg
  dnf --installroot=$TARGET --setopt=tsflags='nodocs' --setopt=install_weak_deps=False --disablerepo="*" -y install glibc-minimal-langpack*.rpm *.rpm
  cd ..
}

rhsetup_two() {
  cd $TARGET/root
  wget $NETWORK_SOURCE/kernel-core-4.18.0-147.8.1.el8_1.x86_64.rpm
  cd /tmp
chroot $TARGET /bin/bash <<EOF
  rpm --nodeps -ivh /root/kernel-core-4.18.0-147.8.1.el8_1.x86_64.rpm
  echo "root:changeme" | chpasswd
EOF
}

rhsetup_three() {
chroot $TARGET /bin/bash <<EOF
 grub2-mkconfig -o /boot/grub2/grub.cfg
 grub2-install /dev/${TARGET_DISK}
EOF
}

rhsetup() {
  cd /tmp
  disk_partition
  mount_cd
  disk_mount
  rhsetup_one
  rhinstall
  rhsetup_two
  common_setup
  rhsetup_three
}


# Common functions
if [ "$1" == "part" ]; then disk_partition; exit; fi
if [ "$1" == "mountcd" ]; then mount_cd; exit; fi
if [ "$1" == "mount" ]; then disk_mount; exit; fi
if [ "$1" == "umount" ]; then disk_umount; exit; fi
if [ "$1" == "update" ]; then update_script; exit; fi
if [ "$1" == "chroot" ]; then do_chroot; exit; fi

if [ "$1" == "common" ]; then common_setup; exit; fi

# Debian Install commands
if [ "$1" == "debtest" ]; then debtest; exit; fi
if [ "$1" == "dsetup1" ]; then dsetup1; exit; fi
if [ "$1" == "dsetup2" ]; then dsetup2; exit; fi
if [ "$1" == "dsetup3" ]; then dsetup3; exit; fi
if [ "$1" == "dsetup4" ]; then dsetup4; exit; fi
if [ "$1" == "debsetup" ]; then debsetup; exit; fi

# RH Install commands
if [ "$1" == "rhsetup1" ]; then rhsetup_one; exit; fi
if [ "$1" == "rhsetup2" ]; then rhsetup_two; exit; fi
if [ "$1" == "rhsetup3" ]; then rhsetup_three; exit; fi
if [ "$1" == "rhinstall" ]; then rhinstall ${*:2}; exit; fi
if [ "$1" == "rhsetup" ]; then rhsetup; exit; fi


echo "Command does not exist"
