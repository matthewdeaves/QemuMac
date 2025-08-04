#!/usr/bin/env bash

#######################################
# Unified Mac Emulation Runner
# Single script to run both 68k and PowerPC Mac emulation using QEMU
# Auto-detects architecture from config file and handles all emulation logic
# Uses user-mode networking for simple, out-of-the-box connectivity
#######################################

set -euo pipefail

# Source shared utilities and modules
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/qemu-utils.sh
source "$SCRIPT_DIR/scripts/qemu-utils.sh"
# shellcheck source=scripts/qemu-common.sh
source "$SCRIPT_DIR/scripts/qemu-common.sh"

# --- Script Constants ---
readonly REQUIRED_QEMU_VERSION="4.0"

# --- Configuration Variables (loaded from .conf file) ---
CONFIG_NAME=""
ARCH=""
QEMU_MACHINE=""
QEMU_RAM=""
QEMU_ROM=""
QEMU_HDD=""
QEMU_SHARED_HDD=""
QEMU_SHARED_HDD_SIZE=""
QEMU_GRAPHICS=""
QEMU_CPU=""
QEMU_SMP_CORES=""
QEMU_HDD_SIZE=""
QEMU_PRAM=""
QEMU_AUDIO_BACKEND=""
QEMU_AUDIO_LATENCY=""
QEMU_ASC_MODE=""
QEMU_SOUND_DEVICE=""
QEMU_CPU_MODEL=""
QEMU_TCG_THREAD_MODE=""
QEMU_TB_SIZE=""
QEMU_MEMORY_BACKEND=""
QEMU_SCSI_CACHE_MODE=""
QEMU_SCSI_AIO_MODE=""
QEMU_SCSI_VENDOR=""
QEMU_SCSI_SERIAL_PREFIX=""
QEMU_IDE_CACHE_MODE=""
QEMU_IDE_AIO_MODE=""
QEMU_DISPLAY_DEVICE=""
QEMU_RESOLUTION_PRESET=""
QEMU_FLOPPY_IMAGE=""
QEMU_FLOPPY_READONLY=""
QEMU_FLOPPY_FORMAT=""
QEMU_USB_ENABLED=""
QEMU_NETWORK_DEVICE=""

# --- Script Variables ---
CONFIG_FILE=""
CD_FILE=""
ADDITIONAL_HDD_FILE=""
BOOT_FROM_CD=false
DISPLAY_TYPE=""
DEBUG_MODE=false

#######################################
# Display help information
# Arguments:
#   None
# Returns:
#   None
# Exits:
#   1 (help display always exits)
#######################################
show_help() {
    echo "Unified Mac Emulation Runner"
    echo ""
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo ""
    echo "Auto-detects architecture from config file and runs appropriate emulation:"
    echo "  ARCH=\"m68k\" -> 68k Macintosh emulation (Mac OS 7.x)"
    echo "  ARCH=\"ppc\"  -> PowerPC Macintosh emulation (Mac OS 9.x/X)"
    echo ""
    echo "Required:"
    echo "  -C FILE  Specify configuration file"
    echo ""
    echo "Options:"
    echo "  -c FILE  Specify CD-ROM image file"
    echo "  -a FILE  Specify additional hard drive image file"
    echo "  -b       Boot from CD-ROM (for OS installation)"
    echo "  -d TYPE  Force display type (sdl, gtk, cocoa)"
    echo "  -D       Enable debug mode (set -x)"
    echo "  -?       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -C m68k/configs/m68k-macos753.conf"
    echo "  $0 -C ppc/configs/ppc-macos91.conf -c install.iso -b"
    echo "  $0 -C ppc/configs/ppc-osxtiger104.conf"
    echo ""
    echo "Networking: Uses user-mode for simple, out-of-the-box networking."
    exit 1
}

#######################################
# Extract architecture from config file
# Arguments:
#   config_file: Path to configuration file
# Returns:
#   Prints architecture (m68k or ppc) to stdout
# Exits:
#   1 if config file not found or ARCH not defined
#######################################
get_architecture_from_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file '$config_file' not found." >&2
        exit 1
    fi
    
    # Extract ARCH variable from config file
    local arch
    arch=$(grep "^ARCH=" "$config_file" 2>/dev/null | cut -d'"' -f2)
    
    if [ -z "$arch" ]; then
        echo "Error: ARCH variable not found in config file '$config_file'." >&2
        echo "Config files must define ARCH=\"m68k\" or ARCH=\"ppc\"." >&2
        exit 1
    fi
    
    echo "$arch"
}

