#!/usr/bin/env bash

#######################################
# Simplified Mac Emulation Runner
# Runs both 68k and PowerPC Mac emulation with QEMU
# Auto-detects architecture from config file
#######################################

# Basic error handling (removed strict -u mode)
set -eo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script variables
CONFIG_FILE=""
CD_FILE=""
ADDITIONAL_HDD_FILE=""
BOOT_FROM_CD=false
DISPLAY_TYPE=""
DEBUG_MODE=false

# Configuration variables (will be loaded from config file)
ARCH=""
QEMU_MACHINE=""
QEMU_RAM=""
QEMU_ROM=""
QEMU_HDD=""
QEMU_SHARED_HDD=""
QEMU_GRAPHICS=""
QEMU_PRAM=""

#######################################
# Show help information
#######################################
show_help() {
    echo "Simplified Mac Emulation Runner"
    echo ""
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo ""
    echo "Required:"
    echo "  -C FILE  Configuration file"
    echo ""
    echo "Options:"
    echo "  -c FILE  CD-ROM image file"
    echo "  -a FILE  Additional hard drive file"
    echo "  -b       Boot from CD-ROM (for installation)"
    echo "  -d TYPE  Display type (sdl, gtk, cocoa)"
    echo "  -D       Debug mode"
    echo "  -?       Show help"
    echo ""
    echo "Examples:"
    echo "  $0 -C m68k/configs/m68k-macos753.conf"
    echo "  $0 -C m68k/configs/m68k-macos753.conf -c install.iso -b"
    exit 1
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    while getopts "C:c:a:bd:D?" opt; do
        case $opt in
            C) CONFIG_FILE="$OPTARG" ;;
            c) CD_FILE="$OPTARG" ;;
            a) ADDITIONAL_HDD_FILE="$OPTARG" ;;
            b) BOOT_FROM_CD=true ;;
            d) DISPLAY_TYPE="$OPTARG" ;;
            D) DEBUG_MODE=true ;;
            ?) show_help ;;
            *) echo "Invalid option" >&2; exit 1 ;;
        esac
    done

    if [ -z "$CONFIG_FILE" ]; then
        echo "Error: Configuration file required (-C)" >&2
        show_help
    fi
}

#######################################
# Load configuration file
#######################################
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: Config file not found: $CONFIG_FILE" >&2
        exit 1
    fi
    
    echo "Loading configuration: $CONFIG_FILE"
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    
    # Basic validation
    if [ -z "$ARCH" ]; then
        echo "Error: ARCH not defined in config file" >&2
        exit 1
    fi
    
    if [ "$ARCH" != "m68k" ] && [ "$ARCH" != "ppc" ]; then
        echo "Error: Invalid ARCH '$ARCH'. Must be 'm68k' or 'ppc'" >&2
        exit 1
    fi
    
    echo "Architecture: $ARCH"
}

#######################################
# Check dependencies
#######################################
check_dependencies() {
    local qemu_binary=""
    
    if [ "$ARCH" = "m68k" ]; then
        qemu_binary="qemu-system-m68k"
    else
        qemu_binary="qemu-system-ppc"
    fi
    
    if ! command -v "$qemu_binary" &> /dev/null; then
        echo "Error: $qemu_binary not found" >&2
        echo "Please install QEMU or run ./install-dependencies.sh" >&2
        exit 1
    fi
    
    # Check ROM file for 68k
    if [ "$ARCH" = "m68k" ] && [ ! -f "$QEMU_ROM" ]; then
        echo "Error: ROM file not found: $QEMU_ROM" >&2
        echo "68k emulation requires Quadra 800 ROM file" >&2
        exit 1
    fi
}

#######################################
# Determine display type
#######################################
determine_display() {
    if [ -n "$DISPLAY_TYPE" ]; then
        echo "$DISPLAY_TYPE"
        return
    fi
    
    # Auto-detect based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "cocoa"
    else
        echo "sdl"
    fi
}

#######################################
# Create disk images if they don't exist
#######################################
create_missing_images() {
    # Create main HDD if missing
    if [ -n "$QEMU_HDD" ] && [ ! -f "$QEMU_HDD" ]; then
        local hdd_dir
        hdd_dir="$(dirname "$QEMU_HDD")"
        mkdir -p "$hdd_dir"
        echo "Creating system disk: $QEMU_HDD"
        qemu-img create -f raw "$QEMU_HDD" "${QEMU_HDD_SIZE:-10G}"
    fi
    
    # Create shared HDD if missing
    if [ -n "$QEMU_SHARED_HDD" ] && [ ! -f "$QEMU_SHARED_HDD" ]; then
        local shared_dir
        shared_dir="$(dirname "$QEMU_SHARED_HDD")"
        mkdir -p "$shared_dir"
        echo "Creating shared disk: $QEMU_SHARED_HDD"
        qemu-img create -f raw "$QEMU_SHARED_HDD" "${QEMU_SHARED_HDD_SIZE:-1G}"
    fi
    
    # Create PRAM for 68k if missing
    if [ "$ARCH" = "m68k" ] && [ -n "$QEMU_PRAM" ] && [ ! -f "$QEMU_PRAM" ]; then
        local pram_dir
        pram_dir="$(dirname "$QEMU_PRAM")"
        mkdir -p "$pram_dir"
        echo "Creating PRAM file: $QEMU_PRAM"
        # Create 256-byte PRAM file
        dd if=/dev/zero of="$QEMU_PRAM" bs=256 count=1 2>/dev/null
    fi
}

