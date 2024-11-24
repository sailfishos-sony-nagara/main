#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 <super-image>"
    echo "Unpack super image"
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

IMAGE=$(echo "$1"/super_*)
SDIR=$1/super

echo Unpacking file: $IMAGE
echo Target directory: $SDIR

mkdir -p "$SDIR"
lpunpack "$IMAGE" "$SDIR"

echo
echo "Super image $IMAGE unpacked into $SDIR"
echo