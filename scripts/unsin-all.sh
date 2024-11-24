#!/bin/bash

set -e

show_help() {
    echo "Usage: $0 <stock-firmware> <target-directory>"
    echo "Apply UnSin to all .sin files in stock firmware directory and create target directory with image files"
    echo
    echo "Options:"
    echo "  -h    Show this help message"
    exit 0
}

if [ "$1" = "-h" ]; then
    show_help
fi

if [ $# -ne 2 ]; then
    show_help
fi

STOCK=$1
TARGET=$2

mkdir -p "$TARGET"

pushd "$TARGET"
T=`pwd`
popd

pushd "$STOCK"
for i in *.sin; do
    echo "Processing:" $i
    unsin $i
    mv "${i%.*}".img "$T"
done
popd
