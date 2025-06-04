#!/usr/bin/env bash

#######################################
# Mac Disc Mounter Script
# Mounts Mac-formatted disk images on Linux based on QEMU config
# Handles HFS/HFS+ formats and installs required packages automatically
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

# --- Script Variables ---
CONFIG_FILE=""
DISK_IMAGE=""
MOUNT_POINT="$DEFAULT_MOUNT_POINT"
OPERATION="mount"
CURRENT_USER=$(whoami)

#######################################
# Display help information
# Arguments:
#   None
# Globals:
#   DEFAULT_MOUNT_POINT
# Returns:
#   None
# Exits:
#   1 (help display always exits)
#######################################
show_help() {
    echo "Usage: $0 -C <qemu_config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify QEMU configuration file (e.g., sys753-q800.conf)"
    echo "           The script will use the QEMU_SHARED_HDD path from this file."
    echo "Options:"
    echo "  -m DIR   Specify mount point (default: $DEFAULT_MOUNT_POINT)"
    echo "  -u       Unmount the disk image"
    echo "  -c       Check disk image filesystem type"
    echo "  -r       Repair disk image filesystem"
    echo "  -h       Show this help message"
    exit 1
}

#######################################
# Parse command-line arguments
# Arguments:
#   All command line arguments
# Globals:
#   CONFIG_FILE, MOUNT_POINT, OPERATION
# Returns:
#   None
# Exits:
#   1 if invalid arguments provided
#######################################
parse_arguments() {
    while getopts "C:m:ucrh" opt; do
        case $opt in
            C) CONFIG_FILE="$OPTARG" ;;
            m) MOUNT_POINT="$OPTARG" ;;
            u) OPERATION="unmount" ;;
            c) OPERATION="check" ;;
            r) OPERATION="repair" ;;
            h|*) show_help ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No configuration file specified. Use -C <qemu_config_file.conf>" >&2
        show_help
    fi
    
    # Validate config filename format
    validate_config_filename "$(basename "$CONFIG_FILE")" || exit 1
}

#######################################
# Load configuration and set disk image path
# Arguments:
#   None
# Globals:
#   CONFIG_FILE, DISK_IMAGE, QEMU_SHARED_HDD
# Returns:
#   None
# Exits:
#   1 if config file not found or missing required variables
#######################################
load_disk_config() {
    validate_file_exists "$CONFIG_FILE" "Configuration file" || exit 1
    
    echo "Loading configuration from: $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    check_exit_status $? "Failed to source configuration file '$CONFIG_FILE'"
    
    # Check if the essential variable QEMU_SHARED_HDD was loaded from the config
    if [ -z "${QEMU_SHARED_HDD:-}" ]; then
        echo "Error: Config file $CONFIG_FILE is missing the required QEMU_SHARED_HDD variable." >&2
        exit 1
    fi
    
    # Set the disk image path from the loaded config variable
    DISK_IMAGE="$QEMU_SHARED_HDD"
    echo "Using shared disk image from config: $DISK_IMAGE"
}

#######################################
# Check if the disk image exists and is accessible
# Arguments:
#   None
# Globals:
#   DISK_IMAGE, CONFIG_FILE
# Returns:
#   None
# Exits:
#   1 if disk image not found or not accessible
#######################################
check_disk_image() {
    if [ ! -f "$DISK_IMAGE" ]; then
        echo "Error: Disk image '$DISK_IMAGE' (from config file '$CONFIG_FILE') not found." >&2
        exit 1
    fi
    
    if [ ! -r "$DISK_IMAGE" ]; then
        echo "Error: Disk image '$DISK_IMAGE' is not readable. Check permissions." >&2
        exit 1
    fi
}

#######################################
# Check the filesystem type of the disk image
# Arguments:
#   None
# Globals:
#   DISK_IMAGE
# Returns:
#   None
# Exits:
#   1 if disk image check fails
#######################################
check_filesystem_type() {
    check_disk_image
    echo "Checking filesystem type of '$DISK_IMAGE'..."
    
    local file_output
    file_output=$(sudo file -s "$DISK_IMAGE" 2>/dev/null)
    check_exit_status $? "Failed to check filesystem type of '$DISK_IMAGE'"
    
    echo "$file_output"
    
    # Provide helpful interpretation
    if echo "$file_output" | grep -q "Macintosh HFS"; then
        info_log "Detected Macintosh HFS filesystem"
    elif echo "$file_output" | grep -q "Apple HFS"; then
        info_log "Detected Apple HFS+ filesystem"
    else
        warning_log "Filesystem type may not be supported for mounting"
    fi
}

#######################################
# Repair the disk image filesystem
# Arguments:
#   None
# Globals:
#   DISK_IMAGE
# Returns:
#   None
# Exits:
#   1 if repair operations fail
#######################################
repair_disk_image() {
    check_disk_image
    echo "Attempting to repair '$DISK_IMAGE'..."
    
    # Install required packages for repair
    install_packages "hfsprogs" "hfsplus"
    
    # Try HFS+ repair first
    echo "Trying HFS+ repair..."
    if sudo fsck.hfsplus -f "$DISK_IMAGE" 2>/dev/null; then
        info_log "HFS+ repair completed successfully"
        return 0
    fi
    
    # If that fails, try HFS repair
    echo "HFS+ repair failed. Trying HFS repair..."
    if sudo fsck.hfs -f "$DISK_IMAGE" 2>/dev/null; then
        info_log "HFS repair completed successfully"
        return 0
    fi
    
    echo "Error: Both HFS+ and HFS repair attempts failed" >&2
    echo "The disk image may be severely corrupted or use an unsupported format" >&2
    exit 1
}

