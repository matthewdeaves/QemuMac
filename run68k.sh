#!/bin/bash

# Script to run Mac OS emulation using QEMU with configuration files

# --- Configuration variables (will be loaded from .conf file) ---
CONFIG_NAME=""
QEMU_MACHINE=""
QEMU_RAM=""
QEMU_ROM=""
QEMU_HDD=""
QEMU_SHARED_HDD=""        # Path to the shared disk image for this config
QEMU_SHARED_HDD_SIZE=""   # Optional: Size for shared disk if created (e.g., "200M")
QEMU_GRAPHICS=""
QEMU_CPU=""               # Optional CPU override
QEMU_HDD_SIZE="1G"        # Default size for OS HDD if created
QEMU_PRAM=""              # Path to the PRAM image file (now from config)

# --- Script variables ---
CONFIG_FILE=""
CD_FILE=""                # Path to CD/ISO image
BOOT_FROM_CD=false
DISPLAY_TYPE=""           # Auto-detect later if not specified

# Display help information
show_help() {
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify configuration file (e.g., sys755-q800.conf)"
    echo "           The config file defines the machine, RAM, ROM, OS HDD, Shared HDD, and PRAM file."
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -b       Boot from CD-ROM (requires -c option)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -?       Show this help message"
    exit 1
}

# Parse command-line arguments
# Removed -p option as PRAM is now defined in the config file
while getopts "C:c:bd:?" opt; do
    case $opt in
        C) CONFIG_FILE="$OPTARG" ;;
        c) CD_FILE="$OPTARG" ;;
        b) BOOT_FROM_CD=true ;;
        d) DISPLAY_TYPE="$OPTARG" ;;
        \?|*) show_help ;;
    esac
done

# --- Validation and Configuration Loading ---

# Check if a configuration file was specified
if [ -z "$CONFIG_FILE" ]; then
    echo "Error: No configuration file specified. Use -C <config_file.conf>"
    show_help
fi

# Check if the configuration file exists and load it
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from: $CONFIG_FILE"
    # Source the config file - variables defined here might override defaults above
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check if essential variables were loaded from config
# Added QEMU_PRAM to the required list
if [ -z "$QEMU_MACHINE" ] || [ -z "$QEMU_ROM" ] || [ -z "$QEMU_HDD" ] || [ -z "$QEMU_SHARED_HDD" ] || [ -z "$QEMU_RAM" ] || [ -z "$QEMU_GRAPHICS" ] || [ -z "$QEMU_PRAM" ]; then
     echo "Error: Config file $CONFIG_FILE is missing one or more required variables:"
     echo "Required: QEMU_MACHINE, QEMU_ROM, QEMU_HDD, QEMU_SHARED_HDD, QEMU_RAM, QEMU_GRAPHICS, QEMU_PRAM"
     exit 1
fi

# Set default shared HDD size if not specified in config
DEFAULT_SHARED_HDD_SIZE="200M"
if [ -z "$QEMU_SHARED_HDD_SIZE" ]; then
    echo "Info: QEMU_SHARED_HDD_SIZE not set in config, defaulting to $DEFAULT_SHARED_HDD_SIZE"
    QEMU_SHARED_HDD_SIZE="$DEFAULT_SHARED_HDD_SIZE"
fi

# Check if the specific ROM exists (Essential, cannot create)
if [ ! -f "$QEMU_ROM" ]; then
    echo "Error: ROM file '$QEMU_ROM' specified in config not found."
    exit 1
fi

# --- File Preparation ---

# Create PRAM image if it doesn't exist or is empty
# Now uses QEMU_PRAM variable from config
if [ ! -s "$QEMU_PRAM" ]; then
    PRAM_DIR=$(dirname "$QEMU_PRAM")
    if [ ! -d "$PRAM_DIR" ]; then
        echo "Creating directory for PRAM: $PRAM_DIR"
        mkdir -p "$PRAM_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create directory '$PRAM_DIR'."
            exit 1
        fi
    fi
    echo "Creating new PRAM image file: $QEMU_PRAM"
    dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create PRAM image '$QEMU_PRAM'."
        exit 1
    fi
fi

