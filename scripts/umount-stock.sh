#!/bin/bash

show_help() {
    echo "Usage: $0 <mount-root>"
    echo "Unmount extracted stock from specified mount root"
    echo
    echo "Options:"
    echo "  -h    Show this help message"
    exit 0
}

if [ "$1" = "-h" ]; then
    show_help
fi

if [ $# -ne 1 ]; then
    show_help
fi

ROOT=$1

echo Unmounting from $ROOT
echo
echo This script requires sudo operations and you maybe asked for password
echo

sudo umount "$ROOT/odm"
sudo umount "$ROOT/oem"
sudo umount "$ROOT/system_ext"
sudo umount "$ROOT/product"
sudo umount "$ROOT/vendor"
sudo umount "$ROOT/vendor_dlkm"

sudo umount "$ROOT"

echo Dropping all unused loop devices
sudo losetup -D


