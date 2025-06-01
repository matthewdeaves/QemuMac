#!/bin/bash

#######################################
# QEMU Storage Management Module
# Handles creation and preparation of disk images and PRAM
#######################################

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-utils.sh
source "$SCRIPT_DIR/qemu-utils.sh"

#######################################
# Prepare PRAM image with proper error handling
# Arguments:
#   None
# Globals:
#   QEMU_PRAM
# Returns:
#   None
# Exits:
#   1 if PRAM creation fails
#######################################
prepare_pram() {
    if [ ! -s "$QEMU_PRAM" ]; then
        local pram_dir
        pram_dir=$(dirname "$QEMU_PRAM")
        
        ensure_directory "$pram_dir" "PRAM directory"
        
        echo "Creating new PRAM image file: $QEMU_PRAM"
        dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1 status=none
        check_exit_status $? "Failed to create PRAM image '$QEMU_PRAM'"
        
        info_log "PRAM image created successfully"
    else
        debug_log "PRAM image already exists: $QEMU_PRAM"
    fi
}

#######################################
# Prepare OS hard disk image with proper error handling
# Arguments:
#   None
# Globals:
#   QEMU_HDD, QEMU_HDD_SIZE
# Returns:
#   None
# Exits:
#   1 if HDD creation fails
#######################################
prepare_hdd() {
    if [ ! -f "$QEMU_HDD" ]; then
        local hdd_dir
        hdd_dir=$(dirname "$QEMU_HDD")
        
        ensure_directory "$hdd_dir" "OS HDD directory"
        
        local os_disk_size="${QEMU_HDD_SIZE}"
        echo "OS hard disk image '$QEMU_HDD' not found. Creating ($os_disk_size)..."
        qemu-img create -f raw "$QEMU_HDD" "$os_disk_size" > /dev/null
        check_exit_status $? "Failed to create OS hard disk image '$QEMU_HDD'"
        
        echo "Empty OS hard disk image created. Proceeding with boot (likely from CD for install)."
    else
        echo "OS hard disk image '$QEMU_HDD' found."
    fi
}

#######################################
# Prepare shared hard disk image with proper error handling
# Arguments:
#   None
# Globals:
#   QEMU_SHARED_HDD, QEMU_SHARED_HDD_SIZE
# Returns:
#   None
# Exits:
#   1 if shared HDD creation fails
#######################################
prepare_shared_hdd() {
    if [ ! -f "$QEMU_SHARED_HDD" ]; then
        local shared_hdd_dir
        shared_hdd_dir=$(dirname "$QEMU_SHARED_HDD")
        
        ensure_directory "$shared_hdd_dir" "Shared HDD directory"
        
        echo "Shared disk image '$QEMU_SHARED_HDD' not found. Creating ($QEMU_SHARED_HDD_SIZE)..."
        qemu-img create -f raw "$QEMU_SHARED_HDD" "$QEMU_SHARED_HDD_SIZE" > /dev/null
        check_exit_status $? "Failed to create shared disk image '$QEMU_SHARED_HDD'"
        
        echo "Empty shared disk image created. Format it within the emulator."
        echo "To share files with the VM (Linux example):"
        echo "  1. sudo mount -o loop \"$QEMU_SHARED_HDD\" /mnt"
        echo "  2. Copy files"
        echo "  3. sudo umount /mnt"
    else
        debug_log "Shared disk image already exists: $QEMU_SHARED_HDD"
    fi
}

#######################################
# Prepare all necessary disk images from configuration
# Arguments:
#   None
# Globals:
#   Various QEMU_* variables
# Returns:
#   None
# Exits:
#   1 if any disk preparation fails
#######################################
prepare_config_disk_images() {
    debug_log "Preparing disk images..."
    prepare_pram
    prepare_hdd
    prepare_shared_hdd
    info_log "All disk images prepared successfully"
}

#######################################
# Set the boot device SCSI ID in the PRAM file
# The PRAM (Parameter RAM) stores boot preferences.
# Writing specific values at offset 122 (0x7A) controls
# which SCSI device the Mac will attempt to boot from.
# Arguments:
#   device_type: "hdd" for hard disk (SCSI ID 0) or "cdrom" for CD-ROM (SCSI ID 2)
# Globals:
#   QEMU_PRAM, DEBUG_MODE
# Returns:
#   None
# Exits:
#   1 if PRAM file not found or write fails
#######################################
set_pram_boot_order() {
    local device_type="$1"
    local pram_file="$QEMU_PRAM"
    local offset=122 # 0x7A in decimal
    
    # Validate arguments
    if [ -z "$device_type" ]; then
        echo "Error: Device type is required for PRAM boot order setting" >&2
        exit 1
    fi
    
    # Ensure PRAM file exists (should have been created by prepare_pram)
    validate_file_exists "$pram_file" "PRAM file" || exit 1
    
    local byte1 byte2
    case "$device_type" in
        "hdd")
            # Boot from SCSI ID 0: Value 0xFFDF -> Bytes FF DF
            byte1='\xff'
            byte2='\xdf'
            info_log "Setting PRAM to boot from HDD (SCSI ID 0)"
            ;;
        "cdrom")
            # Boot from SCSI ID 2: Value 0xFFDD -> Bytes FF DD
            byte1='\xff'
            byte2='\xdd'
            info_log "Setting PRAM to boot from CD-ROM (SCSI ID 2)"
            ;;
        *)
            echo "Error: Invalid device type '$device_type' for PRAM boot order" >&2
            echo "Valid types: hdd, cdrom" >&2
            exit 1
            ;;
    esac
    
    # Write the 2 bytes (16 bits) at the specified offset (0x7A = 122)
    # Using printf for byte representation and dd for precise writing
    # conv=notrunc prevents truncating the file
    # status=none suppresses dd output
    printf "%b%b" "$byte1" "$byte2" | dd of="$pram_file" bs=1 seek="$offset" count=2 conv=notrunc status=none
    check_exit_status $? "Failed to write boot order to PRAM file '$pram_file'"
    
    if [ "${DEBUG_MODE:-false}" = true ]; then
        echo "DEBUG: PRAM bytes at offset 122 after writing:"
        hexdump -C -s 122 -n 2 "$pram_file"
    fi
}

#######################################
# Validate additional hard drive file if specified
# Arguments:
#   additional_hdd_file: Path to additional HDD file (can be empty)
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if additional HDD file specified but not found
#######################################
validate_additional_hdd() {
    local additional_hdd_file="$1"
    
    if [ -n "$additional_hdd_file" ]; then
        validate_file_exists "$additional_hdd_file" "Additional hard drive file" || exit 1
        info_log "Additional HDD validated: $additional_hdd_file"
    fi
}