#!/bin/sh
# This script resizes your Android emulator userdata partition so it does not use the default 6Gb
# TIP: don't put spaces in your AVD names

# program locations
E2FSCK_PRG=~/Library/Android/sdk/emulator/bin64/e2fsck
RESIZE_PRG=~/Library/Android/sdk/emulator/bin64/resize2fs
TMP_FILE=~/ramdisk/temp.file

resize_avd_userdata() {
  IMAGE_NAME=$1
  NEW_SIZE_MB=3072
  SIZE_BYTES=$((NEW_SIZE_MB * 1024 * 1024))

  sed "s/disk.dataPartition.size = .*/disk.dataPartition.size = $SIZE_BYTES/" ~/.android/avd/$IMAGE_NAME.avd/config.ini > $TMP_FILE
  mv $TMP_FILE ~/.android/avd/$IMAGE_NAME.avd/config.ini
  sed "s/disk.dataPartition.size = .*/disk.dataPartition.size = $SIZE_BYTES/" ~/.android/avd/$IMAGE_NAME.avd/hardware-qemu.ini > $TMP_FILE
  mv $TMP_FILE ~/.android/avd/$IMAGE_NAME.avd/hardware-qemu.ini

  $E2FSCK_PRG -f ~/.android/avd/$IMAGE_NAME.avd/userdata-qemu.img
  $RESIZE_PRG ~/.android/avd/$IMAGE_NAME.avd/userdata-qemu.img ${NEW_SIZE_MB}M
}

if [ -d ~/.android/avd/$1.avd ]; then resize_avd_userdata $1; exit; fi
echo "AVD named $1 not found"