#######################################
# Test write permissions on mount point
# Arguments:
#   mount_point: Path to mount point to test
# Globals:
#   CURRENT_USER
# Returns:
#   0 if write test succeeds, 1 if it fails
#######################################
test_write_permissions() {
    local mount_point="$1"
    local test_file="$mount_point/test_write_permission"
    
    echo "Testing write permissions..."
    if touch "$test_file" 2>/dev/null; then
        echo "Write permissions confirmed."
        rm -f "$test_file" 2>/dev/null || true
        return 0
    else
        warning_log "Could not write to the mount point. Trying to fix permissions..."
        sudo mount -o remount,rw "$mount_point" 2>/dev/null || true
        sudo chmod -R 777 "$mount_point" 2>/dev/null || true
        return 1
    fi
}

#######################################
# Mount the disk image with proper error handling
# Arguments:
#   None
# Globals:
#   DISK_IMAGE, MOUNT_POINT, CURRENT_USER
# Returns:
#   None
# Exits:
#   1 if mount operation fails
#######################################
mount_disk_image() {
    check_disk_image
    install_packages "hfsprogs" "hfsplus"
    
    # Create mount point if it doesn't exist
    ensure_directory "$MOUNT_POINT" "mount point"
    
    # Check if already mounted
    if mount | grep -q "$MOUNT_POINT"; then
        echo "Error: Something is already mounted at $MOUNT_POINT" >&2
        echo "Please unmount first using the -u option with the same -C config file." >&2
        exit 1
    fi
    
    echo "Attempting to mount '$DISK_IMAGE' to '$MOUNT_POINT'..."
    
    # Mount options with user permissions
    local mount_options="loop,rw,uid=$(id -u),gid=$(id -g),umask=000"
    local mount_successful=false
    
    # Try HFS+ first
    echo "Trying HFS+ mount with user permissions..."
    if sudo mount -t hfsplus -o "$mount_options" "$DISK_IMAGE" "$MOUNT_POINT" 2>/dev/null; then
        mount_successful=true
        info_log "Successfully mounted as HFS+"
    else
        # If HFS+ fails, try HFS
        echo "HFS+ mount failed. Trying HFS mount..."
        if sudo mount -t hfs -o "$mount_options" "$DISK_IMAGE" "$MOUNT_POINT" 2>/dev/null; then
            mount_successful=true
            info_log "Successfully mounted as HFS"
        fi
    fi
    
    # Check if mount was successful
    if [ "$mount_successful" != true ]; then
        echo "Error: Failed to mount disk image." >&2
        echo "The image might be corrupted or using an unsupported filesystem." >&2
        echo "Try repairing with: $0 -C \"$CONFIG_FILE\" -r" >&2
        exit 1
    fi
    
    # Ensure permissions are set correctly
    echo "Setting permissions on mount point..."
    sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_POINT" 2>/dev/null || true
    sudo chmod -R 755 "$MOUNT_POINT" 2>/dev/null || true
    
    # Test write permissions
    test_write_permissions "$MOUNT_POINT"
    
    echo "Disk image mounted successfully at $MOUNT_POINT"
    echo "You can now access and copy files to/from this location."
    echo "Remember to unmount when finished with: $0 -C \"$CONFIG_FILE\" -u"
    
    # Show disk usage
    echo ""
    echo "Disk usage information:"
    df -h "$MOUNT_POINT" 2>/dev/null || echo "Could not retrieve disk usage information"
    
    # List contents
    echo ""
    echo "Directory contents:"
    ls -la "$MOUNT_POINT" 2>/dev/null || echo "Could not list directory contents"
    
    # Open file manager at the mount point if available
    if command -v xdg-open &> /dev/null; then
        echo ""
        echo "Opening file manager at mount point..."
        xdg-open "$MOUNT_POINT" &
    fi
}

#######################################
# Unmount the disk image with proper error handling
# Arguments:
#   None
# Globals:
#   MOUNT_POINT
# Returns:
#   None
# Exits:
#   1 if unmount operation fails
#######################################
unmount_disk_image() {
    # Check if mounted
    if ! mount | grep -q "$MOUNT_POINT"; then
        echo "Nothing is mounted at $MOUNT_POINT"
        exit 0
    fi
    
    echo "Unmounting $MOUNT_POINT..."
    
    # Try graceful unmount first
    if sudo umount "$MOUNT_POINT" 2>/dev/null; then
        echo "Disk image unmounted successfully."
        return 0
    fi
    
    # If graceful unmount fails, provide helpful error message
    echo "Error: Failed to unmount disk image." >&2
    echo "Make sure no processes are using files on the mounted filesystem." >&2
    
    # Try to identify what's using the mount point
    if command -v lsof &> /dev/null; then
        echo "Processes using the mount point:" >&2
        sudo lsof +f -- "$MOUNT_POINT" 2>/dev/null || echo "No processes found using lsof" >&2
    fi
    
    echo "You can force unmount with: sudo umount -f $MOUNT_POINT" >&2
    exit 1
}

# --- Main Execution ---

# Parse command line arguments
parse_arguments "$@"

# Load configuration
load_disk_config

# Execute the requested operation
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
    *)
        echo "Error: Unknown operation: $OPERATION" >&2
        exit 1
        ;;
esac

exit 0