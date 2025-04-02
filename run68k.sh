#!/bin/bash

# Script to run Mac OS emulation using QEMU with configuration files
# Supports both TAP/Bridge networking (default) and User Mode networking.

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
BRIDGE_NAME="br0"         # Default bridge name (used only if NETWORK_TYPE=tap)
QEMU_TAP_IFACE=""         # Optional: Specific TAP interface name (used only if NETWORK_TYPE=tap)
QEMU_MAC_ADDR=""          # Optional: Specific MAC address (used only if NETWORK_TYPE=tap)

# --- Script variables ---
CONFIG_FILE=""
CD_FILE=""                # Path to CD/ISO image
BOOT_FROM_CD=false
DISPLAY_TYPE=""           # Auto-detect later if not specified
NETWORK_TYPE="tap"        # Default network type ('tap' or 'user')
TAP_FUNCTIONS_SCRIPT="./qemu-tap-functions.sh" # Path to TAP functions script

# --- Variables used only in TAP mode ---
TAP_DEV_NAME=""           # Actual TAP device name used for this instance
MAC_ADDRESS=""            # Actual MAC address used

# Display help information
show_help() {
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify configuration file (e.g., sys755-q800.conf)"
    echo "           The config file defines machine, RAM, ROM, disks, PRAM, graphics,"
    echo "           and optionally BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR (for TAP)."
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -b       Boot from CD-ROM (requires -c option)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -N TYPE  Specify network type: 'tap' (default, bridge-based) or 'user' (simple NAT)"
    echo "  -?       Show this help message"
    echo "Networking Notes:"
    echo "  'tap' mode (default): Uses TAP device on a bridge (default: br0)."
    echo "     - Enables inter-VM communication on the same bridge."
    echo "     - Requires '$TAP_FUNCTIONS_SCRIPT'."
    echo "     - Requires 'bridge-utils', 'iproute2', and sudo privileges."
    echo "     - Does NOT automatically provide internet access to VMs (requires extra host config)."
    echo "  'user' mode: Uses QEMU's built-in User Mode Networking."
    echo "     - Provides simple internet access via NAT (if host has it)."
    echo "     - Does NOT easily allow inter-VM communication or host-to-VM connections."
    echo "     - No special privileges or extra packages needed."
    exit 1
}

# Function to check for required commands
# Usage: check_command <command_name> [package_suggestion]
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Command '$1' not found."
        if [ -n "$2" ]; then
             echo "Please install it. Suggestion: $2"
        fi
        # Allow the main script to decide if this is fatal
        return 1
    fi
    return 0
}

# --- Argument Parsing ---
while getopts "C:c:bd:N:?" opt; do
    case $opt in
        C) CONFIG_FILE="$OPTARG" ;;
        c) CD_FILE="$OPTARG" ;;
        b) BOOT_FROM_CD=true ;;
        d) DISPLAY_TYPE="$OPTARG" ;;
        N) NETWORK_TYPE="$OPTARG" ;;
        \?|*) show_help ;;
    esac
done

# --- Validate Network Type ---
if [[ "$NETWORK_TYPE" != "tap" && "$NETWORK_TYPE" != "user" ]]; then
    echo "Error: Invalid network type specified with -N. Use 'tap' or 'user'."
    show_help
fi

# --- Source TAP Functions if needed ---
if [ "$NETWORK_TYPE" == "tap" ]; then
    if [ -f "$TAP_FUNCTIONS_SCRIPT" ]; then
        # Source the functions into the current script's environment
        source "$TAP_FUNCTIONS_SCRIPT"
        # Check for commands required ONLY for TAP mode
        check_command "ip" "iproute2" || exit 1
        check_command "brctl" "bridge-utils" || exit 1
        check_command "sudo" "sudo" || exit 1
    else
        echo "Error: Network type 'tap' selected, but TAP functions script not found at: $TAP_FUNCTIONS_SCRIPT"
        exit 1
    fi
fi

# --- General Command Checks ---
check_command "qemu-system-m68k" "qemu-system-m68k package" || exit 1
check_command "qemu-img" "qemu-utils package" || exit 1
check_command "dd" "coreutils package" || exit 1

# --- Validation and Configuration Loading ---

# Check if a configuration file was specified
if [ -z "$CONFIG_FILE" ]; then
    echo "Error: No configuration file specified. Use -C <config_file.conf>"
    show_help
fi

