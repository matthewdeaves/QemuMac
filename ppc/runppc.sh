#!/usr/bin/env bash

#######################################
# QEMU PowerPC Mac OS Emulation Runner
# Main script to run PowerPC Mac OS emulation using QEMU with configuration files
# Supports Mac OS 9 and Mac OS X emulation with IDE storage
# Supports TAP/Bridge, User Mode (with optional SMB), and Passt networking.
# Uses simple boot order control (-boot c/d) instead of PRAM.
# Allows attaching an additional user-specified hard drive.
#######################################

# Source shared utilities and modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/qemu-utils.sh
source "$SCRIPT_DIR/../scripts/qemu-utils.sh"
# shellcheck source=../scripts/qemu-config.sh
source "$SCRIPT_DIR/../scripts/qemu-config.sh"
# shellcheck source=../scripts/qemu-networking.sh
source "$SCRIPT_DIR/../scripts/qemu-networking.sh"
# shellcheck source=../scripts/qemu-display.sh
source "$SCRIPT_DIR/../scripts/qemu-display.sh"

# --- Script Constants ---
readonly REQUIRED_QEMU_VERSION="4.0"
readonly TAP_FUNCTIONS_SCRIPT="$SCRIPT_DIR/../scripts/qemu-tap-functions.sh"

# --- Configuration Variables (loaded from .conf file) ---
CONFIG_NAME=""
QEMU_MACHINE=""
QEMU_RAM=""
QEMU_HDD=""
QEMU_SHARED_HDD=""
QEMU_SHARED_HDD_SIZE=""
QEMU_GRAPHICS=""
QEMU_CPU=""
QEMU_SMP_CORES=""
QEMU_HDD_SIZE=""
BRIDGE_NAME=""
QEMU_TAP_IFACE=""
QEMU_MAC_ADDR=""
QEMU_USER_SMB_DIR=""
QEMU_AUDIO_BACKEND=""
QEMU_AUDIO_LATENCY=""
QEMU_SOUND_DEVICE=""
QEMU_TCG_THREAD_MODE=""
QEMU_TB_SIZE=""
QEMU_MEMORY_BACKEND=""
QEMU_IDE_CACHE_MODE=""
QEMU_IDE_AIO_MODE=""
QEMU_DISPLAY_DEVICE=""
QEMU_RESOLUTION_PRESET=""
QEMU_USB_ENABLED=""

# --- Script Variables ---
CONFIG_FILE=""
CD_FILE=""
ADDITIONAL_HDD_FILE=""
BOOT_FROM_CD=false
DISPLAY_TYPE=""
# Auto-detect network type based on OS (User mode is simpler for PPC)
if [[ "$(uname)" == "Darwin" ]]; then
    NETWORK_TYPE="user"  # Default to user mode on macOS (TAP requires Linux tools)
else
    NETWORK_TYPE="user"  # Default to user mode on Linux for PPC (simpler than TAP)
fi
DEBUG_MODE=false

# --- Variables used only in TAP mode ---
TAP_DEV_NAME=""
MAC_ADDRESS=""

