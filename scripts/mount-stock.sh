#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 <extracted-stock> <mount-root>"
    echo "Mount extracted stock to specified mount root"
    echo
    echo "Options:"
    echo "  -h    Show this help message"
    exit 0
}

mount_on_loop() {
    LDEV=`sudo losetup -f --show -r "$1"`
    echo "Loop device:" $LDEV $1
    sudo mount -o ro "$LDEV" "$2"
}

if [ "$1" = "-h" ]; then
    show_help
fi

if [ $# -ne 2 ]; then
    show_help
fi

STOCK=$1
ROOT=$2

echo Extracted stock from $STOCK
echo Mounting to $ROOT
echo
echo This script requires sudo operations and you maybe asked for password
echo

mkdir -p "$ROOT"

mount_on_loop "$STOCK/super/system_a.img" "$ROOT"

mount_on_loop "$STOCK/super/odm_a.img" "$ROOT/odm"
mount_on_loop "$STOCK"/oem_*.img "$ROOT/oem"
mount_on_loop "$STOCK/super/system_ext_a.img" "$ROOT/system_ext"
mount_on_loop "$STOCK/super/product_a.img" "$ROOT/product"
mount_on_loop "$STOCK/super/vendor_a.img" "$ROOT/vendor"
mount_on_loop "$STOCK/super/vendor_dlkm_a.img" "$ROOT/vendor_dlkm"
