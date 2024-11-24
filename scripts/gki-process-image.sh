#!/bin/bash

# # This script will convert Google GKI boot.img into a 
# a boot image that is packed in a way which is expected for nagara

# DO NOT USE THIS SCRIPT WITHOUT ADJUSTING PARAMETERS
# - set the PATH to point towards Android sources
# - check fingerprint below

PATH=android-14_r67/out/host/linux-x86/bin:$PATH

# Check if the script received an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <boot_image_zip_file>"
    exit 1
fi

# Input zip file
BOOT_ZIP_FILE="$1"
if [[ ! -f "$BOOT_ZIP_FILE" ]]; then
    echo "Error: File '$BOOT_ZIP_FILE' not found!"
    exit 1
fi

# Extract the base name and target image name
BASE_NAME=$(basename "$BOOT_ZIP_FILE" .zip)
TARGET_IMG="${BASE_NAME#gki-certified-}.img"

# Create a temporary directory
TMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TMP_DIR"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Unpack the zip file into the temporary directory
echo "Unpacking zip file..."
unzip -q "$BOOT_ZIP_FILE" -d "$TMP_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to unpack zip file."
    exit 1
fi

BOOT_IMG=$(find "$TMP_DIR" -type f -name "boot*.img")
if [[ -z "$BOOT_IMG" ]]; then
    echo "Error: No boot.img found in the zip."
    exit 1
fi

# Unpack the boot image
echo "Unpacking boot image..."
unpack_bootimg --boot_img "$BOOT_IMG" --out "$TMP_DIR/unpacked"
if [ $? -ne 0 ]; then
    echo "Error: Failed to unpack boot image."
    exit 1
fi

strings "$TMP_DIR/unpacked/kernel" | grep "Linux version"

# Pack the boot image back
echo "Packing boot image..."
mkbootimg \
    --kernel "$TMP_DIR/unpacked/kernel" \
    --ramdisk "$TMP_DIR/unpacked/ramdisk" \
    --header_version 4 \
    --os_version 12.0.0 \
    --os_patch_level 2024-05 \
    --ramdisk_offset 0x01000000 \
    --tags_offset 0x00000100 \
    --cmdline '' \
    --output "$TMP_DIR/repacked.img"

if [ $? -ne 0 ]; then
    echo "Error: Failed to pack boot image."
    exit 1
fi

# Add hash footer using avbtool
echo "Adding AVB hash footer..."
avbtool add_hash_footer \
    --image "$TMP_DIR/repacked.img" \
    --partition_name boot \
    --partition_size 100663296 \
    --prop com.android.build.boot.fingerprint:'Sony/kernelsu_xqct54/pdx223:13/TQ3A.230901.001/root11192255:userdebug/test-keys' \
    --prop com.android.build.boot.os_version:'12' \
    --prop com.android.build.boot.security_patch:'2024-07-01' \
    --hash_algorithm sha256

if [ $? -ne 0 ]; then
    echo "Error: Failed to add AVB hash footer."
    exit 1
fi

# Move the final image to the current directory
mv "$TMP_DIR/repacked.img" "$TARGET_IMG"
if [ $? -eq 0 ]; then
    echo "Boot image created: $TARGET_IMG"
else
    echo "Error: Failed to move the final image."
    exit 1
fi

