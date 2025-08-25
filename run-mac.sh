#!/bin/bash
set -Euo pipefail
source "$(dirname "$0")/lib/common.sh"

generate_config() {
    local vm_name="$1"
    local vm_dir="vms/${vm_name}"
    local conf_file="${vm_dir}/${vm_name}.conf"
    local arch_choice arch

    dir_exists "$vm_dir" && die "VM '${vm_name}' already exists at '${vm_dir}'."

    local arch_choice
    arch_choice=$(menu "Choose an architecture for '${vm_name}':" \
        "m68k (Macintosh Quadra)" \
        "ppc (PowerMac G4)")
    
    case $arch_choice in
        "m68k (Macintosh Quadra)") arch="m68k";;
        "ppc (PowerMac G4)") arch="ppc";;
    esac

    info "Creating new VM: ${vm_name} (${arch})"
    ensure_directory "$vm_dir" "Creating VM directory"

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
SHARED_SCSI_ID=4
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

preflight_checks() {
    if ! file_exists "$HD_IMAGE"; then
        info "Hard drive not found. Creating '${HD_IMAGE}' (${HD_SIZE})."
        qemu-img create -f qcow2 "$HD_IMAGE" "$HD_SIZE" > /dev/null
    fi

    if [[ "$ARCH" == "m68k" ]]; then
        if ! file_exists "$PRAM_FILE"; then
            info "PRAM file not found. Creating '${PRAM_FILE}'."
            dd if=/dev/zero of="$PRAM_FILE" bs=256 count=1 &>/dev/null
        fi
        local m68k_rom_file="roms/800.ROM"
        require_file "$m68k_rom_file" "Required m68k ROM file not found at: ${m68k_rom_file}"
    fi

    [[ -n "$CD_ISO_FILE" ]] && require_file "$CD_ISO_FILE" "ISO file '${CD_ISO_FILE}' is specified but not found."
    
    local shared_dir="shared"
    local shared_disk="$shared_dir/shared-disk.img"
    if ! file_exists "$shared_disk"; then
        info "Shared disk not found. Creating '${shared_disk}' (512M)."
        ensure_directory "$shared_dir"
        qemu-img create -f raw "$shared_disk" 512M > /dev/null
        success "Shared disk created (unformatted)"
        info "Format as Mac OS Standard from within your Mac VM"
        info "Then mount with: ./mount-shared.sh"
    fi
}

# Patch PRAM boot device: RefNum = ~(SCSI_ID + 32) at offset 120
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