# Create OS hard disk image if it doesn't exist
if [ ! -f "$QEMU_HDD" ]; then
    HDD_DIR=$(dirname "$QEMU_HDD")
    if [ ! -d "$HDD_DIR" ]; then
        echo "Creating directory for OS HDD: $HDD_DIR"
        mkdir -p "$HDD_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create directory '$HDD_DIR'."
            exit 1
        fi
    fi
    OS_DISK_SIZE=${QEMU_HDD_SIZE:-1G}
    echo "OS hard disk image '$QEMU_HDD' not found. Creating ($OS_DISK_SIZE)..."
    qemu-img create -f raw "$QEMU_HDD" "$OS_DISK_SIZE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create OS hard disk image '$QEMU_HDD'."
        exit 1
    fi
    echo "Empty OS hard disk image created. Proceeding with boot (likely from CD for install)."
else
    echo "OS hard disk image '$QEMU_HDD' found."
fi

# Create config-specific shared disk image if it doesn't exist
if [ ! -f "$QEMU_SHARED_HDD" ]; then
    SHARED_HDD_DIR=$(dirname "$QEMU_SHARED_HDD")
    if [ ! -d "$SHARED_HDD_DIR" ]; then
        echo "Creating directory for Shared HDD: $SHARED_HDD_DIR"
        mkdir -p "$SHARED_HDD_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create directory '$SHARED_HDD_DIR'."
            exit 1
        fi
    fi
    echo "Shared disk image '$QEMU_SHARED_HDD' not found. Creating ($QEMU_SHARED_HDD_SIZE)..."
    qemu-img create -f raw "$QEMU_SHARED_HDD" "$QEMU_SHARED_HDD_SIZE"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create shared disk image '$QEMU_SHARED_HDD'."
        exit 1
    fi
    echo "Empty shared disk image created. Format it within the emulator."
    echo "To share files with the VM (Linux example):"
    echo "  1. sudo mount -o loop \"$QEMU_SHARED_HDD\" /mnt"
    echo "  2. Copy files"
    echo "  3. sudo umount /mnt"
fi

# --- Display Setup ---

if [ -z "$DISPLAY_TYPE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        DISPLAY_TYPE="cocoa"
    else
        DISPLAY_TYPE="sdl" # Default to SDL
    fi
fi

# --- QEMU Command Construction ---

echo "--- Starting Emulation ---"
echo "Configuration: $CONFIG_NAME"
echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M, ROM: $QEMU_ROM"
echo "OS HDD: $QEMU_HDD"
echo "Shared HDD: $QEMU_SHARED_HDD"
# Updated to show PRAM from config
echo "PRAM: $QEMU_PRAM"

# Prepare the base command
# Updated PRAM drive file to use QEMU_PRAM
QEMU_CMD="qemu-system-m68k \
    -M \"$QEMU_MACHINE\" \
    -m \"$QEMU_RAM\" \
    -bios \"$QEMU_ROM\" \
    -display \"$DISPLAY_TYPE\" \
    -g \"$QEMU_GRAPHICS\" \
    -drive file=\"$QEMU_PRAM\",format=raw,if=mtd \
    -net nic,model=dp83932 -net user"

# Add CPU if specified in config (optional)
if [ -n "$QEMU_CPU" ]; then
    QEMU_CMD="$QEMU_CMD -cpu \"$QEMU_CPU\""
fi

# Add hard disks and CD-ROM with appropriate boot order
if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
    echo "Boot order: CD-ROM first ($CD_FILE)"
    # *** MODIFIED VENDOR/PRODUCT STRINGS HERE ***
    QEMU_CMD="$QEMU_CMD \
    -device scsi-cd,scsi-id=0,drive=cd0 \
    -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0 \
    -device scsi-hd,scsi-id=1,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=2,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"
else
    echo "Boot order: OS HDD first"
    # Normal order - OS hard disk first (ID 0)
    # *** MODIFIED VENDOR/PRODUCT STRINGS HERE ***
    QEMU_CMD="$QEMU_CMD \
    -device scsi-hd,scsi-id=0,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=1,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"

    # Add CD-ROM if specified (as ID 3)
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
echo "--------------------------"
# Uncomment the next line if you want to see the full command before execution
# echo "Executing: $QEMU_CMD"

# Run QEMU
eval $QEMU_CMD

# --- Error Handling ---
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "QEMU exited with error code: $exit_code"
    if [ "$DISPLAY_TYPE" = "sdl" ] && [[ "$OSTYPE" != "darwin"* ]]; then
        echo "SDL display failed. You might try forcing GTK with: -d gtk"
        echo "(Install GTK support if needed: sudo apt install libgtk-3-dev)"
    fi
    echo "Check QEMU output for specific error messages."
else
    echo "QEMU session ended normally."
fi

exit $exit_code