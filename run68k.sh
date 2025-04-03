#!/bin/bash

# Script to run Mac OS emulation using QEMU with configuration files
# Supports TAP/Bridge networking and User Mode networking (with optional SMB).

# --- Strict Mode & Error Handling ---
set -o errexit  # Exit immediately if a command exits with a non-zero status.
set -o nounset  # Treat unset variables as an error when substituting.
set -o pipefail # Pipelines return status of the last command to exit with non-zero status.

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
QEMU_USER_SMB_DIR=""      # Optional: Directory to share via SMB in user mode networking

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

# --- Functions ---

# Display help information
show_help() {
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify configuration file (e.g., sys755-q800.conf)"
    echo "           The config file defines machine, RAM, ROM, disks, PRAM, graphics,"
    echo "           and optionally BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR (for TAP),"
    echo "           and QEMU_USER_SMB_DIR (for User mode SMB share)."
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
    echo "     - Can share a host directory via SMB using QEMU_USER_SMB_DIR in config."
    echo "     - Does NOT easily allow inter-VM communication or host-to-VM connections."
    echo "     - No special privileges or extra packages needed."
    exit 1
}

# Function to check for required commands
# Usage: check_command <command_name> [package_suggestion]
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: Command '$1' not found." >&2
        if [ -n "$2" ]; then
             echo "Please install it. Suggestion: $2" >&2
        fi
        # Allow the caller to decide if this is fatal
        return 1
    fi
    return 0
}

# Parse command-line arguments
parse_arguments() {
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

    # Validate Network Type early
    if [[ "$NETWORK_TYPE" != "tap" && "$NETWORK_TYPE" != "user" ]]; then
        echo "Error: Invalid network type specified with -N. Use 'tap' or 'user'." >&2
        show_help
    fi
}

# Validate essential configuration variables are set
validate_config() {
    local req_vars="QEMU_MACHINE QEMU_ROM QEMU_HDD QEMU_SHARED_HDD QEMU_RAM QEMU_GRAPHICS QEMU_PRAM"
    local missing_vars=false
    for var in $req_vars; do
        if [ -z "${!var}" ]; then # Use indirect expansion to check variable value
            echo "Error: Config file $CONFIG_FILE is missing required variable: $var" >&2
            missing_vars=true
        fi
    done
    # Check BRIDGE_NAME only if TAP is selected
    if [ "$NETWORK_TYPE" == "tap" ] && [ -z "$BRIDGE_NAME" ]; then
         echo "Error: Config file $CONFIG_FILE is missing required variable for TAP mode: BRIDGE_NAME (or default was empty)" >&2
         missing_vars=true
    fi
    if [ "$missing_vars" = true ]; then
        exit 1
    fi

    # Check if the specific ROM exists (Essential, cannot create)
    if [ ! -f "$QEMU_ROM" ]; then
        echo "Error: ROM file '$QEMU_ROM' specified in config not found." >&2
        exit 1
    fi
}

# Load configuration from file
load_configuration() {
    # Check if a configuration file was specified
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No configuration file specified. Use -C <config_file.conf>" >&2
        show_help
    fi

    # Check if the configuration file exists and load it
    if [ -f "$CONFIG_FILE" ]; then
        echo "Loading configuration from: $CONFIG_FILE"
        # Source the config file - variables defined here override defaults
        # Use . instead of source for POSIX compliance, though source is common in bash
        . "$CONFIG_FILE"
        # Check exit status of sourcing
        if [ $? -ne 0 ]; then
            echo "Error: Failed to source configuration file '$CONFIG_FILE'." >&2
            exit 1
        fi
    else
        echo "Error: Configuration file not found: $CONFIG_FILE" >&2
        exit 1
    fi

    # Validate the loaded configuration
    validate_config
}

# Prepare PRAM image
prepare_pram() {
    if [ ! -s "$QEMU_PRAM" ]; then
        local pram_dir
        pram_dir=$(dirname "$QEMU_PRAM")
        if [ ! -d "$pram_dir" ]; then
            echo "Creating directory for PRAM: $pram_dir"
            mkdir -p "$pram_dir"
            if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$pram_dir'." >&2; exit 1; fi
        fi
        echo "Creating new PRAM image file: $QEMU_PRAM"
        dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1 status=none
        if [ $? -ne 0 ]; then echo "Error: Failed to create PRAM image '$QEMU_PRAM'." >&2; exit 1; fi
    fi
}

# Prepare OS HDD image
prepare_hdd() {
    if [ ! -f "$QEMU_HDD" ]; then
        local hdd_dir
        hdd_dir=$(dirname "$QEMU_HDD")
        if [ ! -d "$hdd_dir" ]; then
            echo "Creating directory for OS HDD: $hdd_dir"
            mkdir -p "$hdd_dir"
            if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$hdd_dir'." >&2; exit 1; fi
        fi
        local os_disk_size="${QEMU_HDD_SIZE:-1G}" # Use default if not set
        echo "OS hard disk image '$QEMU_HDD' not found. Creating ($os_disk_size)..."
        qemu-img create -f raw "$QEMU_HDD" "$os_disk_size" > /dev/null
        if [ $? -ne 0 ]; then echo "Error: Failed to create OS hard disk image '$QEMU_HDD'." >&2; exit 1; fi
        echo "Empty OS hard disk image created. Proceeding with boot (likely from CD for install)."
    else
        echo "OS hard disk image '$QEMU_HDD' found."
    fi
}