build_display_and_input_args() {
    local host_os
    host_os=$(detect_os)

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


build_m68k_args() {
    info "Building QEMU arguments for m68k (Quadra 800)..."
    set_boot_m68k "$PRAM_FILE" "$BOOT_TARGET"
    local aio_backend="threads"
    info "Performance optimizations: CPU=m68040, Storage=writeback+${aio_backend}"
    
    QEMU_ARGS+=(
        -M "$MACHINE_TYPE"
        -cpu m68040
        -m "$RAM_SIZE"
        -bios "roms/800.ROM"
        -g 1152x870x8
        -nic user,model=dp83932,mac=08:00:07:12:34:56
        -drive "file=${PRAM_FILE},format=raw,if=mtd"
        -device scsi-hd,scsi-id=$HD_SCSI_ID,drive=hd0
        -drive "file=${HD_IMAGE},format=qcow2,cache=writeback,aio=${aio_backend},detect-zeroes=on,if=none,id=hd0"
        -device scsi-hd,scsi-id=${SHARED_SCSI_ID:-4},drive=shared0
        -drive "file=shared/shared-disk.img,format=raw,if=none,id=shared0"
    )
    if [[ -n "$CD_ISO_FILE" ]]; then
        QEMU_ARGS+=(
            -device scsi-cd,scsi-id=$CD_SCSI_ID,drive=cd0
            -drive "file=${CD_ISO_FILE},format=raw,cache=writeback,aio=${aio_backend},if=none,media=cdrom,id=cd0"
        )
    fi
}

build_ppc_args() {
    info "Building QEMU arguments for ppc (PowerMac G4)..."
    local machine_string="${MACHINE_TYPE},via=pmu"
    local aio_backend="threads"
    info "Performance optimizations: CPU=G4-7400, Storage=writeback+${aio_backend}"
    
    local hd_i=1 cd_i=2
    [[ "$BOOT_TARGET" == "cd" ]] && hd_i=2 cd_i=1

    QEMU_ARGS+=(
        -M "$machine_string"
        -cpu 7400_v2.9
        -m "$RAM_SIZE"
        -vga std
        -g 1024x768x32
        -netdev user,id=net0
        -device sungem,netdev=net0
        -device pci-ohci,id=ohci
        -device usb-mouse,bus=ohci.0
        -device usb-kbd,bus=ohci.0
        -drive "file=${HD_IMAGE},format=qcow2,cache=writeback,aio=${aio_backend},detect-zeroes=on,if=none,id=hd0"
        -device ide-hd,bus=ide.0,unit=0,drive=hd0,bootindex=$hd_i
        -drive "file=shared/shared-disk.img,format=raw,if=none,id=shared0"
        -device ide-hd,bus=ide.1,unit=0,drive=shared0
    )
    if [[ -n "$CD_ISO_FILE" ]]; then
        QEMU_ARGS+=(
            -drive "file=${CD_ISO_FILE},format=raw,cache=writeback,aio=${aio_backend},if=none,id=cd0,media=cdrom"
            -device ide-cd,bus=ide.0,unit=1,drive=cd0,bootindex=$cd_i
        )
    fi
}

interactive_launch() {
    header "Select a Virtual Machine to launch"
    if ! find_files_with_names "vms" "*.conf" "parent_dir" "-mindepth 2 -maxdepth 2 -type f"; then
        error "No VM configurations found in 'vms/' directory"
        info "Create one with: ./run-mac.sh --create-config <vm-name>"
        die "No VM configurations found"
    fi

    local vm_choice vm_index
    vm_choice=$(menu "Choose a VM:" "${FOUND_NAMES[@]}")
    [[ "$vm_choice" == "QUIT" ]] && exit 0
    
    for i in "${!FOUND_NAMES[@]}"; do
        [[ "${FOUND_NAMES[$i]}" == "$vm_choice" ]] && vm_index="$i" && break
    done
    CONFIG_FILE="${FOUND_FILES[$vm_index]}"

    header "Select an ISO file to attach (optional)"
    local -a iso_options=("None (Boot from Hard Drive)")
    local ISO_FILES=()
    if find_files_with_names "iso" "*.iso" "basename" "-maxdepth 1 -type f"; then
        iso_options+=("${FOUND_NAMES[@]}")
        ISO_FILES=("${FOUND_FILES[@]}")
    fi

    local iso_choice
    iso_choice=$(menu "Choose an ISO:" "${iso_options[@]}")
    
    if [[ "$iso_choice" == "NONE" ]] || [[ "$iso_choice" == "None"* ]]; then
        CD_ISO_FILE=""
    else
        for iso in "${ISO_FILES[@]}"; do
            [[ "$(basename "$iso")" == "$iso_choice" ]] && CD_ISO_FILE="$iso" && break
        done
    fi

    if [[ -n "$CD_ISO_FILE" ]]; then
        local boot_action
        boot_action=$(menu "How should the ISO be used?" \
            "Boot from Hard Drive (mount ISO on desktop)" \
            "Boot from CD/ISO (for OS installation, etc.)")
        [[ "$boot_action" == *"CD/ISO"* ]] && BOOT_TARGET="cd" || BOOT_TARGET="hd"
    fi
}

main() {
    local CONFIG_FILE="" BOOT_TARGET="hd" CD_ISO_FILE="" CREATE_VM_NAME=""
    if [[ $# -eq 0 ]]; then
        interactive_launch
    else
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
    fi

    if [[ -n "$CREATE_VM_NAME" ]]; then
        generate_config "$CREATE_VM_NAME"
        exit 0
    fi

    [[ -z "$CONFIG_FILE" ]] && die "No configuration specified or selected"
    require_file "$CONFIG_FILE" "Config file not found"

    source "$CONFIG_FILE"
    CD_ISO_FILE="${CD_ISO_FILE:-}"
    preflight_checks
    local LOCAL_QEMU_INSTALL_DIR="qemu-install"
    local QEMU_EXECUTABLE="qemu-system-${ARCH}"
    local qemu_bin_path=""

    if executable_exists "${LOCAL_QEMU_INSTALL_DIR}/bin/${QEMU_EXECUTABLE}"; then
        info "Using local QEMU build from './${LOCAL_QEMU_INSTALL_DIR}/'"
        qemu_bin_path="${LOCAL_QEMU_INSTALL_DIR}/bin/${QEMU_EXECUTABLE}"
    elif command_exists "$QEMU_EXECUTABLE"; then
        info "Using system QEMU found in PATH."
        qemu_bin_path="$QEMU_EXECUTABLE"
    else
        die "QEMU executable '${QEMU_EXECUTABLE}' not found. Run ./install-deps.sh"
    fi

    declare -a QEMU_ARGS
    QEMU_ARGS=("$qemu_bin_path")
    build_display_and_input_args
    [[ $ARCH == m68k ]] && build_m68k_args || build_ppc_args
    info "Starting QEMU..."
    >&2 echo "---"
    exec "${QEMU_ARGS[@]}"
}

main "$@"
