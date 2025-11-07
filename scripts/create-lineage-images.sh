#!/bin/bash

set -e

# Function to print messages
print_info() {
    echo "$1"
}

print_error() {
    echo "[ERROR] $1"
}

print_warning() {
    echo "[WARNING] $1"
}

# Check if source path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <lineage_source_path> [output_directory]"
    echo "If output_directory is omitted, the current directory is used instead"
    exit 1
fi

LINEAGE_SOURCE="$1"
OUT_DIR="${LINEAGE_SOURCE}/out/target/product"

# Set output directory
if [ -z "$2" ]; then
    OUTPUT_DIR=`pwd`
else
    OUTPUT_DIR="$2"
fi

# Verify source path exists
if [ ! -d "$LINEAGE_SOURCE" ]; then
    print_error "LineageOS source path does not exist: $LINEAGE_SOURCE"
    exit 1
fi

# Verify out directory exists
if [ ! -d "$OUT_DIR" ]; then
    print_error "Output directory does not exist: $OUT_DIR"
    print_error "Have you built LineageOS yet?"
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    print_info "Created output directory: $OUTPUT_DIR"
fi

# Get current date in YYYYMMDD format
DATE=$(date +%Y%m%d)

# Required image files for flashing
REQUIRED_IMAGES=(
    "recovery.img"
    "vbmeta.img"
    "odm.img"
    "product.img"
    "system_ext.img"
    "system.img"
    "vendor.img"
    "vendor_dlkm.img"
    "boot.img"
    "vendor_boot.img"
)

# Function to get date from newest image
get_newest_image_date() {
    local device_dir="$1"
    local newest_timestamp=0
    
    for img in "${REQUIRED_IMAGES[@]}"; do
        if [ -f "$device_dir/$img" ]; then
            local timestamp=$(stat -c %Y "$device_dir/$img" 2>/dev/null || stat -f %m "$device_dir/$img" 2>/dev/null)
            if [ $timestamp -gt $newest_timestamp ]; then
                newest_timestamp=$timestamp
            fi
        fi
    done
    
    if [ $newest_timestamp -eq 0 ]; then
        echo "$DATE"
    else
        date -d @$newest_timestamp +%Y%m%d 2>/dev/null || date -r $newest_timestamp +%Y%m%d 2>/dev/null
    fi
}

# Function to package images for a device
package_device() {
    local device_dir="$1"
    local device_name=$(basename "$device_dir")
    
    print_info "Processing device: $device_name"
    
    # Check if all required images exist
    local missing_images=()
    for img in "${REQUIRED_IMAGES[@]}"; do
        if [ ! -f "$device_dir/$img" ]; then
            missing_images+=("$img")
        fi
    done
    
    # Skip if any images are missing
    if [ ${#missing_images[@]} -gt 0 ]; then
        print_warning "Missing images for $device_name: ${missing_images[*]}"
        print_warning "Skipping device $device_name"
        return 1
    fi
    
    # Get date from newest image
    local image_date=$(get_newest_image_date "$device_dir")
    
    # Create zip filename
    local zip_name="lineage-21.0-${image_date}-SFOSBASE-${device_name}.zip"
    local zip_path="$OUTPUT_DIR/$zip_name"
    
    # Remove old zip files with similar naming pattern
    print_info "Removing old packages for $device_name..."
    rm -f "$OUTPUT_DIR"/lineage-21.0-*-SFOSBASE-${device_name}.zip
    
    # Create temporary directory for packaging
    local temp_dir=$(mktemp -d)
    
    # Copy images to temp directory
    print_info "Copying images..."
    for img in "${REQUIRED_IMAGES[@]}"; do
        cp "$device_dir/$img" "$temp_dir/"
    done
    
    # Create the zip package
    print_info "Creating package: $zip_name"
    cd "$temp_dir"
    zip -q -r "$zip_path" .
    cd - > /dev/null
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    # Verify zip was created
    if [ -f "$zip_path" ]; then
        local zip_size=$(du -h "$zip_path" | cut -f1)
        print_info "Successfully created: $zip_name (${zip_size})"
        return 0
    else
        print_error "Failed to create package for $device_name"
        return 1
    fi
}

# Main execution
print_info "LineageOS Image Packaging Script"
print_info "Source path: $LINEAGE_SOURCE"
print_info "Build directory: $OUT_DIR"
print_info "Output directory: $OUTPUT_DIR"
echo

# Find all device directories
device_count=0
success_count=0

for device_dir in "$OUT_DIR"/*; do
    if [ -d "$device_dir" ]; then
        device_count=$((device_count + 1))
        if package_device "$device_dir"; then
            success_count=$((success_count + 1))
        fi
        echo
    fi
done

# Summary
echo "================================"
print_info "Packaging complete!"
print_info "Devices processed: $device_count"
print_info "Successfully packaged: $success_count"

if [ $success_count -lt $device_count ]; then
    print_warning "Some devices failed to package. Check the output above for details."
    exit 1
fi

exit 0