# Prepare Shared HDD image
prepare_shared_hdd() {
    # Set default shared HDD size if not specified in config
    local default_shared_hdd_size="200M"
    if [ -z "$QEMU_SHARED_HDD_SIZE" ]; then
        echo "Info: QEMU_SHARED_HDD_SIZE not set in config, defaulting to $default_shared_hdd_size"
        QEMU_SHARED_HDD_SIZE="$default_shared_hdd_size"
    fi

    if [ ! -f "$QEMU_SHARED_HDD" ]; then
        local shared_hdd_dir
        shared_hdd_dir=$(dirname "$QEMU_SHARED_HDD")
        if [ ! -d "$shared_hdd_dir" ]; then
            echo "Creating directory for Shared HDD: $shared_hdd_dir"
            mkdir -p "$shared_hdd_dir"
            if [ $? -ne 0 ]; then echo "Error: Failed to create directory '$shared_hdd_dir'." >&2; exit 1; fi
        fi
        echo "Shared disk image '$QEMU_SHARED_HDD' not found. Creating ($QEMU_SHARED_HDD_SIZE)..."
        qemu-img create -f raw "$QEMU_SHARED_HDD" "$QEMU_SHARED_HDD_SIZE" > /dev/null
        if [ $? -ne 0 ]; then echo "Error: Failed to create shared disk image '$QEMU_SHARED_HDD'." >&2; exit 1; fi
        echo "Empty shared disk image created. Format it within the emulator."
        echo "To share files with the VM (Linux example):"
        echo "  1. sudo mount -o loop \"$QEMU_SHARED_HDD\" /mnt"
        echo "  2. Copy files"
        echo "  3. sudo umount /mnt"
    fi
}

# Prepare all necessary disk images
prepare_disk_images() {
    prepare_pram
    prepare_hdd
    prepare_shared_hdd
}

# Setup TAP networking specifics
setup_tap_networking() {
    echo "Info: Setting up TAP networking..."
    if [ -f "$TAP_FUNCTIONS_SCRIPT" ]; then
        # Source the functions into the current script's environment
        . "$TAP_FUNCTIONS_SCRIPT"
        if [ $? -ne 0 ]; then
             echo "Error: Failed to source TAP functions script '$TAP_FUNCTIONS_SCRIPT'." >&2
             exit 1
        fi
        # Check for commands required ONLY for TAP mode
        check_command "ip" "iproute2" || exit 1
        check_command "brctl" "bridge-utils" || exit 1
        check_command "sudo" "sudo" || exit 1
    else
        echo "Error: Network type 'tap' selected, but TAP functions script not found at: $TAP_FUNCTIONS_SCRIPT" >&2
        exit 1
    fi

    # Generate TAP device name if not specified in config
    if [ -z "$QEMU_TAP_IFACE" ]; then
        local config_basename
        config_basename=$(basename "$CONFIG_FILE" .conf)
        TAP_DEV_NAME=$(generate_tap_name "$config_basename")
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

    # Setup bridge first
    setup_bridge "$BRIDGE_NAME"

    # Setup TAP interface for this VM
    setup_tap "$TAP_DEV_NAME" "$BRIDGE_NAME" "$(whoami)" # Pass current user

    # Set trap to clean up TAP interface on exit
    # Pass TAP_DEV_NAME and BRIDGE_NAME correctly to the cleanup function
    trap "cleanup_tap '$TAP_DEV_NAME' '$BRIDGE_NAME'" EXIT SIGINT SIGTERM
    echo "Info: TAP networking enabled. Cleanup trap set."
}

# Setup User Mode networking specifics
setup_user_networking() {
    echo "Info: User Mode networking enabled. No host-side setup or cleanup needed."
    if [ -n "$QEMU_USER_SMB_DIR" ]; then
        if [ -d "$QEMU_USER_SMB_DIR" ]; then
            echo "Info: User mode SMB share configured for directory: $QEMU_USER_SMB_DIR"
        else
            echo "Warning: QEMU_USER_SMB_DIR specified ('$QEMU_USER_SMB_DIR') but directory does not exist. SMB share will likely fail." >&2
        fi
    fi
}

# Setup networking based on selected type
setup_networking() {
    if [ "$NETWORK_TYPE" == "tap" ]; then
        setup_tap_networking
    elif [ "$NETWORK_TYPE" == "user" ]; then
        setup_user_networking
    fi
}

# Determine the display type to use
determine_display_type() {
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
}

