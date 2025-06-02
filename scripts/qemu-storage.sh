#!/usr/bin/env bash

#######################################
# QEMU Storage Management Module
# Handles creation and preparation of disk images and PRAM
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

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
# Set the boot device SCSI ID in the PRAM file using Laurent Vivier's algorithm
# The PRAM (Parameter RAM) stores boot preferences.
# Based on Laurent's analysis: Boot order stored as 16-bit RefNum at offset 0x7A (122)
# Format: (byte) DriveId{for slots} | (byte) PartitionId | (word) RefNum
# SCSI ID calculation: ~RefNum - 32
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
    local offset_78=120  # 0x78 in decimal - DriveId/PartitionId location
    local offset_7a=122  # 0x7A in decimal - RefNum location (main boot order)
    
    # Validate arguments
    if [ -z "$device_type" ]; then
        echo "Error: Device type is required for PRAM boot order setting" >&2
        exit 1
    fi
    
    # Ensure PRAM file exists (should have been created by prepare_pram)
    validate_file_exists "$pram_file" "PRAM file" || exit 1
    
    local scsi_id refnum_value byte1 byte2 drive_partition_byte
    case "$device_type" in
        "hdd")
            scsi_id=0
            # Calculate RefNum using Laurent's formula: ~(scsi_id + 32)
            refnum_value=$((~(scsi_id + 32) & 0xFFFF))
            drive_partition_byte='\xff'  # DriveId/PartitionId for HDD
            info_log "Setting PRAM to boot from HDD (SCSI ID $scsi_id, RefNum: 0x$(printf '%04x' $refnum_value))"
            ;;
        "cdrom")
            scsi_id=2
            # Calculate RefNum using Laurent's formula: ~(scsi_id + 32)
            refnum_value=$((~(scsi_id + 32) & 0xFFFF))
            drive_partition_byte='\xff'  # DriveId/PartitionId for CD-ROM
            info_log "Setting PRAM to boot from CD-ROM (SCSI ID $scsi_id, RefNum: 0x$(printf '%04x' $refnum_value))"
            ;;
        *)
            echo "Error: Invalid device type '$device_type' for PRAM boot order" >&2
            echo "Valid types: hdd, cdrom" >&2
            exit 1
            ;;
    esac
    
    # Convert RefNum to bytes (little-endian format)
    byte1=$(printf '\\x%02x' $((refnum_value & 0xFF)))
    byte2=$(printf '\\x%02x' $(((refnum_value >> 8) & 0xFF)))
    
    # Debug output showing calculations
    debug_log "PRAM Boot Order Calculation:"
    debug_log "  SCSI ID: $scsi_id"
    debug_log "  RefNum calculation: ~($scsi_id + 32) = $refnum_value (0x$(printf '%04x' $refnum_value))"
    debug_log "  Byte1 (LSB): 0x$(printf '%02x' $((refnum_value & 0xFF)))"
    debug_log "  Byte2 (MSB): 0x$(printf '%02x' $(((refnum_value >> 8) & 0xFF)))"
    
    # Write DriveId/PartitionId byte at offset 0x78 (may not be critical but following Laurent's observation)
    printf "%b" "$drive_partition_byte" | dd of="$pram_file" bs=1 seek="$offset_78" count=1 conv=notrunc status=none 2>/dev/null
    
    # Write the RefNum (16-bit value) at offset 0x7A in little-endian format
    printf "%b%b" "$byte1" "$byte2" | dd of="$pram_file" bs=1 seek="$offset_7a" count=2 conv=notrunc status=none
    check_exit_status $? "Failed to write boot order to PRAM file '$pram_file'"
    
    # Enhanced debug output
    if [ "${DEBUG_MODE:-false}" = true ] || [ "${BOOT_DEBUG:-false}" = true ]; then
        echo "PRAM Boot Order Debug Information:"
        echo "  Target Device: $device_type (SCSI ID $scsi_id)"
        echo "  RefNum Value: 0x$(printf '%04x' $refnum_value)"
        echo "  PRAM bytes at offset 0x78 (DriveId/PartitionId):"
        hexdump -C -s 120 -n 1 "$pram_file" | sed 's/^/    /'
        echo "  PRAM bytes at offset 0x7A (RefNum - boot order):"
        hexdump -C -s 122 -n 2 "$pram_file" | sed 's/^/    /'
        echo "  Verification - SCSI ID from RefNum: $((~refnum_value - 32))"
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