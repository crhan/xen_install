#!/bin/sh

PARTFILE="part_crhan"
DISK_NAME="data19"
DISK_GROUP="xendata"
DISK_PATH="/dev/${DISK_GROUP}/${DISK_NAME}"

cat $PARTFILE | fdisk $DISK_PATH
kpartx -a $DISK_PATH

mkfs.ext3 /dev/mapper/${DISK_NAME}p1
mkfs.ext3 /dev/mapper/${DISK_NAME}p2
mkfs.ext3 /dev/mapper/${DISK_NAME}p5
mkswap -L SWAP /dev/mapper/${DISK_NAME}p3
e2label /dev/mapper/${DISK_NAME}p1 "/boot"
e2label /dev/mapper/${DISK_NAME}p2 "/"
e2label /dev/mapper/${DISK_NAME}p5 "/home"

mkdir -p /tmp/crhan/${DISK_NAME}
mount /dev/mapper/${DISK_NAME}p2 /tmp/crhan/${DISK_NAME}
mkdir /tmp/crhan/${DISK_NAME}/boot
mkdir /tmp/crhan/${DISK_NAME}/home
mount /dev/mapper/${DISK_NAME}p1 /tmp/crhan/${DISK_NAME}/boot
mount /dev/mapper/${DISK_NAME}p5 /tmp/crhan/${DISK_NAME}/home