#######################################
# Parse command-line arguments
# Arguments:
#   All command line arguments
# Globals:
#   CONFIG_FILE, CD_FILE, ADDITIONAL_HDD_FILE, BOOT_FROM_CD
#   DISPLAY_TYPE, DEBUG_MODE
# Returns:
#   None
# Exits:
#   1 if invalid arguments provided
#######################################
parse_arguments() {
    while getopts "C:c:a:bd:D?" opt; do
        case $opt in
            C) 
                CONFIG_FILE="$OPTARG"
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
    
    # Check if help was requested or no config provided
    if [ "$#" -eq 0 ] || [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-?" ]]; then
        show_help
    fi
    
    # Validate required arguments
    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: No configuration file specified. Use -C <config_file.conf>" >&2
        show_help
    fi
    
    debug_log "Arguments parsed successfully"
    debug_log "Config: $CONFIG_FILE, Display: ${DISPLAY_TYPE:-auto}"
}

#######################################
# Load and validate configuration
# Arguments:
#   config_file: Path to configuration file
# Globals:
#   Sources all configuration variables
# Returns:
#   None
# Exits:
#   1 if configuration loading or validation fails
#######################################
load_and_validate_config() {
    local config_file="$1"
    
    validate_file_exists "$config_file" "Configuration file" || exit 1
    
    echo "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file"
    check_exit_status $? "Failed to source configuration file '$config_file'"
    
    # Extract config name for potential use
    CONFIG_NAME=$(basename "$config_file" .conf)
    
    # Validate required variables based on architecture
    local missing_vars=()
    
    if [ "$ARCH" = "m68k" ]; then
        # 68k-specific required variables
        local -A REQUIRED_VARS=(
            ["QEMU_MACHINE"]="QEMU machine type (e.g., q800)"
            ["QEMU_ROM"]="ROM file path"
            ["QEMU_HDD"]="Hard disk image path"
            ["QEMU_SHARED_HDD"]="Shared disk image path"
            ["QEMU_RAM"]="RAM amount in MB"
            ["QEMU_GRAPHICS"]="Graphics settings (e.g., 1152x870x8)"
            ["QEMU_PRAM"]="PRAM file path"
        )
        
        # Validate ROM file exists for 68k
        if [ -n "${QEMU_ROM:-}" ]; then
            validate_file_exists "$QEMU_ROM" "ROM file" || exit 1
        fi
        
    elif [ "$ARCH" = "ppc" ]; then
        # PowerPC-specific required variables (no ROM/PRAM needed)
        local -A REQUIRED_VARS=(
            ["QEMU_MACHINE"]="QEMU machine type (e.g., mac99,via=pmu)"
            ["QEMU_HDD"]="Hard disk image path"
            ["QEMU_SHARED_HDD"]="Shared disk image path"
            ["QEMU_RAM"]="RAM amount in MB"
            ["QEMU_GRAPHICS"]="Graphics settings (e.g., 1024x768x8)"
        )
        
    else
        echo "Error: Invalid architecture '$ARCH'. Supported: m68k, ppc" >&2
        exit 1
    fi
    
    # Check required variables
    for var in "${!REQUIRED_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var (${REQUIRED_VARS[$var]})")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "Error: Config file $config_file is missing required variables:" >&2
        printf "  - %s\\n" "${missing_vars[@]}" >&2
        exit 1
    fi
    
    # Set defaults for optional variables
    QEMU_HDD_SIZE="${QEMU_HDD_SIZE:-15G}"
    QEMU_SHARED_HDD_SIZE="${QEMU_SHARED_HDD_SIZE:-1G}"
    
    debug_log "Configuration loaded and validated successfully"
    debug_log "Config name: ${CONFIG_NAME:-unknown}"
    debug_log "Architecture: $ARCH"
    debug_log "Machine: ${QEMU_MACHINE:-unknown}, RAM: ${QEMU_RAM:-unknown}MB"
}

#######################################
# Determine display type based on system
# Arguments:
#   display_type_override: Optional display type override (can be empty)
# Returns:
#   Display type via stdout
#######################################
determine_display_type() {
    local display_type_override="$1"
    
    if [ -n "$display_type_override" ]; then
        echo "$display_type_override"
        return 0
    fi
    
    # Auto-detect based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info_log "Detected macOS, using 'cocoa' display. Use -d to override."
        echo "cocoa"
    else
        info_log "Defaulting to 'sdl' display on this system. Use -d to override (e.g., -d gtk)."
        echo "sdl"
    fi
}