# Check if the configuration file exists and load it
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading configuration from: $CONFIG_FILE"
    # Source the config file - variables defined here override defaults
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check if essential variables were loaded from config
# BRIDGE_NAME is only essential if using TAP mode
REQ_VARS="QEMU_MACHINE QEMU_ROM QEMU_HDD QEMU_SHARED_HDD QEMU_RAM QEMU_GRAPHICS QEMU_PRAM"
MISSING_VARS=false
for var in $REQ_VARS; do
    if [ -z "${!var}" ]; then # Use indirect expansion to check variable value
        echo "Error: Config file $CONFIG_FILE is missing required variable: $var"
        MISSING_VARS=true
    fi
done
# Check BRIDGE_NAME only if TAP is selected
if [ "$NETWORK_TYPE" == "tap" ] && [ -z "$BRIDGE_NAME" ]; then
     echo "Error: Config file $CONFIG_FILE is missing required variable for TAP mode: BRIDGE_NAME (or default was empty)"
     MISSING_VARS=true
fi
if [ "$MISSING_VARS" = true ]; then
    exit 1
fi


# --- Dynamic Value Generation (TAP specific) ---
if [ "$NETWORK_TYPE" == "tap" ]; then
    # Generate TAP device name if not specified in config
    if [ -z "$QEMU_TAP_IFACE" ]; then
        CONFIG_BASENAME=$(basename "$CONFIG_FILE" .conf)
        TAP_DEV_NAME=$(generate_tap_name "$CONFIG_BASENAME")
        echo "Info: QEMU_TAP_IFACE not set in config, generated TAP name: $TAP_DEV_NAME"
    else
        TAP_DEV_NAME="$QEMU_TAP_IFACE"
        echo "Info: Using TAP interface name from config: $TAP_DEV_NAME"
    fi

    # Generate MAC address if not specified
    if [ -z "$QEMU_MAC_ADDR" ]; then
        MAC_ADDRESS=$(generate_mac)
        echo "Info: QEMU_MAC_ADDR not set in config, generated MAC: $MAC_ADDRESS"
    else
        MAC_ADDRESS="$QEMU_MAC_ADDR"
        echo "Info: Using MAC address from config: $MAC_ADDRESS"
    fi
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
if [ ! -s "$QEMU_PRAM" ]; then
    PRAM_DIR=$(dirname "$QEMU_PRAM")
    if [ ! -d "$PRAM_DIR" ]; then
        echo "Creating directory for PRAM: $PRAM_DIR"
        mkdir -p "$PRAM_DIR"
        if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$PRAM_DIR'."; exit 1; fi
    fi
    echo "Creating new PRAM image file: $QEMU_PRAM"
    dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1 status=none
    if [ $? -ne 0 ]; then echo "Error: Failed to create PRAM image '$QEMU_PRAM'."; exit 1; fi
fi

# Create OS hard disk image if it doesn't exist
if [ ! -f "$QEMU_HDD" ]; then
    HDD_DIR=$(dirname "$QEMU_HDD")
    if [ ! -d "$HDD_DIR" ]; then
        echo "Creating directory for OS HDD: $HDD_DIR"
        mkdir -p "$HDD_DIR"
        if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$HDD_DIR'."; exit 1; fi
    fi
    OS_DISK_SIZE=${QEMU_HDD_SIZE:-1G}
    echo "OS hard disk image '$QEMU_HDD' not found. Creating ($OS_DISK_SIZE)..."
    qemu-img create -f raw "$QEMU_HDD" "$OS_DISK_SIZE" > /dev/null
    if [ $? -ne 0 ]; then echo "Error: Failed to create OS hard disk image '$QEMU_HDD'."; exit 1; fi
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
        if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$SHARED_HDD_DIR'."; exit 1; fi
    fi
    echo "Shared disk image '$QEMU_SHARED_HDD' not found. Creating ($QEMU_SHARED_HDD_SIZE)..."
    qemu-img create -f raw "$QEMU_SHARED_HDD" "$QEMU_SHARED_HDD_SIZE" > /dev/null
    if [ $? -ne 0 ]; then echo "Error: Failed to create shared disk image '$QEMU_SHARED_HDD'."; exit 1; fi
    echo "Empty shared disk image created. Format it within the emulator."
    echo "To share files with the VM (Linux example):"
    echo "  1. sudo mount -o loop \"$QEMU_SHARED_HDD\" /mnt"
    echo "  2. Copy files"
    echo "  3. sudo umount /mnt"
fi

