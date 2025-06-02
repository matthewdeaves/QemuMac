#!/usr/bin/env bash

#######################################
# QEMU Mac OS Emulation Runner
# Main script to run Mac OS emulation using QEMU with configuration files
# Supports TAP/Bridge, User Mode (with optional SMB), and Passt networking.
# Controls MacOS boot order via PRAM modification.
# Allows attaching an additional user-specified hard drive.
#######################################

# Source shared utilities and modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-utils.sh
source "$SCRIPT_DIR/qemu-utils.sh"
# shellcheck source=qemu-config.sh
source "$SCRIPT_DIR/qemu-config.sh"
# shellcheck source=qemu-storage.sh
source "$SCRIPT_DIR/qemu-storage.sh"
# shellcheck source=qemu-networking.sh
source "$SCRIPT_DIR/qemu-networking.sh"
# shellcheck source=qemu-display.sh
source "$SCRIPT_DIR/qemu-display.sh"

# --- Script Constants ---
readonly REQUIRED_QEMU_VERSION="4.0"
readonly TAP_FUNCTIONS_SCRIPT="$SCRIPT_DIR/qemu-tap-functions.sh"

# --- Configuration Variables (loaded from .conf file) ---
CONFIG_NAME=""
QEMU_MACHINE=""
QEMU_RAM=""
QEMU_ROM=""
QEMU_HDD=""
QEMU_SHARED_HDD=""
QEMU_SHARED_HDD_SIZE=""
QEMU_GRAPHICS=""
QEMU_CPU=""
QEMU_HDD_SIZE=""
QEMU_PRAM=""
BRIDGE_NAME=""
QEMU_TAP_IFACE=""
QEMU_MAC_ADDR=""
QEMU_USER_SMB_DIR=""
QEMU_AUDIO_BACKEND=""
QEMU_AUDIO_LATENCY=""
QEMU_ASC_MODE=""
QEMU_CPU_MODEL=""
QEMU_TCG_THREAD_MODE=""
QEMU_TB_SIZE=""
QEMU_MEMORY_BACKEND=""

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
    echo "  -C FILE  Specify configuration file (e.g., sys755-q800.conf)"
    echo "           The config file defines machine, RAM, ROM, disks, PRAM, graphics, audio,"
    echo "           and optionally BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR (for TAP),"
    echo "           QEMU_USER_SMB_DIR (for User mode SMB share), QEMU_AUDIO_BACKEND,"
    echo "           QEMU_AUDIO_LATENCY, and QEMU_ASC_MODE (for audio configuration)."
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file (if not specified, no CD will be attached)"
    echo "  -a FILE  Specify an additional hard drive image file (e.g., mydrive.hda or mydrive.img)"
    echo "  -b       Boot from CD-ROM (requires -c option, modifies PRAM)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -N TYPE  Specify network type: 'tap' (Linux default), 'user' (macOS default, NAT), or 'passt' (slirp alternative)"
    echo "  -D       Enable debug mode (set -x, show PRAM before launch)"
    echo "  -B       Enable boot debug mode (show detailed PRAM analysis)"
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
    while getopts "C:c:a:bd:N:DB?" opt; do
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
                BOOT_DEBUG=true
                debug_log "Debug mode enabled"
                set -x
                ;;
            B) 
                BOOT_DEBUG=true
                debug_log "Boot debug mode enabled"
                ;;
            \?|*) 
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
# Build the QEMU command line arguments with secure array construction
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
    
    # Set audio defaults if not specified
    local audio_backend="${QEMU_AUDIO_BACKEND:-$DEFAULT_AUDIO_BACKEND}"
    local audio_latency="${QEMU_AUDIO_LATENCY:-$DEFAULT_AUDIO_LATENCY}"
    local asc_mode="${QEMU_ASC_MODE:-$DEFAULT_ASC_MODE}"
    
    # Validate audio configuration
    validate_audio_backend "$audio_backend" || exit 1
    validate_asc_mode "$asc_mode" || exit 1
    
    # Build machine parameters with audio and ASC configuration
    local machine_params="$QEMU_MACHINE"
    if [ "$asc_mode" = "asc" ]; then
        machine_params="$machine_params,easc=off"
    else
        machine_params="$machine_params,easc=on"
    fi
    
    # Add audio configuration to machine params if not disabled
    if [ "$audio_backend" != "none" ]; then
        machine_params="$machine_params,audiodev=audio0"
    fi
    
    # Base arguments with proper quoting
    qemu_args+=(
        "-M" "$machine_params"
        "-m" "$QEMU_RAM"
        "-bios" "$QEMU_ROM"
        "-display" "$DISPLAY_TYPE"
        "-g" "$QEMU_GRAPHICS"
        "-drive" "file=$QEMU_PRAM,format=raw,if=mtd"
    )
    
    # Add audio device configuration if not disabled
    if [ "$audio_backend" != "none" ]; then
        qemu_args+=("-audiodev" "$audio_backend,id=audio0,in.latency=$audio_latency,out.latency=$audio_latency")
    fi
    
    # Add CPU if specified in config (optional)
    if [ -n "${QEMU_CPU:-}" ]; then
        qemu_args+=("-cpu" "$QEMU_CPU")
    fi
    
    # Add performance optimizations
    local cpu_model="${QEMU_CPU_MODEL:-}"
    local tcg_thread_mode="${QEMU_TCG_THREAD_MODE:-}"
    local tb_size="${QEMU_TB_SIZE:-}"
    local memory_backend="${QEMU_MEMORY_BACKEND:-}"
    
    # Validate performance configuration
    validate_cpu_model "$cpu_model" || exit 1
    validate_tcg_thread_mode "$tcg_thread_mode" || exit 1
    validate_tb_size "$tb_size" || exit 1
    validate_memory_backend "$memory_backend" || exit 1
    
    # Add explicit CPU model if specified
    if [ -n "$cpu_model" ]; then
        qemu_args+=("-cpu" "$cpu_model")
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
    
    # Add memory backend optimization if specified
    if [ -n "$memory_backend" ]; then
        qemu_args+=(
            "-object" "memory-backend-$memory_backend,size=${QEMU_RAM}M,id=ram0"
            "-machine" "memory-backend=ram0"
        )
    fi
    
    # Add network arguments using the networking module
    build_network_args "$NETWORK_TYPE" qemu_args
    
    # --- Add hard disks and CD-ROM ---
    # Boot order is controlled by PRAM for MacOS, bootindex is ignored by firmware.
    # SCSI IDs: 0=OS, 1=Shared, 2=CDROM, 3=Additional HDD
    
    # OS HDD (SCSI ID 0)
    qemu_args+=(
        "-device" "scsi-hd,scsi-id=0,drive=hd0,vendor=SEAGATE,product=QEMU_OS_DISK"
        "-drive" "file=$QEMU_HDD,media=disk,format=raw,if=none,id=hd0"
    )
    
    # Shared HDD (SCSI ID 1)
    qemu_args+=(
        "-device" "scsi-hd,scsi-id=1,drive=hd1,vendor=SEAGATE,product=QEMU_SHARED"
        "-drive" "file=$QEMU_SHARED_HDD,media=disk,format=raw,if=none,id=hd1"
    )
    
    # CD-ROM (SCSI ID 2) - Attach if specified
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE (as SCSI ID 2)"
        qemu_args+=(
            "-device" "scsi-cd,scsi-id=2,drive=cd0"
            "-drive" "file=$CD_FILE,format=raw,media=cdrom,if=none,id=cd0"
        )
    else
        echo "No CD-ROM specified"
    fi
    
    # Additional HDD (SCSI ID 3) - Attach if specified via -a flag
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE (as SCSI ID 3)"
        qemu_args+=(
            "-device" "scsi-hd,scsi-id=3,drive=hd_add,vendor=SEAGATE,product=QEMU_ADD_DISK"
            "-drive" "file=$ADDITIONAL_HDD_FILE,media=disk,format=raw,if=none,id=hd_add"
        )
    fi
    
    echo "Display: $DISPLAY_TYPE"
    echo "Audio: $audio_backend (ASC: $asc_mode, Latency: ${audio_latency}μs)"
    echo "--------------------------"
}