# Build the QEMU command line arguments in an array
build_qemu_command() {
    # Initialize the array
    qemu_args=()

    # Base arguments
    qemu_args+=(
        "-M" "$QEMU_MACHINE"
        "-m" "$QEMU_RAM"
        "-bios" "$QEMU_ROM"
        "-display" "$DISPLAY_TYPE"
        "-g" "$QEMU_GRAPHICS"
        "-drive" "file=$QEMU_PRAM,format=raw,if=mtd"
    )

    # Add CPU if specified in config (optional)
    if [ -n "$QEMU_CPU" ]; then
        qemu_args+=("-cpu" "$QEMU_CPU")
    fi

    # Construct Network Arguments based on type
    if [ "$NETWORK_TYPE" == "tap" ]; then
        echo "Network: TAP device '$TAP_DEV_NAME' on bridge '$BRIDGE_NAME', MAC: $MAC_ADDRESS"
        qemu_args+=(
            "-netdev" "tap,id=net0,ifname=$TAP_DEV_NAME,script=no,downscript=no"
            "-net" "nic,model=dp83932,netdev=net0,macaddr=$MAC_ADDRESS"
        )
    elif [ "$NETWORK_TYPE" == "user" ]; then
        echo "Network: User Mode Networking"
        local user_net_opts="user"
        if [ -n "$QEMU_USER_SMB_DIR" ] && [ -d "$QEMU_USER_SMB_DIR" ]; then
             user_net_opts+=",smb=$QEMU_USER_SMB_DIR"
        elif [ -n "$QEMU_USER_SMB_DIR" ]; then
             echo "Warning: SMB directory '$QEMU_USER_SMB_DIR' not found, skipping SMB share." >&2
        fi
        qemu_args+=(
            "-net" "nic,model=dp83932"
            "-net" "$user_net_opts"
        )
    fi

    # --- Add hard disks and CD-ROM with bootindex ---

    # Determine boot indices based on the -b flag
    local hdd_bootindex="1" # Default: HDD boots first
    local cd_bootindex="2"  # Default: CD boots second

    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        echo "Boot order: CD-ROM first (bootindex=1), HDD second (bootindex=2)"
        hdd_bootindex="2"
        cd_bootindex="1"
    elif [ "$BOOT_FROM_CD" = true ] && [ -z "$CD_FILE" ]; then
        echo "Warning: -b specified but no CD image provided with -c. Defaulting to HDD boot (bootindex=1)." >&2
        # hdd_bootindex remains 1
    else
        echo "Boot order: OS HDD first (bootindex=1)"
        # hdd_bootindex remains 1
        # cd_bootindex remains 2 (or higher if CD exists)
    fi


    # OS HDD (SCSI ID 0) - Assign its bootindex
    qemu_args+=(
        "-device" "scsi-hd,scsi-id=0,drive=hd0,bootindex=$hdd_bootindex,vendor=QEMU,product=QEMU_OS_DISK"
        "-drive" "file=$QEMU_HDD,media=disk,format=raw,if=none,id=hd0"
    )

    # Shared HDD (SCSI ID 1) - No bootindex needed unless you want it bootable
    qemu_args+=(
        "-device" "scsi-hd,scsi-id=1,drive=hd1,vendor=QEMU,product=QEMU_SHARED"
        "-drive" "file=$QEMU_SHARED_HDD,media=disk,format=raw,if=none,id=hd1"
    )

    # CD-ROM (SCSI ID 3) - Assign its bootindex only if specified
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE (as SCSI ID 3, bootindex=$cd_bootindex)"
        qemu_args+=(
            "-device" "scsi-cd,scsi-id=3,drive=cd0,bootindex=$cd_bootindex"
            "-drive" "file=$CD_FILE,format=raw,media=cdrom,if=none,id=cd0"
        )
    else
        echo "No CD-ROM specified"
    fi

    echo "Display: $DISPLAY_TYPE"
    echo "--------------------------"
}

# Run the emulation
run_emulation() {
    echo "--- Starting Emulation ---"
    echo "Configuration: $CONFIG_NAME"
    echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M, ROM: $QEMU_ROM"
    echo "OS HDD: $QEMU_HDD"
    echo "Shared HDD: $QEMU_SHARED_HDD"
    echo "PRAM: $QEMU_PRAM"

    # Uncomment the next line if you want to see the full command array before execution
    # declare -p qemu_args

    # Execute QEMU using the array
    qemu-system-m68k "${qemu_args[@]}"

    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "QEMU exited with error code: $exit_code" >&2
        echo "Check QEMU output for specific error messages." >&2
    else
        echo "QEMU session ended normally."
    fi

    # The trap (if set for TAP mode) will execute cleanup_tap here automatically
    # Exit with QEMU's exit code
    exit $exit_code
}

# --- Main Script Logic ---

# Check essential commands needed regardless of mode
check_command "qemu-system-m68k" "qemu-system-m68k package" || exit 1
check_command "qemu-img" "qemu-utils package" || exit 1
check_command "dd" "coreutils package" || exit 1

parse_arguments "$@"
load_configuration
prepare_disk_images
determine_display_type
setup_networking
build_qemu_command
run_emulation

# Script should have exited in run_emulation, but just in case:
exit 0