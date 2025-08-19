#!/bin/bash
#
# QemuMac Runner - A simple, robust script to manage and launch classic Mac VMs

set -Euo pipefail # Exit on error, unset var, pipe failure

# --- Color Codes for User-Friendly Output ---
C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_RESET=$(tput sgr0)

# --- Helper functions for printing colored text ---
info() { >&2 echo "${C_YELLOW}Info: ${1}${C_RESET}"; }
success() { >&2 echo "${C_GREEN}Success: ${1}${C_RESET}"; }
error() { >&2 echo "${C_RED}Error: ${1}${C_RESET}"; }

#
# Generates a new VM directory and an interactive configuration template.
#
generate_config() {
    local vm_name="$1"
    local vm_dir="vms/${vm_name}"
    local conf_file="${vm_dir}/${vm_name}.conf"
    local arch_choice arch

    if [[ -d "$vm_dir" ]]; then
        error "VM '${vm_name}' already exists at '${vm_dir}'."
        exit 1
    fi

    >&2 echo "Choose an architecture for '${C_BLUE}${vm_name}${C_RESET}':"
    select arch_choice in "m68k (Macintosh Quadra)" "ppc (PowerMac G4)"; do
        case $arch_choice in
            "m68k (Macintosh Quadra)") arch="m68k"; break;;
            "ppc (PowerMac G4)") arch="ppc"; break;;
            *) >&2 echo "Invalid choice. Please enter 1 or 2.";;
        esac
    done

    info "Creating new VM: ${vm_name} (${arch})"
    mkdir -p "$vm_dir"

    # Cleaned up templates without redundant display, net, or rom settings.
    if [[ "$arch" == "m68k" ]]; then
        cat > "$conf_file" << EOL
# VM Configuration for ${vm_name} (m68k)
ARCH="m68k"
MACHINE_TYPE="q800"
RAM_SIZE="128M"
HD_SIZE="2G"
PRAM_FILE="${vm_dir}/pram.img"
HD_IMAGE="${vm_dir}/hdd.qcow2"
HD_SCSI_ID=0
CD_SCSI_ID=2
EOL
    else # ppc
        cat > "$conf_file" << EOL
# VM Configuration for ${vm_name} (ppc)
ARCH="ppc"
MACHINE_TYPE="mac99"
RAM_SIZE="512M"
HD_SIZE="10G"
HD_IMAGE="${vm_dir}/hdd.qcow2"
EOL
    fi
    success "Config created at: ${C_BLUE}${conf_file}${C_RESET}"
    info "Next, ensure your ROM/ISO files are in place and run with:"
    >&2 echo "  ./run-mac.sh --config ${conf_file}"
}

#
# Verifies required files and creates images if they don't exist.
#
preflight_checks() {
    info "Running pre-flight checks..."

    if [[ ! -f "$HD_IMAGE" ]]; then
        info "Hard drive not found. Creating '${HD_IMAGE}' (${HD_SIZE})."
        qemu-img create -f qcow2 "$HD_IMAGE" "$HD_SIZE" > /dev/null
    fi

    if [[ "$ARCH" == "m68k" ]]; then
        # For m68k, PRAM file is required but might be created by user, so check.
        if [[ ! -f "$PRAM_FILE" ]]; then
            info "PRAM file not found. Creating '${PRAM_FILE}'."
            dd if=/dev/zero of="$PRAM_FILE" bs=256 count=1 &>/dev/null
        fi
        local m68k_rom_file="roms/800.ROM"
        if [[ ! -f "$m68k_rom_file" ]]; then
            error "Required m68k ROM file not found at: ${m68k_rom_file}"
            exit 1
        fi
    fi

    if [[ -n "$CD_ISO_FILE" && ! -f "$CD_ISO_FILE" ]]; then
        error "ISO file '${CD_ISO_FILE}' is specified but not found."
        exit 1
    fi
    info "Checks passed."
}

