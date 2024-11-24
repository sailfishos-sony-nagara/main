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

IMAGE=$1
SDIR=`dirname "$IMAGE"`/super
echo Unpacking into $SDIR

mkdir -p "$SDIR"
lpunpack "$IMAGE" "$SDIR"

echo "Super image $IMAGE unpacked into $SDIR"
