#!/bin/bash

# Script to run Mac OS emulation using QEMU with configuration files
# Updated to use TAP networking via a bridge for inter-VM communication
# Defaults to SDL display on Linux/non-macOS systems

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
BRIDGE_NAME="br0"         # Default bridge name (can be overridden in config)
QEMU_TAP_IFACE=""         # Optional: Specific TAP interface name (generated if empty)
QEMU_MAC_ADDR=""          # Optional: Specific MAC address (generated if empty)

# --- Script variables ---
CONFIG_FILE=""
CD_FILE=""                # Path to CD/ISO image
BOOT_FROM_CD=false
DISPLAY_TYPE=""           # Auto-detect later if not specified
TAP_DEV_NAME=""           # Actual TAP device name used for this instance
MAC_ADDRESS=""            # Actual MAC address used

# Display help information
show_help() {
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify configuration file (e.g., sys755-q800.conf)"
    echo "           The config file defines machine, RAM, ROM, disks, PRAM, graphics,"
    echo "           and optionally BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR."
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -b       Boot from CD-ROM (requires -c option)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -?       Show this help message"
    echo "Networking:"
    echo "  This script sets up TAP networking via a bridge (default: br0)."
    echo "  Requires 'bridge-utils' package and sudo privileges."
    exit 1
}

# --- Helper Functions ---

# Function to check for required commands
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Command '$1' not found."
        if [ "$1" == "brctl" ]; then
            echo "Please install 'bridge-utils': sudo apt update && sudo apt install bridge-utils"
        fi
        exit 1
    fi
}

# Function to generate a random MAC address if not provided
generate_mac() {
    hexchars="0123456789ABCDEF"
    # QEMU MAC prefix 52:54:00
    echo "52:54:00:$(for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/\1:/g' -e 's/:$//')"
}

# Function to set up the network bridge
setup_bridge() {
    local bridge="$1"
    echo "--- Network Setup ---"
    echo "Ensuring bridge '$bridge' exists and is up..."
    if ! ip link show "$bridge" &> /dev/null; then
        echo "Bridge '$bridge' not found. Creating..."
        sudo ip link add name "$bridge" type bridge
        if [ $? -ne 0 ]; then echo "Error: Failed to create bridge '$bridge'."; exit 1; fi
        echo "Bringing bridge '$bridge' up..."
        sudo ip link set "$bridge" up
        if [ $? -ne 0 ]; then echo "Error: Failed to bring up bridge '$bridge'."; exit 1; fi
        echo "Bridge '$bridge' created and up."
    else
        # Ensure bridge is up even if it exists
        if ! ip link show "$bridge" | grep -q "state UP"; then
             echo "Bridge '$bridge' exists but is down. Bringing up..."
             sudo ip link set "$bridge" up
             if [ $? -ne 0 ]; then echo "Error: Failed to bring up bridge '$bridge'."; exit 1; fi
        else
             echo "Bridge '$bridge' already exists and is up."
        fi
    fi
    echo "---------------------"
}

# Function to set up the TAP interface for the VM
# Takes TAP name and Bridge name as arguments
setup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    local current_user=$(whoami)

    echo "--- Network Setup ---"
    echo "Setting up TAP interface '$tap_name' for user '$current_user'..."

    # Check if TAP device already exists (maybe from a crashed previous run)
    if ip link show "$tap_name" &> /dev/null; then
        echo "Warning: TAP device '$tap_name' already exists. Trying to reuse/reconfigure."
        # Ensure it's down before potential deletion or reconfiguration
        sudo ip link set "$tap_name" down &> /dev/null
        # Attempt to remove from bridge just in case it's stuck
        sudo brctl delif "$bridge_name" "$tap_name" &> /dev/null
    fi

    echo "Creating TAP device '$tap_name'..."
    sudo ip tuntap add dev "$tap_name" mode tap user "$current_user"
    if [ $? -ne 0 ]; then echo "Error: Failed to create TAP device '$tap_name'."; exit 1; fi

    echo "Bringing TAP device '$tap_name' up..."
    sudo ip link set "$tap_name" up
    if [ $? -ne 0 ]; then echo "Error: Failed to bring up TAP device '$tap_name'."; sudo ip tuntap del dev "$tap_name" mode tap; exit 1; fi

    echo "Adding TAP device '$tap_name' to bridge '$bridge_name'..."
    sudo brctl addif "$bridge_name" "$tap_name"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add TAP device '$tap_name' to bridge '$bridge_name'."
        sudo ip link set "$tap_name" down
        sudo ip tuntap del dev "$tap_name" mode tap
        exit 1
    fi

    echo "TAP device '$tap_name' is up and added to bridge '$bridge_name'."
    echo "---------------------"
}

# Function to clean up the TAP interface
# Takes TAP name and Bridge name as arguments
cleanup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    echo # Newline for clarity after QEMU exits
    echo "--- Network Cleanup ---"
    echo "Cleaning up TAP interface '$tap_name'..."

    # Check if the interface exists before trying to manipulate it
    if ip link show "$tap_name" &> /dev/null; then
        echo "Removing TAP device '$tap_name' from bridge '$bridge_name'..."
        sudo brctl delif "$bridge_name" "$tap_name"
        # Don't exit on error here, proceed to bring down and delete

        echo "Bringing TAP device '$tap_name' down..."
        sudo ip link set "$tap_name" down

        echo "Deleting TAP device '$tap_name'..."
        sudo ip tuntap del dev "$tap_name" mode tap
    else
        echo "TAP device '$tap_name' not found, cleanup skipped."
    fi
    echo "-----------------------"
}