#
# Patches the m68k PRAM file to set the boot device.
# Mac OS on m68k ignores the QEMU boot order arguments and instead reads the
# boot device from PRAM (Parameter RAM). This function writes to the PRAM
# file before launch to select the boot target (hard drive or CD-ROM).
#
# The boot device is stored as a 4-byte value starting at offset 0x78 (120)
# in the PRAM file. The structure is:
#   - Byte 0 (offset 120, 0x78): Drive ID
#   - Byte 1 (offset 121, 0x79): Partition ID
#   - Bytes 2-3 (offset 122, 0x7A): RefNum (a 16-bit word)
#
# For SCSI devices, DriveID and PartitionID are typically 0xff. The RefNum
# is calculated from the SCSI ID using the formula: RefNum = ~(SCSI_ID + 32).
#
# This function calculates the correct RefNum for the target SCSI device
# and writes the full 4-byte sequence into the PRAM file.
#
set_boot_m68k() {
    local pram_file="$1"
    local target="$2"
    local scsi_id refnum_value byte_format_string

    if [[ "$target" == "cd" ]]; then
        scsi_id=$CD_SCSI_ID
        info "Patching PRAM to boot from CD-ROM (SCSI ID ${scsi_id})..."
    else
        scsi_id=$HD_SCSI_ID
        info "Patching PRAM to boot from Hard Drive (SCSI ID ${scsi_id})..."
    fi

    refnum_value=$((~(scsi_id + 32) & 0xFFFF))
    byte_format_string=$(printf '\\xff\\xff\\x%02x\\x%02x' \
        $(((refnum_value >> 8) & 0xFF)) \
        $((refnum_value & 0xFF)))

    printf "$byte_format_string" | dd of="$pram_file" bs=1 seek=120 count=4 conv=notrunc &>/dev/null
}

#
# Build display and input args based on the host OS.
#
build_display_and_input_args() {
    local host_os=""
    [[ "$OSTYPE" == darwin* ]] && host_os="macos" || host_os="linux"

    info "Configuring display and input devices for host OS..."
    if [[ "$host_os" == "macos" ]]; then
        info "Using Cocoa display on macOS."
        QEMU_ARGS+=(-display cocoa,swap-opt-cmd=on)
    else
        info "Using SDL display on Linux."
        info "→ Press Right-Ctrl + G to release mouse grab."
        info "→ Press Left-Shift + Left-Command + Q/W for Quit/Close in 68k guest."
        info "→ Right-Command + Q/W for Quit/Close in PPC guest."
        QEMU_ARGS+=(-display sdl,grab-mod=rctrl)
    fi
}

#
# Build all QEMU arguments for an m68k (Quadra) VM.
#
build_m68k_args() {
    info "Building QEMU arguments for m68k (Quadra 800)..."
    set_boot_m68k "$PRAM_FILE" "$BOOT_TARGET"

    QEMU_ARGS+=(
        -M "$MACHINE_TYPE"
        -m "$RAM_SIZE"
        -bios "roms/800.ROM"
        -g 1152x870x8
        -nic user,model=dp83932,mac=08:00:07:12:34:56
        -drive "file=${PRAM_FILE},format=raw,if=mtd"
        -device scsi-hd,scsi-id=$HD_SCSI_ID,drive=hd0
        -drive "file=${HD_IMAGE},format=qcow2,if=none,id=hd0"
    )
    if [[ -n "$CD_ISO_FILE" ]]; then
        QEMU_ARGS+=(
            -device scsi-cd,scsi-id=$CD_SCSI_ID,drive=cd0
            -drive "file=${CD_ISO_FILE},format=raw,if=none,media=cdrom,id=cd0"
        )
    fi
}

