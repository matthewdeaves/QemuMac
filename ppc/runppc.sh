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
# Auto-detect network type based on OS (TAP requires Linux, User mode for macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    NETWORK_TYPE="user"  # Default to user mode on macOS (TAP requires Linux tools)
else
    NETWORK_TYPE="tap"   # Default to TAP on Linux
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
    local hdd_size="${QEMU_HDD_SIZE:-2G}"
    local shared_size="${QEMU_SHARED_HDD_SIZE:-200M}"
    
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
        echo "Empty PowerPC OS hard disk image created. Proceeding with boot likely from CD for install."
        echo "Note: Format this drive with Mac OS Disk Utility during installation."
    fi
    
    # Create shared disk image if it doesn't exist
    if [ ! -f "$QEMU_SHARED_HDD" ]; then
        info_log "PowerPC shared disk image '$QEMU_SHARED_HDD' not found. Creating ${shared_size}..."
        qemu-img create -f raw "$QEMU_SHARED_HDD" "$shared_size"
        check_exit_status $? "Failed to create PowerPC shared disk image '$QEMU_SHARED_HDD'"
        echo "Empty PowerPC shared disk image created. Format it within the emulator."
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
    
    # Set defaults if not specified
    local audio_backend="${QEMU_AUDIO_BACKEND:-pa}"
    local audio_latency="${QEMU_AUDIO_LATENCY:-50000}"
    local sound_device="${QEMU_SOUND_DEVICE:-es1370}"
    local tcg_thread_mode="${QEMU_TCG_THREAD_MODE:-single}"
    local tb_size="${QEMU_TB_SIZE:-256}"
    local ide_cache_mode="${QEMU_IDE_CACHE_MODE:-writethrough}"
    local ide_aio_mode="${QEMU_IDE_AIO_MODE:-threads}"
    local usb_enabled="${QEMU_USB_ENABLED:-false}"
    
    # Base arguments - PPC uses -L pc-bios instead of ROM file
    qemu_args+=(
        "-L" "pc-bios"
        "-M" "$QEMU_MACHINE"
        "-m" "$QEMU_RAM"
        "-display" "$DISPLAY_TYPE"
        "-g" "$QEMU_GRAPHICS"
    )
    
    # Add boot order - PPC uses simple -boot flag instead of PRAM
    if [ "$BOOT_FROM_CD" = true ]; then
        qemu_args+=("-boot" "d")  # Boot from CD-ROM
    else
        qemu_args+=("-boot" "c")  # Boot from hard disk
    fi
    
    # Add audio configuration if not disabled
    if [ "$audio_backend" != "none" ]; then
        qemu_args+=("-audiodev" "$audio_backend,id=audio0,in.latency=$audio_latency,out.latency=$audio_latency")
        qemu_args+=("-device" "$sound_device,audiodev=audio0")
    fi
    
    # Add CPU if specified in config (optional)
    if [ -n "${QEMU_CPU:-}" ]; then
        qemu_args+=("-cpu" "$QEMU_CPU")
    fi
    
    # Add TCG optimizations if specified
    if [ -n "$tcg_thread_mode" ] || [ -n "$tb_size" ]; then
        local tcg_opts="tcg"
        if [ -n "$tcg_thread_mode" ]; then
            tcg_opts="$tcg_opts,thread=$tcg_thread_mode"
        fi
        if [ -n "$tb_size" ]; then
            tcg_opts="$tcg_opts,tb-size=$tb_size"
        fi
        qemu_args+=("-accel" "$tcg_opts")
    fi
    
    # Add network arguments using the shared networking module
    build_network_args "$NETWORK_TYPE" qemu_args
    
    # Build drive cache parameters
    local drive_cache_params="cache=$ide_cache_mode,aio=$ide_aio_mode"
    if [ "$ide_aio_mode" = "native" ]; then
        drive_cache_params="$drive_cache_params,cache.direct=on"
    fi
    
    # --- Add drives using IDE channels (simpler than 68k SCSI) ---
    # IDE Channel assignment for PowerPC Macs:
    # Primary Master (index=0): OS hard drive OR CD-ROM (when booting from CD)
    # Primary Slave (index=1): CD-ROM OR OS hard drive (when booting from CD)  
    # Secondary Master (index=2): Shared hard drive
    # Secondary Slave (index=3): Additional hard drive (when specified)
    
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        # When booting from CD, put CD on primary master for boot priority
        echo "CD-ROM: $CD_FILE as Primary Master for boot"
        qemu_args+=("-drive" "file=$CD_FILE,format=raw,media=cdrom,if=ide,index=0,id=cd0")
        # Put OS drive on primary slave when booting from CD
        qemu_args+=("-drive" "file=$QEMU_HDD,media=disk,format=raw,if=ide,index=1,id=hd0,$drive_cache_params")
    else
        # Normal operation - OS drive on primary master
        qemu_args+=("-drive" "file=$QEMU_HDD,media=disk,format=raw,if=ide,index=0,id=hd0,$drive_cache_params")
        
        # CD-ROM on primary slave if specified
        if [ -n "$CD_FILE" ]; then
            echo "CD-ROM: $CD_FILE as Primary Slave"
            qemu_args+=("-drive" "file=$CD_FILE,format=raw,media=cdrom,if=ide,index=1,id=cd0")
        else
            echo "No CD-ROM specified"
        fi
    fi
    
    # Secondary Master - Shared HDD
    qemu_args+=("-drive" "file=$QEMU_SHARED_HDD,media=disk,format=raw,if=ide,index=2,id=hd1,$drive_cache_params")
    
    # Secondary Slave - Additional HDD if specified via -a flag
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE as Secondary Slave"
        qemu_args+=("-drive" "file=$ADDITIONAL_HDD_FILE,media=disk,format=raw,if=ide,index=3,id=hd_add,$drive_cache_params")
    fi
    
    # Add USB support if enabled (for Mac OS X)
    if [ "$usb_enabled" = "true" ]; then
        info_log "Adding USB support for Mac OS X"
        qemu_args+=(
            "-device" "pci-ohci,id=ohci"
            "-device" "usb-kbd,bus=ohci.0"
            "-device" "usb-mouse,bus=ohci.0"
        )
    fi
    
    echo "Display: $DISPLAY_TYPE Resolution: $QEMU_GRAPHICS"
    echo "Audio: $audio_backend Device: $sound_device, Latency: ${audio_latency}μs"
    echo "Storage: IDE Cache: $ide_cache_mode, AIO: $ide_aio_mode"
    echo "--------------------------"
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