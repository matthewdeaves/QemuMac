#!/usr/bin/env bash
#
# QemuMac Shared Disk Mounter - Simple script to mount the shared disk
#

set -euo pipefail

# Load common library
source "$(dirname "$0")/lib/common.sh"

# Configuration
SHARED_DIR="shared"
SHARED_DISK="$SHARED_DIR/shared-disk.img"

# The directory on the host system where the shared disk will be mounted.
# This can be changed to any path you prefer (e.g., "~/qemu-shared").
MOUNT_POINT="$SHARED_MOUNT_POINT"
OPERATION="mount"

# Parse arguments
[[ "${1:-}" == "-u" ]] && OPERATION="unmount"
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && {
    echo "Usage: $0 [-u]"
    echo "  -u    Unmount the shared disk"
    echo ""
    echo "Mounts the shared disk used by all QemuMac VMs at: $MOUNT_POINT"
    exit 0
}

# Mount the shared disk
mount_shared() {
    require_file "$SHARED_DISK" "Shared disk not found. Run a VM first to create it."
    
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        error "Shared disk already mounted at: $MOUNT_POINT"
        die "To unmount, run: ${C_BLUE}./mount-shared.sh -u${C_RESET}"
    fi
    
    ensure_directory "$MOUNT_POINT"
    
    info "Mounting shared disk: $SHARED_DISK"
    local uid=$(id -u)
    local gid=$(id -g)
    if sudo mount -t hfsplus -o loop,rw,uid=$uid,gid=$gid "$SHARED_DISK" "$MOUNT_POINT" 2>/dev/null; then
        info "Mounted as HFS+ (read-write)"
    elif sudo mount -t hfs -o loop,rw,uid=$uid,gid=$gid "$SHARED_DISK" "$MOUNT_POINT" 2>/dev/null; then
        info "Mounted as HFS (read-write)"
    else
        die "Failed to mount shared disk. Install HFS support: sudo apt install hfsprogs"
    fi
    
    success "Shared disk mounted at: $MOUNT_POINT"
    info "This disk is accessible from all your Mac VMs"
}

# Unmount the shared disk
unmount_shared() {
    if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        info "Shared disk not currently mounted"
        exit 0
    fi
    
    info "Unmounting shared disk"
    sudo umount "$MOUNT_POINT" || die "Failed to unmount shared disk"
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    
    success "Shared disk unmounted"
}

# Main execution
case "$OPERATION" in
    mount) mount_shared ;;
    unmount) unmount_shared ;;
esac