#######################################
# Setup networking
# Arguments:
#   None
# Returns:
#   None
#######################################
setup_networking() {
    info_log "User Mode networking enabled. No host-side setup or cleanup needed."
}

#######################################
# Build network arguments for QEMU command
# Arguments:
#   qemu_args_var: Name of array variable to append to
# Returns:
#   None (modifies array via nameref)
#######################################
build_network_args() {
    local -n qemu_args_ref=$1

    # Determine network device model
    local network_device
    if [ -n "${QEMU_NETWORK_DEVICE:-}" ]; then
        network_device="$QEMU_NETWORK_DEVICE"
    elif [ "$ARCH" = "ppc" ]; then
        # For PowerPC, virtio-net is a good default
        network_device="virtio-net"
    else
        # For 68k, use dp83932 which is a common choice for older systems
        network_device="dp83932"
    fi

    echo "Network: User-mode networking, Device: $network_device"
    qemu_args_ref+=(
        "-net"
        "nic,model=${network_device}"
        "-net"
        "user"
    )
}

#######################################
# Prepare disk images if they don't exist (create empty images)
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
        info_log "OS hard disk image '$QEMU_HDD' not found. Creating ${hdd_size}..."
        qemu-img create -f raw "$QEMU_HDD" "$hdd_size"
        check_exit_status $? "Failed to create OS hard disk image '$QEMU_HDD'"
        echo "Empty OS hard disk image created (${hdd_size}). Proceeding with boot likely from CD for install."
        echo "Note: Format this drive with Mac OS Disk Utility during installation."
    fi
    
    # Create shared disk image if it doesn't exist
    if [ ! -f "$QEMU_SHARED_HDD" ]; then
        info_log "Shared disk image '$QEMU_SHARED_HDD' not found. Creating ${shared_size}..."
        qemu-img create -f raw "$QEMU_SHARED_HDD" "$shared_size"
        check_exit_status $? "Failed to create shared disk image '$QEMU_SHARED_HDD'"
        echo "Empty shared disk image created (${shared_size}). Format it within the emulator."
        echo "To share files with the VM - Linux example:"
        echo "  1. Format as HFS+ in Mac OS first"
        echo "  2. sudo mount -t hfsplus -o loop \"$QEMU_SHARED_HDD\" /mnt"
        echo "  3. Copy files"
        echo "  4. sudo umount /mnt"
        echo "Note: Install hfsprogs package for HFS+ support on Linux host"
    fi
    
    # Create PRAM image for 68k if needed
    if [ "$ARCH" = "m68k" ] && [ ! -s "$QEMU_PRAM" ]; then
        local pram_dir
        pram_dir=$(dirname "$QEMU_PRAM")
        
        if [ ! -d "$pram_dir" ]; then
            echo "Creating PRAM directory: $pram_dir"
            mkdir -p "$pram_dir"
            check_exit_status $? "Failed to create PRAM directory '$pram_dir'"
        fi
        
        echo "Creating new PRAM image file: $QEMU_PRAM"
        dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1 status=none
        check_exit_status $? "Failed to create PRAM image '$QEMU_PRAM'"
        
        info_log "PRAM image created successfully"
    elif [ "$ARCH" = "m68k" ]; then
        debug_log "PRAM image already exists: $QEMU_PRAM"
    fi
    
    info_log "All disk images prepared successfully"
}

