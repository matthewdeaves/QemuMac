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
HOST_OS=""

# Detect OS once
HOST_OS=$(detect_os)

# Parse arguments
[[ "${1:-}" == "-u" || "${1:-}" == "--unmount" ]] && OPERATION="unmount"
[[ "${1:-}" == "-l" || "${1:-}" == "--list" ]] && OPERATION="list"
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && {
    echo "Usage: $0 [-u|-l|-h]"
    echo "  -u, --unmount  Unmount/release the shared disk"
    echo "  -l, --list     List files on the shared disk"
    echo "  -h, --help     Show this help message"
    echo ""
    if [[ "$HOST_OS" == "macos" ]]; then
        echo "On macOS, uses hfsutils (hmount/humount) to access the HFS disk."
        echo "Files are accessed via hfsutils commands, not a mount point."
        echo ""
        echo "After mounting, use hfsutils commands to interact with the disk:"
        echo "  hls              - List files"
        echo "  hcopy file :     - Copy file to disk"
        echo "  hcopy :file .    - Copy file from disk"
        echo "  humount          - Release the disk"
    else
        echo "Mounts the shared disk used by all QemuMac VMs at: $MOUNT_POINT"
    fi
    exit 0
}

# ============================================================================
# Linux mount/unmount functions (uses loop mount)
# ============================================================================

mount_shared_linux() {
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

unmount_shared_linux() {
    if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        info "Shared disk not currently mounted"
        exit 0
    fi

    info "Unmounting shared disk"
    sudo umount "$MOUNT_POINT" || die "Failed to unmount shared disk"
    rmdir "$MOUNT_POINT" 2>/dev/null || true

    success "Shared disk unmounted"
}

list_shared_linux() {
    if ! mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        die "Shared disk not mounted. Run ./mount-shared.sh first."
    fi

    ls -la "$MOUNT_POINT"
}

# ============================================================================
# macOS mount/unmount functions (uses hfsutils)
# ============================================================================

mount_shared_macos() {
    require_file "$SHARED_DISK" "Shared disk not found. Run a VM first to create it."
    require_commands hmount

    # Check if already mounted by trying hls
    if hls 2>/dev/null | grep -q .; then
        error "An HFS volume is already mounted via hfsutils"
        die "To release it, run: ${C_BLUE}./mount-shared.sh -u${C_RESET}"
    fi

    info "Mounting shared disk with hfsutils: $SHARED_DISK"
    if hmount "$SHARED_DISK" >/dev/null 2>&1; then
        success "Shared disk mounted via hfsutils"
        echo ""
        info "Use hfsutils commands to access files:"
        echo "  ${C_BLUE}hls${C_RESET}              - List files on the disk"
        echo "  ${C_BLUE}hcopy file :${C_RESET}     - Copy file TO the disk"
        echo "  ${C_BLUE}hcopy :file .${C_RESET}    - Copy file FROM the disk"
        echo "  ${C_BLUE}humount${C_RESET}          - Release the disk when done"
    else
        die "Failed to mount shared disk. Install hfsutils: brew install hfsutils"
    fi
}

unmount_shared_macos() {
    require_commands humount

    # Check if mounted
    if ! hls 2>/dev/null | grep -q . 2>/dev/null; then
        info "No HFS volume currently mounted via hfsutils"
        exit 0
    fi

    info "Releasing shared disk"
    humount || die "Failed to release shared disk"

    success "Shared disk released"
}

list_shared_macos() {
    require_commands hls

    if ! hls 2>/dev/null | grep -q . 2>/dev/null; then
        die "No HFS volume mounted. Run ./mount-shared.sh first."
    fi

    hls -la
}

# ============================================================================
# Main mount/unmount dispatcher
# ============================================================================

mount_shared() {
    case "$HOST_OS" in
        macos) mount_shared_macos ;;
        ubuntu) mount_shared_linux ;;
        *) die "Unsupported OS: $HOST_OS" ;;
    esac
}

unmount_shared() {
    case "$HOST_OS" in
        macos) unmount_shared_macos ;;
        ubuntu) unmount_shared_linux ;;
        *) die "Unsupported OS: $HOST_OS" ;;
    esac
}

list_shared() {
    case "$HOST_OS" in
        macos) list_shared_macos ;;
        ubuntu) list_shared_linux ;;
        *) die "Unsupported OS: $HOST_OS" ;;
    esac
}

# Main execution
case "$OPERATION" in
    mount) mount_shared ;;
    unmount) unmount_shared ;;
    list) list_shared ;;
esac
