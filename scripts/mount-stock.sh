#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 <extracted-stock> <mount-root> <vendor-overlay>"
    echo "Mount extracted stock to specified mount root with vendor overlay"
    echo
    echo "Options:"
    echo "  -h    Show this help message"
    exit 0
}

mount_on_loop() {
    local img_path="$1"
    local mount_point="$2"

    LDEV=$(sudo losetup -f --show -r "$img_path")
    echo "Loop device:" $LDEV $img_path
    sudo mount -o ro "$LDEV" "$mount_point"
}

if [ "$1" = "-h" ]; then
    show_help
fi

if [ $# -ne 3 ]; then
    show_help
fi

STOCK=$1
ROOT=$2
OVERLAY_VENDOR=$3

# Ensure overlay vendor folder exists
if [ ! -d "$OVERLAY_VENDOR" ]; then
    echo "Error: Vendor overlay folder $OVERLAY_VENDOR does not exist."
    exit 1
fi

VENDOR_MOUNT="$ROOT-vendor-stock"      # Separate read-only mount for original vendor
OVERLAY_WORK="$ROOT-vendor-work"       # Required work dir for overlayfs

echo "Extracted stock from $STOCK"
echo "Mounting to $ROOT"
echo "Applying vendor overlay from $OVERLAY_VENDOR"
echo
echo "This script requires sudo operations, and you may be asked for a password."
echo

mkdir -p "$ROOT"
mkdir -p "$VENDOR_MOUNT"

# Ensure overlay work directory is clean
rm -rf "$OVERLAY_WORK"
mkdir -p "$OVERLAY_WORK"

# Mount stock partitions
mount_on_loop "$STOCK/super/system_a.img" "$ROOT"
mount_on_loop "$STOCK/super/odm_a.img" "$ROOT/odm"
mount_on_loop "$STOCK"/oem_*.img "$ROOT/oem"
mount_on_loop "$STOCK/super/system_ext_a.img" "$ROOT/system_ext"
mount_on_loop "$STOCK/super/product_a.img" "$ROOT/product"
mount_on_loop "$STOCK/super/vendor_a.img" "$VENDOR_MOUNT"  # Mount vendor separately
mount_on_loop "$STOCK/super/vendor_dlkm_a.img" "$ROOT/vendor_dlkm"

# Mount overlay directly at $ROOT/vendor
sudo mount -t overlay overlay -o lowerdir="$VENDOR_MOUNT",upperdir="$OVERLAY_VENDOR",workdir="$OVERLAY_WORK" "$ROOT/vendor"

echo "Vendor directory at $ROOT/vendor now includes files from $OVERLAY_VENDOR."
