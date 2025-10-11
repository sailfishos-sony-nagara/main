#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(pwd)"

echo "Applying patches from directories under: $SCRIPT_DIR"
echo "Working inside Android source root: $ANDROID_ROOT"
echo ""

# Find all .patch files and sort them
find "$SCRIPT_DIR" -type f -name '*.patch' | sort | while read -r patch_file; do
    patch_dir="$(dirname "$patch_file")"
    rel_path="${patch_dir#$SCRIPT_DIR/}"

    # Check if target directory is a git repository
    if [ ! -d "$ANDROID_ROOT/$rel_path/.git" ]; then
        echo "Skipping $(basename "$patch_file"): $rel_path is not a git repository"
        continue
    fi

    echo "Applying patch: $rel_path/$(basename "$patch_file")"
    (
        cd "$ANDROID_ROOT/$rel_path"
        git am "$patch_file" || {
            echo "  Failed to apply patch: $(basename "$patch_file"). Aborting."
            git am --abort
            exit 1
        }
    )
    echo ""
done