# --- Argument Parsing ---
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

# Check required tools
check_command "ip"
check_command "brctl"
check_command "qemu-system-m68k"
check_command "qemu-img"
check_command "sudo"
check_command "dd"

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
if [ -z "$QEMU_MACHINE" ] || [ -z "$QEMU_ROM" ] || [ -z "$QEMU_HDD" ] || [ -z "$QEMU_SHARED_HDD" ] || [ -z "$QEMU_RAM" ] || [ -z "$QEMU_GRAPHICS" ] || [ -z "$QEMU_PRAM" ] || [ -z "$BRIDGE_NAME" ]; then
     echo "Error: Config file $CONFIG_FILE is missing one or more required variables:"
     echo "Required: QEMU_MACHINE, QEMU_ROM, QEMU_HDD, QEMU_SHARED_HDD, QEMU_RAM, QEMU_GRAPHICS, QEMU_PRAM"
     echo "Required (can use default): BRIDGE_NAME"
     exit 1
fi

# --- Dynamic Value Generation ---

# Generate TAP device name if not specified in config
if [ -z "$QEMU_TAP_IFACE" ]; then
    # Sanitize config file name for use as part of tap name
    SANITIZED_CONF_NAME=$(basename "$CONFIG_FILE" .conf | sed 's/[^a-zA-Z0-9]//g')
    # Limit length to avoid exceeding interface name limits (IFNAMSIZ is often 16)
    TAP_DEV_NAME="tap_${SANITIZED_CONF_NAME:0:10}"
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

# --- Network Setup ---
# Setup bridge first
setup_bridge "$BRIDGE_NAME"

# Setup TAP interface for this VM
setup_tap "$TAP_DEV_NAME" "$BRIDGE_NAME"

# Set trap to clean up TAP interface on exit
# Pass TAP_DEV_NAME and BRIDGE_NAME correctly to the cleanup function
trap "cleanup_tap '$TAP_DEV_NAME' '$BRIDGE_NAME'" EXIT SIGINT SIGTERM

# --- QEMU Command Construction ---

echo "--- Starting Emulation ---"
echo "Configuration: $CONFIG_NAME"
echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M, ROM: $QEMU_ROM"
echo "OS HDD: $QEMU_HDD"
echo "Shared HDD: $QEMU_SHARED_HDD"
echo "PRAM: $QEMU_PRAM"
echo "Network: TAP device '$TAP_DEV_NAME' on bridge '$BRIDGE_NAME', MAC: $MAC_ADDRESS"

# Prepare the base command
# Use TAP networking instead of -net user
# Specify MAC address for the NIC using -net nic
QEMU_CMD="qemu-system-m68k \
    -M \"$QEMU_MACHINE\" \
    -m \"$QEMU_RAM\" \
    -bios \"$QEMU_ROM\" \
    -display \"$DISPLAY_TYPE\" \
    -g \"$QEMU_GRAPHICS\" \
    -drive file=\"$QEMU_PRAM\",format=raw,if=mtd \
    -netdev tap,id=net0,ifname=$TAP_DEV_NAME,script=no,downscript=no \
    -net nic,netdev=net0,macaddr=$MAC_ADDRESS"

# Add CPU if specified in config (optional)
if [ -n "$QEMU_CPU" ]; then
    QEMU_CMD="$QEMU_CMD -cpu \"$QEMU_CPU\""
fi

# Add hard disks and CD-ROM with appropriate boot order
if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
    echo "Boot order: CD-ROM first ($CD_FILE)"
    QEMU_CMD="$QEMU_CMD \
    -device scsi-cd,scsi-id=0,drive=cd0 \
    -drive file=\"$CD_FILE\",format=raw,media=cdrom,if=none,id=cd0 \
    -device scsi-hd,scsi-id=1,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=2,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"
else
    echo "Boot order: OS HDD first"
    QEMU_CMD="$QEMU_CMD \
    -device scsi-hd,scsi-id=0,drive=hd0,vendor=\"SEAGATE\",product=\"ST31200N\" \
    -drive file=\"$QEMU_HDD\",media=disk,format=raw,if=none,id=hd0 \
    -device scsi-hd,scsi-id=1,drive=hd1,vendor=\"SEAGATE\",product=\"ST3200N\" \
    -drive file=\"$QEMU_SHARED_HDD\",media=disk,format=raw,if=none,id=hd1"

    # Add CD-ROM if specified (as SCSI ID 3)
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
# Note: Cleanup is handled by the trap
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "QEMU exited with error code: $exit_code"
    # Removed specific GTK/SDL failure messages as SDL is now default on Linux
    # User can still force GTK with -d gtk if needed and available
    echo "Check QEMU output for specific error messages."
else
    echo "QEMU session ended normally."
fi

# The trap will execute cleanup_tap here automatically
exit $exit_code