#######################################
# Display help information
# Arguments:
#   None
# Globals:
#   TAP_FUNCTIONS_SCRIPT
# Returns:
#   None
# Exits:
#   1 (help display always exits)
#######################################
show_help() {
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo "Required:"
    echo "  -C FILE  Specify configuration file (e.g., macos91-standard.conf)"
    echo "           The config file defines machine, RAM, disks, graphics, audio,"
    echo "           and optionally BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR (for TAP),"
    echo "           QEMU_USER_SMB_DIR (for User mode SMB share), QEMU_AUDIO_BACKEND,"
    echo "           QEMU_AUDIO_LATENCY, and QEMU_SOUND_DEVICE (for audio configuration)."
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -a FILE  Specify an additional hard drive image file (must be properly formatted Mac HFS/HFS+ image with valid partition)"
    echo "  -b       Boot from CD-ROM (for OS installation)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -N TYPE  Specify network type: 'tap' (Linux default), 'user' (macOS default, NAT), or 'passt' (slirp alternative)"
    echo "  -D       Enable debug mode (set -x, show detailed info before launch)"
    echo "  -?       Show this help message"
    echo "Networking Notes:"
    echo "  'tap' mode (Linux default): Uses TAP device on a bridge (default: $DEFAULT_BRIDGE_NAME)."
    echo "     - Enables inter-VM communication on the same bridge."
    echo "     - Requires '$TAP_FUNCTIONS_SCRIPT'."
    echo "     - Requires 'bridge-utils', 'iproute2', and sudo privileges."
    echo "     - Does NOT automatically provide internet access to VMs (requires extra host config)."
    echo "  'user' mode (macOS default): Uses QEMU's built-in User Mode Networking."
    echo "     - Provides simple internet access via NAT (if host has it)."
    echo "     - Can share a host directory via SMB using QEMU_USER_SMB_DIR in config."
    echo "     - Does NOT easily allow inter-VM communication or host-to-VM connections."
    echo "     - No special privileges or extra packages needed."
    echo "     - Recommended for macOS as TAP mode requires Linux-specific tools."
    echo "  'passt' mode: Uses the passt userspace networking backend."
    echo "     - Alternative to 'user' mode, potentially better performance/features."
    echo "     - Requires the 'passt' command to be installed on the host (see https://passt.top/)."
    exit 1
}

#######################################
# Parse command-line arguments with enhanced validation
# Arguments:
#   All command line arguments
# Globals:
#   CONFIG_FILE, CD_FILE, ADDITIONAL_HDD_FILE, BOOT_FROM_CD
#   DISPLAY_TYPE, NETWORK_TYPE, DEBUG_MODE
# Returns:
#   None
# Exits:
#   1 if invalid arguments provided
#######################################
parse_arguments() {
    while getopts "C:c:a:bd:N:D?" opt; do
        case $opt in
            C) 
                CONFIG_FILE="$OPTARG"
                validate_config_filename "$(basename "$CONFIG_FILE")" || exit 1
                ;;
            c) 
                CD_FILE="$OPTARG"
                ;;
            a) 
                ADDITIONAL_HDD_FILE="$OPTARG"
                ;;
            b) 
                BOOT_FROM_CD=true
                ;;
            d) 
                DISPLAY_TYPE="$OPTARG"
                validate_display_type "$DISPLAY_TYPE" || exit 1
                ;;
            N) 
                NETWORK_TYPE="$OPTARG"
                ;;
            D) 
                DEBUG_MODE=true
                debug_log "Debug mode enabled"
                set -x
                ;;
            \\?|*) 
                show_help
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No configuration file specified. Use -C <config_file.conf>" >&2
        show_help
    fi
    
    # Validate Network Type early
    if [[ "$NETWORK_TYPE" != "tap" && "$NETWORK_TYPE" != "user" && "$NETWORK_TYPE" != "passt" ]]; then
        echo "Error: Invalid network type specified with -N. Use 'tap', 'user', or 'passt'." >&2
        show_help
    fi
    
    debug_log "Arguments parsed successfully"
    debug_log "Config: $CONFIG_FILE, Network: $NETWORK_TYPE, Display: ${DISPLAY_TYPE:-auto}"
}

