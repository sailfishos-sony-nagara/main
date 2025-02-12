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
VENDOR_MOUNT="$ROOT-vendor-stock"
OVERLAY_WORK="$ROOT-vendor-work"

echo "Unmounting from $ROOT"
echo
echo "This script requires sudo operations, and you may be asked for a password."
echo

# Unmount the overlay vendor first
if mountpoint -q "$ROOT/vendor"; then
    sudo umount "$ROOT/vendor"
fi

# Unmount separately mounted vendor stock
if mountpoint -q "$VENDOR_MOUNT"; then
    sudo umount "$VENDOR_MOUNT"
fi

# Unmount all other partitions
for mnt in odm oem system_ext product vendor_dlkm; do
    if mountpoint -q "$ROOT/$mnt"; then
        sudo umount "$ROOT/$mnt"
    fi
done

# Unmount root system
if mountpoint -q "$ROOT"; then
    sudo umount "$ROOT"
fi

# Remove overlay work directory
rm -rf "$OVERLAY_WORK"

echo "Dropping all unused loop devices"
sudo losetup -D

echo "Unmounting completed."