#######################################
# Build QEMU command for 68k
#######################################
build_68k_command() {
    local cmd=("qemu-system-m68k")
    local display
    display="$(determine_display)"
    
    cmd+=("-M" "$QEMU_MACHINE")
    cmd+=("-m" "$QEMU_RAM")
    cmd+=("-bios" "$QEMU_ROM")
    # PRAM file (simpler approach)
    if [ -n "$QEMU_PRAM" ]; then
        cmd+=("-drive" "file=$QEMU_PRAM,format=raw,if=none,id=pram")
        cmd+=("-global" "q800-machine.pram=pram")
    fi
    cmd+=("-display" "$display")
    cmd+=("-netdev" "user,id=net0")

    cmd+=(
        "-net"
        "nic,model=$QEMU_NETWORK_DEVICE"
        "-net"
        "user"
    )
    
    # Graphics
    if [ -n "$QEMU_GRAPHICS" ]; then
        cmd+=("-g" "$QEMU_GRAPHICS")
    fi
    
    # Storage setup
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        # Boot from CD: CD gets SCSI ID 6, HDD gets ID 5
        cmd+=("-drive" "file=$CD_FILE,format=raw,media=cdrom,if=scsi,bus=0,unit=6")
        if [ -n "$QEMU_HDD" ]; then
            cmd+=("-drive" "file=$QEMU_HDD,format=raw,if=scsi,bus=0,unit=5")
        fi
    else
        # Normal boot: HDD gets SCSI ID 6
        if [ -n "$QEMU_HDD" ]; then
            cmd+=("-drive" "file=$QEMU_HDD,format=raw,if=scsi,bus=0,unit=6")
        fi
        if [ -n "$CD_FILE" ]; then
            cmd+=("-drive" "file=$CD_FILE,format=raw,media=cdrom,if=scsi,bus=0,unit=3")
        fi
    fi
    
    # Shared drive
    if [ -n "$QEMU_SHARED_HDD" ]; then
        cmd+=("-drive" "file=$QEMU_SHARED_HDD,format=raw,if=scsi,bus=0,unit=4")
    fi
    
    # Additional HDD
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        cmd+=("-drive" "file=$ADDITIONAL_HDD_FILE,format=raw,if=scsi,bus=0,unit=2")
    fi
    
    echo "${cmd[@]}"
}

#######################################
# Build QEMU command for PowerPC
#######################################
build_ppc_command() {
    local cmd=("qemu-system-ppc")
    local display
    display="$(determine_display)"
    
    cmd+=("-M" "$QEMU_MACHINE")
    cmd+=("-m" "$QEMU_RAM")
    cmd+=("-display" "$display")
    cmd+=("-netdev" "user,id=net0")
    cmd+=("-device" "rtl8139,netdev=net0")
    
    # Graphics
    if [ -n "$QEMU_GRAPHICS" ]; then
        local res="${QEMU_GRAPHICS%x*}"  # Extract resolution
        local width="${res%x*}"
        local height="${res#*x}"
        cmd+=("-device" "VGA,xres=$width,yres=$height")
    fi
    
    # Storage setup
    if [ "$BOOT_FROM_CD" = true ] && [ -n "$CD_FILE" ]; then
        # Boot from CD
        cmd+=("-cdrom" "$CD_FILE")
        cmd+=("-boot" "d")
        if [ -n "$QEMU_HDD" ]; then
            cmd+=("-drive" "file=$QEMU_HDD,format=raw,if=ide")
        fi
    else
        # Normal boot from HDD
        if [ -n "$QEMU_HDD" ]; then
            cmd+=("-drive" "file=$QEMU_HDD,format=raw,if=ide")
        fi
        if [ -n "$CD_FILE" ]; then
            cmd+=("-cdrom" "$CD_FILE")
        fi
        cmd+=("-boot" "c")
    fi
    
    # Shared drive as second IDE drive
    if [ -n "$QEMU_SHARED_HDD" ]; then
        cmd+=("-drive" "file=$QEMU_SHARED_HDD,format=raw,if=ide,index=1")
    fi
    
    # Additional HDD
    if [ -n "$ADDITIONAL_HDD_FILE" ]; then
        cmd+=("-drive" "file=$ADDITIONAL_HDD_FILE,format=raw,if=ide,index=2")
    fi
    
    echo "${cmd[@]}"
}

#######################################
# Main execution
#######################################
main() {
    if [ "$DEBUG_MODE" = true ]; then
        set -x
    fi
    
    parse_arguments "$@"
    load_config
    check_dependencies
    create_missing_images
    
    echo "Starting $ARCH Mac emulation..."
    echo "Display: $(determine_display)"
    if [ "$BOOT_FROM_CD" = true ]; then
        echo "Boot mode: CD-ROM installation"
    else
        echo "Boot mode: Hard disk"
    fi
    
    # Build and execute command based on architecture
    local qemu_cmd
    if [ "$ARCH" = "m68k" ]; then
        qemu_cmd="$(build_68k_command)"
    else
        qemu_cmd="$(build_ppc_command)"
    fi
    
    echo "Executing: $qemu_cmd"
    eval "$qemu_cmd"
}

# Run main function with all arguments
main "$@"