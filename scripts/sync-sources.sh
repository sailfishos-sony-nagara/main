#!/bin/bash

# Sync Android sources and apply all required patches

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPLY_PATCHES_SCRIPT="$SCRIPT_DIR/../patches/apply-patches.sh"

# Check if ANDROID_ROOT is set
if [ -z "$ANDROID_ROOT" ]; then
    echo "Error: ANDROID_ROOT environment variable is not set"
    exit 1
fi

# Change to ANDROID_ROOT directory
cd "$ANDROID_ROOT"

# Sync sources
repo sync "$@"

# Set environment
source build/envsetup.sh

# Apply repopicks
REPOPICKS="423299 423083 410938 423304 419385"
for repopick_id in $REPOPICKS; do
    repopick -f "$repopick_id"
done

# Apply Hybris patches
hybris-patches/apply-patches.sh --mb

# Apply Nagara patches using patches/apply-patches.sh
"$APPLY_PATCHES_SCRIPT"