#######################################
# Build QEMU command line arguments for 68k architecture
# Arguments:
#   None
# Globals:
#   Various QEMU configuration variables
# Returns:
#   Sets qemu_args array
#######################################
build_68k_qemu_command() {
    # Initialize the array
    qemu_args=()
    
    # Set audio defaults
    local audio_backend="${QEMU_AUDIO_BACKEND:-$DEFAULT_AUDIO_BACKEND}"
    local audio_latency="${QEMU_AUDIO_LATENCY:-$DEFAULT_AUDIO_LATENCY}"
    local asc_mode="${QEMU_ASC_MODE:-$DEFAULT_ASC_MODE}"
    
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
    
    # Base arguments
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
    
    # Add explicit CPU model if specified
    if [ -n "$cpu_model" ]; then
        qemu_args+=("-cpu" "$cpu_model")
    fi
    
    # Add TCG optimizations if specified
    if [ -n "$tcg_thread_mode" ] || [ -n "$tb_size" ]; then
        local tcg_opts
        tcg_opts=$(build_tcg_acceleration "$tcg_thread_mode" "$tb_size")
        qemu_args+=("-accel" "$tcg_opts")
    fi
    
    # Add memory backend optimization if specified
    if [ -n "$memory_backend" ]; then
        local memory_opts
        memory_opts=$(build_memory_backend "$memory_backend" "$QEMU_RAM")
        if [ -n "$memory_opts" ]; then
            qemu_args+=($memory_opts)
        fi
    fi
    
    # Add network arguments
    build_network_args qemu_args
    
    # Add SCSI configuration variables with defaults
    local scsi_cache_mode="${QEMU_SCSI_CACHE_MODE:-$DEFAULT_SCSI_CACHE_MODE}"
    local scsi_aio_mode="${QEMU_SCSI_AIO_MODE:-$DEFAULT_SCSI_AIO_MODE}"
    local scsi_vendor="${QEMU_SCSI_VENDOR:-$DEFAULT_SCSI_VENDOR}"
    local scsi_serial_prefix="${QEMU_SCSI_SERIAL_PREFIX:-$DEFAULT_SCSI_SERIAL_PREFIX}"
    
    # Add display configuration variables with defaults
    local display_device="${QEMU_DISPLAY_DEVICE:-$DEFAULT_DISPLAY_DEVICE}"
    local resolution_preset="${QEMU_RESOLUTION_PRESET:-$DEFAULT_RESOLUTION_PRESET}"
    
    # Override QEMU_GRAPHICS if resolution preset is specified and differs from default
    if [ "$resolution_preset" != "$DEFAULT_RESOLUTION_PRESET" ]; then
        local preset_resolution
        case "$resolution_preset" in
            "mac_standard") preset_resolution="1152x870x8" ;;
            "vga") preset_resolution="640x480x8" ;;
            "svga") preset_resolution="800x600x8" ;;
            "xga") preset_resolution="1024x768x8" ;;
            "sxga") preset_resolution="1280x1024x8" ;;
            *) preset_resolution="$QEMU_GRAPHICS" ;;
        esac
        
        if [ "$preset_resolution" != "$QEMU_GRAPHICS" ]; then
            QEMU_GRAPHICS="$preset_resolution"
            info_log "Using resolution from preset '$resolution_preset': $QEMU_GRAPHICS"
        fi
    fi
    
    # Add floppy configuration variables with defaults
    local floppy_image="${QEMU_FLOPPY_IMAGE:-}"
    local floppy_readonly="${QEMU_FLOPPY_READONLY:-$DEFAULT_FLOPPY_READONLY}"
    local floppy_format="${QEMU_FLOPPY_FORMAT:-$DEFAULT_FLOPPY_FORMAT}"
    
    # Basic floppy file validation if specified
    if [ -n "$floppy_image" ] && [ ! -f "$floppy_image" ]; then
        echo "Error: Floppy image file '$floppy_image' not found" >&2
        exit 1
    fi
    
    # --- Add hard disks and CD-ROM ---
    # Static SCSI ID assignment. OS HDD must be highest for drives to mount correctly.
    # In install mode, we swap the IDs to boot from the CD.
    # SCSI IDs: 6=OS, 5=Shared, 4=Additional HDD, 3=CDROM
    
    local hdd_scsi_id=6
    local cdrom_scsi_id=3
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        hdd_scsi_id=0
        cdrom_scsi_id=6
    fi

    # OS HDD (SCSI ID 6)
    local drive_cache_params
    drive_cache_params=$(build_drive_cache_params "$scsi_cache_mode" "$scsi_aio_mode")
    qemu_args+=(
        "-device" "scsi-hd,bus=scsi.0,scsi-id=${hdd_scsi_id},drive=hd0,vendor=$scsi_vendor,product=QEMU_OS_DISK,serial=${scsi_serial_prefix}001"
        "-drive" "file=$QEMU_HDD,media=disk,format=raw,if=none,id=hd0,$drive_cache_params"
    )
    
    # Shared HDD (SCSI ID 5)
    qemu_args+=(
        "-device" "scsi-hd,bus=scsi.0,scsi-id=5,drive=hd1,vendor=$scsi_vendor,product=QEMU_SHARED,serial=${scsi_serial_prefix}002"
        "-drive" "file=$QEMU_SHARED_HDD,media=disk,format=raw,if=none,id=hd1,$drive_cache_params"
    )
    
    # CD-ROM (SCSI ID 3) - Attach if specified
    if [ -n "$CD_FILE" ]; then
        echo "CD-ROM: $CD_FILE (as SCSI ID ${cdrom_scsi_id})"
        qemu_args+=(
            "-device" "scsi-cd,bus=scsi.0,scsi-id=${cdrom_scsi_id},drive=cd0,vendor=$scsi_vendor,product=CD-ROM,serial=${scsi_serial_prefix}004"
            "-drive" "file=$CD_FILE,format=raw,media=cdrom,if=none,id=cd0"
        )
    else
        echo "No CD-ROM specified"
    fi
    
    # Additional HDD (SCSI ID 4) - Attach if specified via -a flag
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE (as SCSI ID 4)"
        qemu_args+=(
            "-device" "scsi-hd,bus=scsi.0,scsi-id=4,drive=hd_add,vendor=$scsi_vendor,product=QEMU_ADD_DISK,serial=${scsi_serial_prefix}003"
            "-drive" "file=$ADDITIONAL_HDD_FILE,media=disk,format=raw,if=none,id=hd_add,$drive_cache_params"
        )
    fi
    
    # Add NuBus framebuffer device if specified
    if [ "$display_device" = "nubus-macfb" ]; then
        info_log "Adding NuBus framebuffer device"
        qemu_args+=("-device" "nubus-macfb")
    fi
    
    # Add SWIM floppy drive if image is specified
    if [ -n "$floppy_image" ]; then
        info_log "Adding SWIM floppy drive with image: $floppy_image"
        local readonly_param=""
        if [ "$floppy_readonly" = "true" ]; then
            readonly_param=",readonly=on"
        fi
        
        qemu_args+=(
            "-device" "swim-drive,bus=swim-bus,drive=floppy0"
            "-drive" "file=$floppy_image,format=raw,if=none,id=floppy0$readonly_param"
        )
        
        echo "Floppy: $floppy_image (Format: $floppy_format, Read-only: $floppy_readonly)"
    else
        echo "No floppy disk specified"
    fi
    
    echo "Display: $DISPLAY_TYPE (Device: $display_device, Resolution: $QEMU_GRAPHICS)"
    echo "Audio: $audio_backend (ASC: $asc_mode, Latency: ${audio_latency}μs)"
    echo "--------------------------"
}

