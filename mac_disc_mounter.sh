#!/bin/bash

# Script to mount Mac-formatted disk images on Ubuntu
# Handles HFS/HFS+ formats and installs required packages

# Default settings
DISK_IMAGE="shared.img"
MOUNT_POINT="/mnt/mac_shared"
OPERATION="mount" # Default operation: mount the disk
CURRENT_USER=$(whoami)

# Display help information
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -i FILE  Specify disk image file (default: $DISK_IMAGE)"
    echo "  -m DIR   Specify mount point (default: $MOUNT_POINT)"
    echo "  -u       Unmount the disk image"
    echo "  -c       Check disk image filesystem type"
    echo "  -r       Repair disk image filesystem"
    echo "  -h       Show this help message"
    exit 1
}

# Parse command-line arguments
while getopts "i:m:ucrhf" opt; do
    case $opt in
        i) DISK_IMAGE="$OPTARG" ;;
        m) MOUNT_POINT="$OPTARG" ;;
        u) OPERATION="unmount" ;;
        c) OPERATION="check" ;;
        r) OPERATION="repair" ;;
        h|*) show_help ;;
    esac
done

# Function to check if a package is installed
check_package() {
    dpkg -l "$1" &> /dev/null
    return $?
}

# Function to install required packages
install_required_packages() {
    echo "Checking for required packages..."
    
    PACKAGES_TO_INSTALL=""
    
    # Check for hfsprogs
    if ! check_package hfsprogs; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hfsprogs"
    fi
    
    # Check for hfsplus
    if ! check_package hfsplus; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hfsplus"
    fi
    
    # Install packages if needed
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        echo "Installing required packages: $PACKAGES_TO_INSTALL"
        sudo apt-get update
        sudo apt-get install -y $PACKAGES_TO_INSTALL
        
        # Check if installation was successful
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install required packages."
            exit 1
        fi
        echo "Required packages installed successfully."
    else
        echo "All required packages are already installed."
    fi
}

# Function to check if the disk image exists
check_disk_image() {
    if [ ! -f "$DISK_IMAGE" ]; then
        echo "Error: Disk image '$DISK_IMAGE' not found."
        exit 1
    fi
}

# Function to check the filesystem type of the disk image
check_filesystem_type() {
    check_disk_image
    echo "Checking filesystem type of '$DISK_IMAGE'..."
    sudo file -s "$DISK_IMAGE"
}

# Function to repair the disk image
repair_disk_image() {
    check_disk_image
    echo "Attempting to repair '$DISK_IMAGE'..."
    
    # Try HFS+ repair first
    echo "Trying HFS+ repair..."
    sudo fsck.hfsplus -f "$DISK_IMAGE"
    
    # If that fails, try HFS repair
    if [ $? -ne 0 ]; then
        echo "HFS+ repair failed. Trying HFS repair..."
        sudo fsck.hfs -f "$DISK_IMAGE"
    fi
}

# Function to mount the disk image
mount_disk_image() {
    check_disk_image
    install_required_packages
    
    # Create mount point if it doesn't exist
    if [ ! -d "$MOUNT_POINT" ]; then
        echo "Creating mount point: $MOUNT_POINT"
        sudo mkdir -p "$MOUNT_POINT"
    fi
    
    # Check if already mounted
    if mount | grep -q "$MOUNT_POINT"; then
        echo "Error: Something is already mounted at $MOUNT_POINT"
        echo "Please unmount first with: $0 -u"
        exit 1
    fi
    
    echo "Attempting to mount '$DISK_IMAGE' to '$MOUNT_POINT'..."
    
    # Mount options with user permissions
    MOUNT_OPTIONS="loop,rw,uid=$(id -u),gid=$(id -g),umask=000"
    
    # Try HFS+ first
    echo "Trying HFS+ mount with user permissions..."
    sudo mount -t hfsplus -o $MOUNT_OPTIONS "$DISK_IMAGE" "$MOUNT_POINT" 2>/dev/null
    
    # If HFS+ fails, try HFS
    if [ $? -ne 0 ]; then
        echo "HFS+ mount failed. Trying HFS mount..."
        sudo mount -t hfs -o $MOUNT_OPTIONS "$DISK_IMAGE" "$MOUNT_POINT"
        
        # If both fail, show error
        if [ $? -ne 0 ]; then
            echo "Error: Failed to mount disk image."
            echo "The image might be corrupted or using an unsupported filesystem."
            echo "Try repairing with: $0 -r"
            exit 1
        fi
    fi
    
    # Ensure permissions are set correctly
    echo "Setting permissions on mount point..."
    sudo chown -R $CURRENT_USER:$CURRENT_USER "$MOUNT_POINT"
    sudo chmod -R 755 "$MOUNT_POINT"
    
    # Try to make the mount point writable by creating a test file
    echo "Testing write permissions..."
    if touch "$MOUNT_POINT/test_write_permission" 2>/dev/null; then
        echo "Write permissions confirmed."
        rm -f "$MOUNT_POINT/test_write_permission"
    else
        echo "Warning: Could not write to the mount point. Trying to fix permissions..."
        sudo mount -o remount,rw "$MOUNT_POINT"
        sudo chmod -R 777 "$MOUNT_POINT"
    fi
    
    echo "Disk image mounted successfully at $MOUNT_POINT"
    echo "You can now access and copy files to/from this location."
    echo "Remember to unmount when finished with: $0 -u"
    
    # Show disk usage
    echo ""
    echo "Disk usage information:"
    df -h "$MOUNT_POINT"
    
    # List contents
    echo ""
    echo "Directory contents:"
    ls -la "$MOUNT_POINT"
    
    # Open file manager at the mount point (equivalent to 'open .' on macOS)
    echo ""
    echo "Opening file manager at mount point..."
    xdg-open "$MOUNT_POINT" &
}

# Function to unmount the disk image
unmount_disk_image() {
    # Check if mounted
    if ! mount | grep -q "$MOUNT_POINT"; then
        echo "Nothing is mounted at $MOUNT_POINT"
        exit 0
    fi
    
    echo "Unmounting $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
    
    if [ $? -eq 0 ]; then
        echo "Disk image unmounted successfully."
    else
        echo "Error: Failed to unmount disk image."
        echo "Make sure no processes are using files on the mounted filesystem."
        echo "You can force unmount with: sudo umount -f $MOUNT_POINT"
        exit 1
    fi
}

# Main execution
case "$OPERATION" in
    mount)
        mount_disk_image
        ;;
    unmount)
        unmount_disk_image
        ;;
    check)
        check_filesystem_type
        ;;
    repair)
        repair_disk_image
        ;;
esac

exit 0