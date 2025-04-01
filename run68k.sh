#!/bin/bash

# Script to run Mac System 7.5.5 on Quadra 800 emulation

# Default file paths - adjust these to match your actual file locations
ROM_FILE="800.ROM"
PRAM_FILE="pram.img"
HDD_FILE="hdd1.img"
SHARED_HDD_FILE="shared.img"  # New shared disk image for file transfer
CD_FILE=""  # Empty by default
HDD_SIZE="1G"  # Size for new hard disk image if needed
SHARED_HDD_SIZE="200M"  # Size for shared disk (200MB)

# Display help information
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r FILE  Specify ROM file (default: $ROM_FILE)"
    echo "  -p FILE  Specify PRAM file (default: $PRAM_FILE)"
    echo "  -h FILE  Specify hard disk image file (default: $HDD_FILE)"
    echo "  -f FILE  Specify shared disk image file (default: $SHARED_HDD_FILE)"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -s SIZE  Specify size for new hard disk image (default: $HDD_SIZE)"
    echo "  -S SIZE  Specify size for new shared disk image (default: $SHARED_HDD_SIZE)"
    echo "  -b       Boot from CD-ROM (requires -c option)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -?       Show this help message"
    exit 1
}

# Default boot order - boot from hard disk
BOOT_FROM_CD=false

# Parse command-line arguments
while getopts "r:p:h:f:c:s:S:bd:?" opt; do
    case $opt in
        r) ROM_FILE="$OPTARG" ;;
        p) PRAM_FILE="$OPTARG" ;;
        h) HDD_FILE="$OPTARG" ;;
        f) SHARED_HDD_FILE="$OPTARG" ;;
        c) CD_FILE="$OPTARG" ;;
        s) HDD_SIZE="$OPTARG" ;;
        S) SHARED_HDD_SIZE="$OPTARG" ;;
        b) BOOT_FROM_CD=true ;;
        d) DISPLAY_TYPE="$OPTARG" ;;
        \?|*) show_help ;;
    esac
done

# Create PRAM image if it doesn't exist or is empty
if [ ! -s "$PRAM_FILE" ]; then
    echo "Creating new PRAM image file..."
    dd if=/dev/zero of="$PRAM_FILE" bs=1k count=8
fi

# Create hard disk image if it doesn't exist
if [ ! -f "$HDD_FILE" ]; then
    echo "Hard disk image $HDD_FILE not found. Creating a new empty disk image ($HDD_SIZE)..."
    qemu-img create -f raw "$HDD_FILE" "$HDD_SIZE"
    echo "Empty disk image created. You'll need to format it from within the emulator."
fi

# Create shared disk image if it doesn't exist
if [ ! -f "$SHARED_HDD_FILE" ]; then
    echo "Shared disk image $SHARED_HDD_FILE not found. Creating a new empty disk image ($SHARED_HDD_SIZE)..."
    qemu-img create -f raw "$SHARED_HDD_FILE" "$SHARED_HDD_SIZE"
    echo "Empty shared disk image created. You'll need to format it from within the emulator."
    echo "To share files with the VM:"
    echo "  1. On Linux: Use 'sudo mount -o loop $SHARED_HDD_FILE /mnt/point' to mount the image"
    echo "  2. Copy files to the mounted image"
    echo "  3. Unmount with 'sudo umount /mnt/point'"
    echo "  4. Start the VM and access the files from the second hard drive"
fi

# Set display type based on host system if not specified
if [ -z "$DISPLAY_TYPE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        DISPLAY_TYPE="cocoa"
    else
        # Try SDL instead of GTK for potentially better mouse handling
        DISPLAY_TYPE="sdl"
    fi
fi

echo "Starting Macintosh Quadra 800 emulation..."
echo "ROM: $ROM_FILE"
echo "HDD: $HDD_FILE"
echo "Shared HDD: $SHARED_HDD_FILE"

# Prepare the base command
QEMU_CMD="qemu-system-m68k \
    -M q800 \
    -m 256 \
    -bios \"$ROM_FILE\" \
    -display \"$DISPLAY_TYPE\" \
    -g 1152x870x8 \
    -drive file=\"$PRAM_FILE\",format=raw,if=mtd"

# Add hard disks and CD-ROM with appropriate boot order
if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
    echo "Boot order: CD-ROM first"
    # Add CD-ROM as first SCSI device (ID 0) for booting
    QEMU_CMD="$QEMU_CMD \
    -device scsi-cd,scsi-id=0,drive=cd0 \
    -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0 \
    -device scsi-hd,scsi-id=1,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$HDD_FILE\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=2,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$SHARED_HDD_FILE\",media=disk,format=raw,if=none,id=hd1"
else
    # Normal order - hard disk first, CD-ROM as ID 3
    QEMU_CMD="$QEMU_CMD \
    -device scsi-hd,scsi-id=0,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$HDD_FILE\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=1,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$SHARED_HDD_FILE\",media=disk,format=raw,if=none,id=hd1"
    
    # Add CD-ROM if specified
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE (as SCSI ID 3)"
        QEMU_CMD="$QEMU_CMD \
        -device scsi-cd,scsi-id=3,drive=cd0 \
        -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0"
    else
        echo "No CD-ROM specified"
    fi
fi

echo "Display: $DISPLAY_TYPE"

# Run QEMU with the specified parameters
eval $QEMU_CMD

exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "QEMU exited with error code: $exit_code"
    if [ "$DISPLAY_TYPE" = "sdl" ]; then
        echo "SDL display failed. Trying with GTK..."
        DISPLAY_TYPE="gtk"
        
        # Update the command with new display type
        QEMU_CMD=$(echo "$QEMU_CMD" | sed "s/-display \"sdl\"/-display \"gtk\"/")
        
        # Run with GTK display
        eval $QEMU_CMD
        
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "GTK display also failed. Check for error messages above."
            echo "Try running: sudo apt install qemu-system-m68k"
        fi
    else
        echo "Try running: sudo apt install qemu-system-m68k"
        echo "If already installed, check for error messages above."
    fi
else
    echo "QEMU session ended normally."
fi