#######################################
# Build QEMU command line arguments for PowerPC architecture
# Arguments:
#   None
# Globals:
#   Various QEMU configuration variables
# Returns:
#   Sets qemu_args array
#######################################
build_ppc_qemu_command() {
    # Initialize the array
    qemu_args=()
    
    # Base machine arguments
    qemu_args+=(
        "-L" "pc-bios"
        "-M" "$QEMU_MACHINE"
        "-display" "$DISPLAY_TYPE"
        "-m" "$QEMU_RAM"
    )

    # Add graphics resolution from config file
    if [ -n "$QEMU_GRAPHICS" ]; then
        qemu_args+=("-g" "$QEMU_GRAPHICS")
    fi

    # Add a capable VGA device with EDID to allow the guest OS to detect more resolutions.
    # This is often necessary for Mac OS X.
    qemu_args+=("-device" "VGA,edid=on")
    
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
    local accel_opts
    accel_opts=$(build_tcg_acceleration "$QEMU_TCG_THREAD_MODE" "$QEMU_TB_SIZE")
    qemu_args+=("-accel" "$accel_opts")
    
    # Add boot order - PPC uses simple -boot flag instead of PRAM
    if [ "$BOOT_FROM_CD" = true ]; then
        qemu_args+=("-boot" "d")  # Boot from CD-ROM
    else
        qemu_args+=("-boot" "c")  # Boot from hard disk
    fi
    
    # --- Storage drives with performance settings ---
    local drive_opts=""
    
    # Build IDE performance options using common function
    if [ -n "$QEMU_IDE_CACHE_MODE" ] || [ -n "$QEMU_IDE_AIO_MODE" ]; then
        local cache_mode="${QEMU_IDE_CACHE_MODE:-writethrough}"
        local aio_mode="${QEMU_IDE_AIO_MODE:-threads}"
        drive_opts=$(build_drive_cache_params "$cache_mode" "$aio_mode")
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
    
    # --- Network arguments using shared networking module ---
    build_network_args qemu_args
    
    echo "Display: $DISPLAY_TYPE"
    echo "Performance: CPU=$QEMU_CPU, SMP=$QEMU_SMP_CORES, TCG=$QEMU_TCG_THREAD_MODE, TB=$QEMU_TB_SIZE"
    echo "Storage: Cache=$QEMU_IDE_CACHE_MODE, AIO=$QEMU_IDE_AIO_MODE"
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
    echo "--- Starting $ARCH Mac Emulation ---"
    echo "Configuration: $CONFIG_NAME"
    echo "Machine: $QEMU_MACHINE, RAM: ${QEMU_RAM}M"
    echo "OS HDD: $QEMU_HDD"
    echo "Shared HDD: $QEMU_SHARED_HDD"
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        echo "Additional HDD: $ADDITIONAL_HDD_FILE"
    fi
    if [ "$ARCH" = "m68k" ]; then
        echo "ROM: $QEMU_ROM"
        echo "PRAM: $QEMU_PRAM"
    fi
    
    # Execute QEMU using the secure array
    local qemu_binary
    if [ "$ARCH" = "m68k" ]; then
        qemu_binary="qemu-system-m68k"
    else
        qemu_binary="qemu-system-ppc"
    fi

    # Prepare the command for printing, ensuring proper quoting for copy-pasting.
    # The '%q' format specifier quotes the string in a way that is reusable by the shell.
    local cmd_to_print
    printf -v cmd_to_print "%q " "$qemu_binary" "${qemu_args[@]}"

    # Display the full, copy-pasteable command to the user.
    echo ""
    echo "========================================================"
    echo " QEMU LAUNCH COMMAND (copy/paste)"
    echo "--------------------------------------------------------"
    echo "$cmd_to_print"
    echo "--------------------------------------------------------"
    echo ""
    
    echo "--- Starting QEMU $ARCH ---"
    debug_log "QEMU command: $qemu_binary ${qemu_args[*]}"
    
    "$qemu_binary" "${qemu_args[@]}"
    
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "QEMU exited with error code: $exit_code" >&2
        echo "Check QEMU output for specific error messages." >&2
    else
        echo "QEMU session ended normally."
    fi
    
    # Exit with QEMU's exit code
    exit $exit_code
}

