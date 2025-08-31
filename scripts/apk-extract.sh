#!/bin/bash

# Script to extract APK using jadx
# Usage: ./extract_apk.sh <output_directory> <path_to_apk>

set -e

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <output_directory> <path_to_apk1> [path_to_apk2] [path_to_apk3] ..."
    exit 1
fi

OUTPUT_DIR="$1"
shift  # Remove first argument, leaving only APK paths

# Check if jadx is installed
if ! command -v jadx &> /dev/null; then
    echo "Error: jadx is not installed or not in PATH"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Starting extraction of $(($# )) APK(s) to: $OUTPUT_DIR"
echo "=========================================="

# Process each APK
for APK_PATH in "$@"; do
    echo ""
    echo "Processing: $(basename "$APK_PATH")"

    # Check if APK file exists
    if [ ! -f "$APK_PATH" ]; then
        echo "Error: APK file '$APK_PATH' does not exist"
        continue
    fi

    APK_BASENAME=$(basename "$APK_PATH" .apk)
    FULL_OUTPUT_DIR="$OUTPUT_DIR/$APK_BASENAME"

    if [[ $OVERWRITE_ALL == true ]] && [ -d "$FULL_OUTPUT_DIR" ]; then
        rm -rf "$FULL_OUTPUT_DIR"
    elif [ -d "$FULL_OUTPUT_DIR" ]; then
        echo "Warning: Directory '$APK_BASENAME' already exists"
        read -p "Do you want to overwrite it? (y/N/a for all): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Aa]$ ]]; then
            # Set flag to overwrite all subsequent conflicts
            OVERWRITE_ALL=true
        elif [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipped: $APK_BASENAME"
            ((SKIPPED++))
            continue
        fi
        rm -rf "$FULL_OUTPUT_DIR"
    fi

    echo "Extracting to: $APK_BASENAME/"

    if jadx -d "$FULL_OUTPUT_DIR" "$APK_PATH" > /dev/null 2>&1; then
        echo "✓ Successfully extracted: $APK_BASENAME"
    else
        echo "✗ Failed to extract: $APK_BASENAME"
        exit 1
    fi
done