#######################################
# Create disk images if they don't exist (simplified for PPC)
# Arguments:
#   None
# Globals:
#   Various QEMU configuration variables
# Returns:
#   None
#######################################
prepare_disk_images() {
    local hdd_size="${QEMU_HDD_SIZE:-15G}"
    local shared_size="${QEMU_SHARED_HDD_SIZE:-1G}"
    
    # Create data directory if it doesn't exist
    local data_dir
    data_dir="$(dirname "$QEMU_HDD")"
    if [ ! -d "$data_dir" ]; then
        info_log "Creating data directory: $data_dir"
        mkdir -p "$data_dir"
    fi
    
    # Create OS hard disk image if it doesn't exist
    if [ ! -f "$QEMU_HDD" ]; then
        info_log "PowerPC OS hard disk image '$QEMU_HDD' not found. Creating ${hdd_size}..."
        qemu-img create -f raw "$QEMU_HDD" "$hdd_size"
        check_exit_status $? "Failed to create PowerPC OS hard disk image '$QEMU_HDD'"
        echo "Empty PowerPC OS hard disk image created (${hdd_size}). Proceeding with boot likely from CD for install."
        echo "Note: Format this drive with Mac OS Disk Utility during installation."
    fi
    
    # Create shared disk image if it doesn't exist
    if [ ! -f "$QEMU_SHARED_HDD" ]; then
        info_log "PowerPC shared disk image '$QEMU_SHARED_HDD' not found. Creating ${shared_size}..."
        qemu-img create -f raw "$QEMU_SHARED_HDD" "$shared_size"
        check_exit_status $? "Failed to create PowerPC shared disk image '$QEMU_SHARED_HDD'"
        echo "Empty PowerPC shared disk image created (${shared_size}). Format it within the emulator."
        echo "To share files with the PowerPC VM - Linux example:"
        echo "  1. Format as HFS+ in Mac OS first"
        echo "  2. sudo mount -t hfsplus -o loop \"$QEMU_SHARED_HDD\" /mnt"
        echo "  3. Copy files"
        echo "  4. sudo umount /mnt"
        echo "Note: Install hfsprogs package for HFS+ support on Linux host"
    fi
    
    info_log "All PowerPC disk images prepared successfully"
}

#######################################
# Build PPC-specific network arguments (simplified vs 68k)
# Arguments:
#   network_type: Type of networking (tap, user, passt)
#   qemu_args_ref: Reference to qemu_args array
# Globals:
#   BRIDGE_NAME, QEMU_USER_SMB_DIR
# Returns:
#   None
#######################################
build_ppc_network_args() {
    local network_type="$1"
    local -n qemu_args_ref=$2
    
    case "$network_type" in
        "tap")
            # Simplified TAP for PPC - use rtl8139 which is more compatible
            echo "Network: TAP mode (simplified for PPC)"
            qemu_args_ref+=(
                "-netdev" "tap,id=net0"
                "-device" "rtl8139,netdev=net0"
            )
            ;;
        "user")
            echo "Network: User Mode Networking"
            local user_opts="user,id=net0"
            if [ -n "${QEMU_USER_SMB_DIR:-}" ] && [ -d "$QEMU_USER_SMB_DIR" ]; then
                user_opts+=",smb=$QEMU_USER_SMB_DIR"
                echo "SMB share: $QEMU_USER_SMB_DIR"
            fi
            qemu_args_ref+=(
                "-netdev" "$user_opts"
                "-device" "rtl8139,netdev=net0"
            )
            ;;
        "passt")
            # Check if passt is available
            if ! command -v passt &> /dev/null; then
                echo "Error: passt command not found. Install passt or use -N user" >&2
                exit 1
            fi
            echo "Network: Passt backend"
            qemu_args_ref+=(
                "-netdev" "stream,id=net0,server=off,addr.type=unix,addr.path=/tmp/passt.socket"
                "-device" "rtl8139,netdev=net0"
            )
            ;;
        *)
            echo "Error: Unknown network type '$network_type'" >&2
            exit 1
            ;;
    esac
}