# --- Display Setup ---
# Determine default display type if not forced by -d option
if [ -z "$DISPLAY_TYPE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        DISPLAY_TYPE="cocoa" # Cocoa is generally better on macOS
        echo "Info: Detected macOS, using 'cocoa' display. Use -d to override."
    else
        # Default to SDL on Linux/other systems
        DISPLAY_TYPE="sdl"
        echo "Info: Defaulting to 'sdl' display on this system. Use -d to override (e.g., -d gtk)."
    fi
fi

# --- Network Setup (Conditional) ---
if [ "$NETWORK_TYPE" == "tap" ]; then
    # Setup bridge first
    setup_bridge "$BRIDGE_NAME"

    # Setup TAP interface for this VM
    setup_tap "$TAP_DEV_NAME" "$BRIDGE_NAME" "$(whoami)" # Pass current user

    # Set trap to clean up TAP interface on exit
    # Pass TAP_DEV_NAME and BRIDGE_NAME correctly to the cleanup function
    trap "cleanup_tap '$TAP_DEV_NAME' '$BRIDGE_NAME'" EXIT SIGINT SIGTERM
    echo "Info: TAP networking enabled. Cleanup trap set."
else
    echo "Info: User Mode networking enabled. No host-side setup or cleanup needed."
fi

# --- QEMU Command Construction ---

echo "--- Starting Emulation ---"
echo "Configuration: $CONFIG_NAME"
echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M, ROM: $QEMU_ROM"
echo "OS HDD: $QEMU_HDD"
echo "Shared HDD: $QEMU_SHARED_HDD"
echo "PRAM: $QEMU_PRAM"

# Prepare the base command (excluding network)
QEMU_CMD_BASE="qemu-system-m68k \
    -M \"$QEMU_MACHINE\" \
    -m \"$QEMU_RAM\" \
    -bios \"$QEMU_ROM\" \
    -display \"$DISPLAY_TYPE\" \
    -g \"$QEMU_GRAPHICS\" \
    -drive file=\"$QEMU_PRAM\",format=raw,if=mtd"

# Add CPU if specified in config (optional)
if [ -n "$QEMU_CPU" ]; then
    QEMU_CMD_BASE="$QEMU_CMD_BASE -cpu \"$QEMU_CPU\""
fi

# Construct Network Arguments based on type
QEMU_NET_ARGS=""
if [ "$NETWORK_TYPE" == "tap" ]; then
    echo "Network: TAP device '$TAP_DEV_NAME' on bridge '$BRIDGE_NAME', MAC: $MAC_ADDRESS"
    QEMU_NET_ARGS="-netdev tap,id=net0,ifname=$TAP_DEV_NAME,script=no,downscript=no -net nic,netdev=net0,macaddr=$MAC_ADDRESS"
elif [ "$NETWORK_TYPE" == "user" ]; then
    echo "Network: User Mode Networking"
    # Use a common NIC model compatible with classic MacOS networking (e.g., OpenTransport)
    QEMU_NET_ARGS="-net nic,model=dp83932 -net user"
fi

# Add hard disks and CD-ROM with appropriate boot order
QEMU_DRIVE_ARGS=""
if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
    echo "Boot order: CD-ROM first ($CD_FILE)"
    QEMU_DRIVE_ARGS="$QEMU_DRIVE_ARGS \
    -device scsi-cd,scsi-id=0,drive=cd0 \
    -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0 \
    -device scsi-hd,scsi-id=1,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=2,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"
else
    echo "Boot order: OS HDD first"
    QEMU_DRIVE_ARGS="$QEMU_DRIVE_ARGS \
    -device scsi-hd,scsi-id=0,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=1,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"

    # Add CD-ROM if specified (as SCSI ID 3)
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE (as SCSI ID 3)"
        QEMU_DRIVE_ARGS="$QEMU_DRIVE_ARGS \
        -device scsi-cd,scsi-id=3,drive=cd0 \
        -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0"
    else
        echo "No CD-ROM specified"
    fi
fi

echo "Display: $DISPLAY_TYPE"
echo "--------------------------"

# Combine all parts of the command
QEMU_CMD="$QEMU_CMD_BASE $QEMU_NET_ARGS $QEMU_DRIVE_ARGS"

# Uncomment the next line if you want to see the full command before execution
# echo "Executing: $QEMU_CMD"

# Run QEMU
eval $QEMU_CMD

# --- Error Handling ---
# Note: Cleanup for TAP is handled by the trap
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "QEMU exited with error code: $exit_code"
    echo "Check QEMU output for specific error messages."
else
    echo "QEMU session ended normally."
fi

# The trap (if set for TAP mode) will execute cleanup_tap here automatically
exit $exit_code