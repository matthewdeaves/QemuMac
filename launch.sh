#!/bin/bash
#
# QemuMac Launcher - A friendly menu-driven launcher for run-mac.sh
# This script finds all available VM configurations and ISO files and
# presents them in simple menus to make launching a VM easy.
#

set -Euo pipefail

# --- Color Codes for User-Friendly Output (consistent with other scripts) ---
C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_RESET=$(tput sgr0)


# --- Helper functions for printing colored text ---
info() { >&2 echo -e "${C_YELLOW}Info: ${1}${C_RESET}"; }
error() { >&2 echo -e "${C_RED}Error: ${1}${C_RESET}"; }
header() { >&2 echo -e "\n${C_BLUE}--- ${1} ---${C_RESET}"; }


# --- SCRIPT ENTRY POINT ---
main() {
    # Pre-flight check to ensure the main run script is available
    if [[ ! -x "./run-mac.sh" ]]; then
        error "'run-mac.sh' not found or is not executable in the current directory."
        exit 1
    fi

    # --- Step 1: Select the Virtual Machine ---
    header "Select a Virtual Machine to launch"

    # Find all .conf files in the vms/ directory structure.
    # 'mapfile -t' reads the output of the find command directly into an array.
    mapfile -t CONFIG_FILES < <(find vms -mindepth 2 -maxdepth 2 -type f -name "*.conf" | sort)

    if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
        error "No VM configuration files (.conf) found in the 'vms/' directory."
        info "You can create one using: ./run-mac.sh --create-config <vm-name>"
        exit 1
    fi

    # Create a user-friendly list of VM names from their config file paths.
    # This makes the menu much cleaner than showing the full path.
    local -a vm_options
    for conf_path in "${CONFIG_FILES[@]}"; do
        # Extract the vm name, e.g., "powermac_g4" from "vms/powermac_g4/powermac_g4.conf"
        vm_options+=("$(basename "$(dirname "$conf_path")")")
    done

    # Use the 'select' command to create an interactive menu for VMs.
    PS3="${C_YELLOW}Choose a VM: ${C_RESET}"
    select vm_choice in "${vm_options[@]}"; do
        if [[ -n "$vm_choice" ]]; then
            # The REPLY variable holds the index number of the selected option.
            SELECTED_CONFIG="${CONFIG_FILES[$REPLY-1]}"
            info "You selected VM: ${C_BLUE}${vm_choice}${C_RESET}"
            break
        else
            error "Invalid selection. Please try again."
        fi
    done

    # --- Step 2: Select an ISO file to attach ---
    header "Select an ISO file to attach (optional)"

    # Find all .iso files in the iso/ directory.
    mapfile -t ISO_FILES < <(find iso -maxdepth 1 -type f -name "*.iso" | sort)

    # Create a new list of options, starting with "None" for convenience.
    local -a iso_options=("None (Boot from Hard Drive)")
    for iso_path in "${ISO_FILES[@]}"; do
        iso_options+=("$(basename "$iso_path")")
    done

    local SELECTED_ISO=""

    # Display the interactive selection menu for ISOs.
    PS3="${C_YELLOW}Choose an ISO: ${C_RESET}"
    select iso_choice in "${iso_options[@]}"; do
        if [[ -n "$iso_choice" ]]; then
            if [[ "$iso_choice" == "None (Boot from Hard Drive)" ]]; then
                info "No ISO selected. The VM will boot from its hard drive."
                SELECTED_ISO=""
            else
                # The index for ISO_FILES is off by one because we added "None" at the start of iso_options.
                # For example, selecting option 2 (the first ISO) corresponds to index 0 in the ISO_FILES array.
                SELECTED_ISO="${ISO_FILES[$REPLY-2]}"
                info "You selected ISO: ${C_BLUE}${iso_choice}${C_RESET}"
            fi
            break
        else
            error "Invalid selection. Please try again."
        fi
    done

    # --- Step 3: Choose Boot Target (only if an ISO was selected) ---
    local BOOT_FLAG=""
    if [[ -n "$SELECTED_ISO" ]]; then
        header "Choose boot action for the selected ISO"

        local boot_prompt_options=(
            "Boot from Hard Drive (mount ISO on desktop)"
            "Boot from CD/ISO (for OS installation, etc.)"
        )

        PS3="${C_YELLOW}How should the ISO be used? ${C_RESET}"
        select boot_action in "${boot_prompt_options[@]}"; do
            if [[ "$boot_action" == "Boot from CD/ISO (for OS installation, etc.)" ]]; then
                BOOT_FLAG="--boot-from-cd"
                info "VM will attempt to boot from the ISO."
                break
            elif [[ "$boot_action" == "Boot from Hard Drive (mount ISO on desktop)" ]]; then
                BOOT_FLAG=""
                info "VM will boot from the hard drive; ISO will be available on the guest desktop."
                break
            else
                error "Invalid selection. Please try again."
            fi
        done
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