#######################################
# Build the QEMU command line arguments (PPC version)
# Arguments:
#   None
# Globals:
#   Various QEMU configuration variables
# Returns:
#   Sets qemu_args array
#######################################
build_qemu_command() {
    # Initialize the array
    qemu_args=()
    
    # Base machine arguments
    qemu_args+=(
        "-L" "pc-bios"
        "-M" "$QEMU_MACHINE"
        "-display" "$DISPLAY_TYPE"
        "-m" "$QEMU_RAM"
    )
    
    # Add CPU type if specified
    if [ -n "$QEMU_CPU" ]; then
        qemu_args+=("-cpu" "$QEMU_CPU")
    fi
    
    # Add SMP support if specified and greater than 1
    # Note: PowerPC mac99 machine only supports 1 CPU maximum
    if [ -n "$QEMU_SMP_CORES" ] && [ "$QEMU_SMP_CORES" -gt 1 ]; then
        qemu_args+=("-smp" "$QEMU_SMP_CORES")
    fi
    
    # Add TCG acceleration with threading and translation block cache settings
    local accel_opts="tcg"
    if [ -n "$QEMU_TCG_THREAD_MODE" ] && [ "$QEMU_TCG_THREAD_MODE" != "single" ]; then
        accel_opts="${accel_opts},thread=${QEMU_TCG_THREAD_MODE}"
    fi
    if [ -n "$QEMU_TB_SIZE" ]; then
        accel_opts="${accel_opts},tb-size=${QEMU_TB_SIZE}"
    fi
    qemu_args+=("-accel" "$accel_opts")
    
    # Add boot order - PPC uses simple -boot flag instead of PRAM
    if [ "$BOOT_FROM_CD" = true ]; then
        qemu_args+=("-boot" "d")  # Boot from CD-ROM
    else
        qemu_args+=("-boot" "c")  # Boot from hard disk
    fi
    
    # --- Storage drives with performance settings ---
    local drive_opts=""
    
    # Build IDE performance options
    if [ -n "$QEMU_IDE_CACHE_MODE" ]; then
        drive_opts="cache=${QEMU_IDE_CACHE_MODE}"
    fi
    if [ -n "$QEMU_IDE_AIO_MODE" ]; then
        if [ -n "$drive_opts" ]; then
            drive_opts="${drive_opts},aio=${QEMU_IDE_AIO_MODE}"
        else
            drive_opts="aio=${QEMU_IDE_AIO_MODE}"
        fi
        
        # Add cache.direct=on when using native AIO (required by QEMU)
        if [ "$QEMU_IDE_AIO_MODE" = "native" ]; then
            if [ -n "$drive_opts" ]; then
                drive_opts="${drive_opts},cache.direct=on"
            else
                drive_opts="cache.direct=on"
            fi
        fi
    fi
    
    # Add CD-ROM first if specified
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE"
        qemu_args+=("-drive" "file=$CD_FILE,format=raw,media=cdrom")
    fi
    
    # Add main HDD with performance options
    local main_hdd_drive="file=$QEMU_HDD,format=raw,media=disk"
    if [ -n "$drive_opts" ]; then
        main_hdd_drive="${main_hdd_drive},${drive_opts}"
    fi
    qemu_args+=("-drive" "$main_hdd_drive")
    
    # Add shared drive with performance options
    echo "Shared HDD: $QEMU_SHARED_HDD"
    local shared_hdd_drive="file=$QEMU_SHARED_HDD,format=raw,media=disk"
    if [ -n "$drive_opts" ]; then
        shared_hdd_drive="${shared_hdd_drive},${drive_opts}"
    fi
    qemu_args+=("-drive" "$shared_hdd_drive")
    
    # Add additional HDD if specified via -a flag
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE"
        local additional_hdd_drive="file=$ADDITIONAL_HDD_FILE,format=raw,media=disk"
        if [ -n "$drive_opts" ]; then
            additional_hdd_drive="${additional_hdd_drive},${drive_opts}"
        fi
        qemu_args+=("-drive" "$additional_hdd_drive")
    fi
    
    # --- Audio settings ---
    # Add audio backend first, then link sound device to it
    if [ -n "$QEMU_AUDIO_BACKEND" ]; then
        local audio_opts="driver=${QEMU_AUDIO_BACKEND}"
        if [ -n "$QEMU_AUDIO_LATENCY" ]; then
            audio_opts="${audio_opts},timer-period=${QEMU_AUDIO_LATENCY}"
        fi
        qemu_args+=("-audiodev" "$audio_opts,id=audio0")
        
        # Add sound device linked to the audio backend
        if [ -n "$QEMU_SOUND_DEVICE" ]; then
            qemu_args+=("-device" "$QEMU_SOUND_DEVICE,audiodev=audio0")
        fi
    fi
    
    # --- USB support ---
    if [ "$QEMU_USB_ENABLED" = "true" ]; then
        qemu_args+=("-usb")
    fi
    
    echo "Display: $DISPLAY_TYPE"
    echo "Performance: CPU=$QEMU_CPU, SMP=$QEMU_SMP_CORES, TCG=$QEMU_TCG_THREAD_MODE, TB=$QEMU_TB_SIZE"
    echo "Storage: Cache=$QEMU_IDE_CACHE_MODE, AIO=$QEMU_IDE_AIO_MODE"
    echo "Generated QEMU command: qemu-system-ppc ${qemu_args[*]}"
    echo "-------------------------------------------------------"
}

