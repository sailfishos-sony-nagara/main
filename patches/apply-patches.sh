#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_ROOT="$(pwd)"

echo "Applying patches from directories under: $SCRIPT_DIR"
echo "Working inside Android source root: $ANDROID_ROOT"
echo ""

# Find all .patch files, get their parent directories, and deduplicate
find "$SCRIPT_DIR" -type f -name '*.patch' | while read -r patch_file; do
    patch_dir="$(dirname "$patch_file")"
    rel_path="${patch_dir#$SCRIPT_DIR/}"

    # Only process each patch directory once
    if [ ! -d "$ANDROID_ROOT/$rel_path/.git" ]; then
        echo "Skipping $rel_path: Not a git repository"
        continue
    fi

    echo "Applying patches in: $rel_path"
    (
        cd "$ANDROID_ROOT/$rel_path"
        for patch in "$patch_dir"/*.patch; do
            echo "  Applying patch: $(basename "$patch")"
            git am "$patch" || {
                echo "  Failed to apply patch: $(basename "$patch"). Aborting."
                git am --abort
                exit 1
            }
        done
    )
    echo ""
done