#
# Build all QEMU arguments for a ppc (PowerMac) VM.
#
build_ppc_args() {
    info "Building QEMU arguments for ppc (PowerMac G4)..."
    # Enable PMU for stable USB keyboard/mouse support in Mac OS 9.
    local machine_string="${MACHINE_TYPE},via=pmu"

    local hd_i=1 cd_i=2
    [[ "$BOOT_TARGET" == "cd" ]] && hd_i=2 cd_i=1

    QEMU_ARGS+=(
        -M "$machine_string"
        -m "$RAM_SIZE"
        -vga std
        -g 1024x768x32
        -netdev user,id=net0
        -device sungem,netdev=net0
        -device pci-ohci,id=ohci
        -device usb-mouse,bus=ohci.0
        -device usb-kbd,bus=ohci.0
        -drive "file=${HD_IMAGE},format=qcow2,if=none,id=hd0"
        -device ide-hd,drive=hd0,bootindex=$hd_i
    )
    if [[ -n "$CD_ISO_FILE" ]]; then
        QEMU_ARGS+=(
            -drive "file=${CD_ISO_FILE},format=raw,if=none,id=cd0,media=cdrom"
            -device ide-cd,drive=cd0,bootindex=$cd_i
        )
    fi
}

# --- SCRIPT ENTRY POINT ---
main() {
    local CONFIG_FILE="" BOOT_TARGET="hd" CD_ISO_FILE="" CREATE_VM_NAME=""
    local SHORT_OPTS="c:i:" LONG_OPTS="config:,iso:,boot-from-cd,create-config:"
    local PARSED_OPTS
    PARSED_OPTS=$(getopt -o "$SHORT_OPTS" -l "$LONG_OPTS" -n "$0" -- "$@") || exit 1
    eval set -- "$PARSED_OPTS"

    while true; do
        case $1 in
            --create-config) CREATE_VM_NAME="$2"; shift 2 ;;
            -c|--config) CONFIG_FILE="$2"; shift 2 ;;
            -i|--iso) CD_ISO_FILE="$2"; shift 2 ;;
            --boot-from-cd) BOOT_TARGET="cd"; shift ;;
            --) shift; break ;;
        esac
    done

    [[ -n $CREATE_VM_NAME ]] && { generate_config "$CREATE_VM_NAME"; exit 0; }
    [[ -z $CONFIG_FILE ]] && { error "No config file specified. Use --config"; exit 1; }
    [[ ! -f $CONFIG_FILE ]] && { error "Config file not found"; exit 1; }

    source "$CONFIG_FILE"
    CD_ISO_FILE="${CD_ISO_FILE:-}"

    preflight_checks

    # Define the path for the local QEMU installation
    local LOCAL_QEMU_INSTALL_DIR="qemu_install"
    local QEMU_EXECUTABLE="qemu-system-${ARCH}"
    local qemu_bin_path=""

    # Prioritize the local QEMU build if it exists
    if [[ -x "${LOCAL_QEMU_INSTALL_DIR}/bin/${QEMU_EXECUTABLE}" ]]; then
        info "Using local QEMU build from './${LOCAL_QEMU_INSTALL_DIR}/'"
        qemu_bin_path="${LOCAL_QEMU_INSTALL_DIR}/bin/${QEMU_EXECUTABLE}"
    # Otherwise, fall back to the system's PATH
    elif command -v "$QEMU_EXECUTABLE" &>/dev/null; then
        info "Using system QEMU found in PATH."
        qemu_bin_path="$QEMU_EXECUTABLE"
    else
        error "QEMU executable '${QEMU_EXECUTABLE}' not found in PATH or in './${LOCAL_QEMU_INSTALL_DIR}/'."
        info "Please run the install-deps.sh script to build it."
        exit 1
    fi

    declare -a QEMU_ARGS
    QEMU_ARGS=("$qemu_bin_path")


    # Set host-specific display driver (Cocoa or SDL)
    build_display_and_input_args

    # Build all architecture-specific arguments (machine, RAM, devices, etc.)
    if [[ $ARCH == m68k ]]; then
        build_m68k_args
    else # ppc
        build_ppc_args
    fi

    info "Starting QEMU..."
    >&2 echo "---"
    exec "${QEMU_ARGS[@]}"
}

main "$@"