#######################################
# Run the QEMU emulation with comprehensive error handling
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
    echo "--- Starting Emulation ---"
    echo "Configuration: $CONFIG_NAME"
    echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M, ROM: $QEMU_ROM"
    echo "OS HDD: $QEMU_HDD"
    echo "Shared HDD: $QEMU_SHARED_HDD"
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE"
    fi
    echo "PRAM: $QEMU_PRAM"
    
    # --- DEBUG: Inspect PRAM before launch (Conditional) ---
    if [ "$DEBUG_MODE" = true ]; then
        echo "--- Pausing before QEMU launch (DEBUG MODE). Check PRAM now. ---"
        echo "Checking PRAM file: $QEMU_PRAM"
        echo "Bytes at offset 122 (0x7A):"
        hexdump -C -s 122 -n 2 "$QEMU_PRAM"
        read -r -p "Press Enter to continue and launch QEMU..."
    fi
    # --- END DEBUG ---
    
    # Execute QEMU using the secure array
    echo "--- Starting QEMU ---"
    debug_log "QEMU command: qemu-system-m68k ${qemu_args[*]}"
    
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
    
    # Check dependencies and offer installation if missing
    local missing_deps=()
    
    # Check essential commands
    if ! command -v qemu-system-m68k &> /dev/null; then
        missing_deps+=("qemu-system-m68k")
    fi
    if ! command -v qemu-img &> /dev/null; then
        missing_deps+=("qemu-img") 
    fi
    if ! command -v dd &> /dev/null; then
        missing_deps+=("coreutils")
    fi
    if ! command -v hexdump &> /dev/null; then
        missing_deps+=("bsdmainutils")
    fi
    
    # If core dependencies missing, offer installation
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing core dependencies: ${missing_deps[*]}"
        echo ""
        echo "You can install all dependencies by running:"
        echo "  ./install-dependencies.sh"
        echo ""
        echo "Or install them manually. Run './install-dependencies.sh --check' to see what's needed."
        echo ""
        echo "Continue anyway? [y/N]"
        read -r response
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled. Please install dependencies first."
            exit 1
        fi
        
        # Still do individual checks for better error messages
        check_command "qemu-system-m68k" "qemu-system-m68k package" || exit 1
        check_command "qemu-img" "qemu-utils package" || exit 1
        check_command "dd" "coreutils package" || exit 1
        check_command "printf" "coreutils package" || exit 1
        check_command "hexdump" "bsdmainutils package" || exit 1
    fi
    
    # Parse arguments first to enable debug mode early if requested
    parse_arguments "$@"
    
    # Load and validate configuration
    load_and_validate_config "$CONFIG_FILE" "$NETWORK_TYPE"
    
    # Validate additional files if specified
    if [ -n "$CD_FILE" ]; then
        validate_file_exists "$CD_FILE" "CD-ROM image file" || exit 1
    fi
    validate_additional_hdd "$ADDITIONAL_HDD_FILE"
    
    # Prepare storage
    prepare_config_disk_images
    
    # Set boot order in PRAM
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        set_pram_boot_order "cdrom"
    elif [ "$BOOT_FROM_CD" = true ] && [ -z "$CD_FILE" ]; then
        warning_log "-b specified but no CD image provided with -c. Setting PRAM to HDD boot."
        set_pram_boot_order "hdd"
    else
        # Default boot is from HDD
        set_pram_boot_order "hdd"
    fi
    
    # Determine display type
    DISPLAY_TYPE=$(determine_display_type "$DISPLAY_TYPE")
    
    # Setup networking
    setup_networking "$NETWORK_TYPE"
    
    # Build QEMU command
    build_qemu_command
    
    # Run emulation
    run_emulation
}

# --- Script Entry Point ---
main "$@"