#######################################
# Main script execution
# Arguments:
#   All command line arguments
# Returns:
#   None
# Exits:
#   Various exit codes depending on failure points
#######################################
main() {
    # Parse arguments first to enable debug mode early if requested
    parse_arguments "$@"
    
    # Get architecture from config file
    ARCH=$(get_architecture_from_config "$CONFIG_FILE")
    echo "Detected $ARCH architecture"
    
    # Check QEMU version compatibility
    check_qemu_version "$REQUIRED_QEMU_VERSION"
    
    # Check dependencies using common module
    check_common_dependencies "$ARCH"
    
    # Load and validate configuration
    load_and_validate_config "$CONFIG_FILE"
    
    # Validate additional files if specified
    validate_common_files "$CD_FILE" "$ADDITIONAL_HDD_FILE"
    
    # Prepare storage
    prepare_disk_images
    
    # Boot order information
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        if [ "$ARCH" = "m68k" ]; then
            info_log "CD-ROM attached for installation - will boot from CD (SCSI ID 6) if bootable"
        else
            info_log "CD-ROM attached for installation - will boot from CD-ROM"
        fi
    else
        if [ "$BOOT_FROM_CD" = true ] && [ -z "$CD_FILE" ]; then
            warning_log "-b specified but no CD image provided with -c. Will boot from OS disk."
        fi
        if [ "$ARCH" = "m68k" ]; then
            info_log "Normal boot - will boot from OS disk (SCSI ID 6)"
        else
            info_log "Normal boot - will boot from hard disk"
        fi
    fi
    
    # Determine display type
    DISPLAY_TYPE=$(determine_display_type "$DISPLAY_TYPE")
    
    # Setup networking
    setup_networking
    
    # Build QEMU command based on architecture
    if [ "$ARCH" = "m68k" ]; then
        build_68k_qemu_command
    else
        build_ppc_qemu_command
    fi
    
    # Run emulation
    run_emulation
}

# --- Script Entry Point ---
main "$@"