#######################################
# Run the QEMU emulation
# Arguments:
#   None
# Globals:
#   Various configuration and command variables
# Returns:
#   None
# Exits:
#   QEMU's exit code
#######################################
run_emulation() {
    echo "--- Starting PowerPC Mac Emulation ---"
    echo "Configuration: $CONFIG_NAME"
    echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M"
    echo "OS HDD: $QEMU_HDD"
    echo "Shared HDD: $QEMU_SHARED_HDD"
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE"
    fi
    
    # Execute QEMU using the secure array
    echo "--- Starting QEMU PowerPC ---"
    echo "QEMU command: qemu-system-ppc ${qemu_args[*]}"
    debug_log "QEMU command: qemu-system-ppc ${qemu_args[*]}"
    
    qemu-system-ppc "${qemu_args[@]}"
    
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "QEMU exited with error code: $exit_code" >&2
        echo "Check QEMU output for specific error messages." >&2
    else
        echo "QEMU session ended normally."
    fi
    
    # The trap (if set for TAP mode) will execute cleanup automatically
    exit $exit_code
}

#######################################
# Main script execution
# Arguments:
#   All command line arguments
# Globals:
#   Various script variables
# Returns:
#   None
# Exits:
#   Various exit codes depending on failure points
#######################################
main() {
    # Check QEMU version compatibility
    check_qemu_version "$REQUIRED_QEMU_VERSION"
    
    # Check dependencies
    local missing_deps=()
    
    # Check essential commands for PowerPC emulation
    if ! command -v qemu-system-ppc &> /dev/null; then
        missing_deps+=("qemu-system-ppc")
    fi
    if ! command -v qemu-img &> /dev/null; then
        missing_deps+=("qemu-img") 
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
        echo "Please install them using the dependency installer:" >&2
        echo "  ./install-dependencies.sh" >&2
        exit 1
    fi
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Load and validate configuration
    load_and_validate_ppc_config "$CONFIG_FILE" "$NETWORK_TYPE"
    
    # Validate essential files exist
    if [ -n "$CD_FILE" ]; then
        validate_file_exists "$CD_FILE" "CD-ROM image file" || exit 1
    fi
    
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        validate_file_exists "$ADDITIONAL_HDD_FILE" "Additional hard drive image file" || exit 1
    fi
    
    # Determine display type if not specified
    if [ -z "$DISPLAY_TYPE" ]; then
        DISPLAY_TYPE=$(determine_display_type "")
    fi
    
    # Prepare disk images (create if missing)
    prepare_disk_images
    
    # Build the QEMU command
    build_qemu_command
    
    # Run the emulation
    run_emulation
}

# Execute main function with all arguments
main "$@"