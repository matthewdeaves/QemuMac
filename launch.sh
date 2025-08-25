#!/bin/bash
#
# QemuMac Launcher - A friendly menu-driven launcher for run-mac.sh
# This script finds all available VM configurations and ISO files and
# presents them in simple menus to make launching a VM easy.
#

set -Euo pipefail

# Load common library
source "$(dirname "$0")/lib/common.sh"


# --- SCRIPT ENTRY POINT ---
main() {
    # Pre-flight check to ensure the main run script is available
    require_executable "./run-mac.sh" "'run-mac.sh' not found or is not executable in the current directory."

    # --- Step 1: Select the Virtual Machine ---
    header "Select a Virtual Machine to launch"

    # Find all .conf files in the vms/ directory structure.
    if ! find_files_with_names "vms" "*.conf" "parent_dir" "-mindepth 2 -maxdepth 2 -type f"; then
        error "No VM configuration files (.conf) found in the 'vms/' directory."
        info "You can create one using: ./run-mac.sh --create-config <vm-name>"
        die "No VM configurations found"
    fi

    # Use menu utility to select VM
    local vm_choice vm_index=""
    vm_choice=$(menu "Choose a VM:" "${FOUND_NAMES[@]}")
    
    [[ "$vm_choice" == "QUIT" ]] && exit 0
    
    # Find index of selected VM
    for i in "${!FOUND_NAMES[@]}"; do
        [[ "${FOUND_NAMES[$i]}" == "$vm_choice" ]] && vm_index="$i" && break
    done
    
    SELECTED_CONFIG="${FOUND_FILES[$vm_index]}"
    info "You selected VM: ${C_BLUE}${vm_choice}${C_RESET}"

    # --- Step 2: Select an ISO file to attach ---
    header "Select an ISO file to attach (optional)"

    # Find all .iso files in the iso/ directory.
    local -a iso_options=("None (Boot from Hard Drive)")
    local ISO_FILES=()
    
    if find_files_with_names "iso" "*.iso" "basename" "-maxdepth 1 -type f"; then
        iso_options+=("${FOUND_NAMES[@]}")
        ISO_FILES=("${FOUND_FILES[@]}")
    fi

    local SELECTED_ISO=""

    # Use menu utility to select ISO
    local iso_choice
    iso_choice=$(menu "Choose an ISO:" "${iso_options[@]}")
    
    if [[ "$iso_choice" == "NONE" ]] || [[ "$iso_choice" == "None"* ]]; then
        # Handle "None" selection
        info "No ISO selected. The VM will boot from its hard drive."
        SELECTED_ISO=""
    else
        # Find matching ISO file
        for iso in "${ISO_FILES[@]}"; do
            [[ "$(basename "$iso")" == "$iso_choice" ]] && SELECTED_ISO="$iso" && break
        done
        info "You selected ISO: ${C_BLUE}$(basename "$SELECTED_ISO")${C_RESET}"
    fi

    # --- Step 3: Choose Boot Target (only if an ISO was selected) ---
    local BOOT_FLAG=""
    if [[ -n "$SELECTED_ISO" ]]; then
        header "Choose boot action for the selected ISO"

        local boot_prompt_options=(
            "Boot from Hard Drive (mount ISO on desktop)"
            "Boot from CD/ISO (for OS installation, etc.)"
        )

        local boot_action
        boot_action=$(menu "How should the ISO be used?" "${boot_prompt_options[@]}")
        
        if [[ "$boot_action" == "Boot from CD/ISO (for OS installation, etc.)" ]]; then
            BOOT_FLAG="--boot-from-cd"
            info "VM will attempt to boot from the ISO."
        else
            BOOT_FLAG=""
            info "VM will boot from the hard drive; ISO will be available on the guest desktop."
        fi
    fi

    # --- Step 4: Assemble and Execute the Command ---
    header "Preparing to launch QEMU"

    # Build the argument list for run-mac.sh in an array. This is the safest
    # way to handle arguments that might contain spaces or special characters.
    local -a CMD_ARGS=("./run-mac.sh")
    CMD_ARGS+=("--config" "$SELECTED_CONFIG")

    if [[ -n "$SELECTED_ISO" ]]; then
        CMD_ARGS+=("--iso" "$SELECTED_ISO")
    fi

    if [[ -n "$BOOT_FLAG" ]]; then
        CMD_ARGS+=("$BOOT_FLAG")
    fi

    # Display the final command for user confirmation/debugging.
    info "Executing command: ${C_GREEN}${CMD_ARGS[*]}${C_RESET}"
    >&2 echo "---"

    # Use 'exec' to replace this launcher script's process with the QEMU process.
    # This is efficient and ensures QEMU signals (like Ctrl+C) are handled correctly.
    exec "${CMD_ARGS[@]}"
}

# Run the main function.
main
