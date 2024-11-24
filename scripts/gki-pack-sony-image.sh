#!/bin/bash

# This script will create boot image that is packed in a way which is expected for nagara

# DO NOT USE THIS SCRIPT WITHOUT ADJUSTING PARAMETERS
# - set the PATH to point towards Android sources
# - check fingerprint below
# - it is expected that kernel is in boot/Image; ramdisk in boot/ramdisk

PATH=android-14_r67/out/host/linux-x86/bin:$PATH

TARGET_IMG=boot-for-sony.img

TMP_DIR=boot

strings "$TMP_DIR/Image" | grep "Linux version"

# Pack the boot image back
echo "Packing boot image..."
mkbootimg \
    --kernel "$TMP_DIR/Image" \
    --ramdisk "$TMP_DIR/ramdisk" \
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

