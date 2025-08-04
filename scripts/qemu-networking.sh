#!/usr/bin/env bash

#######################################
# QEMU Networking Management Module
# Handles setup and configuration of different networking modes
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

# --- Network Setup Functions ---

#######################################
# Setup TAP networking with enhanced error handling
# Arguments:
#   None
# Globals:
#   TAP_FUNCTIONS_SCRIPT, BRIDGE_NAME, QEMU_TAP_IFACE, QEMU_MAC_ADDR
#   CONFIG_NAME, TAP_DEV_NAME, MAC_ADDRESS
# Returns:
#   None
# Exits:
#   1 if TAP setup fails
#######################################
setup_tap_networking() {
    info_log "Setting up TAP networking..."
    
    # Check for required TAP functions script
    validate_file_exists "$TAP_FUNCTIONS_SCRIPT" "TAP functions script" || exit 1
    
    # Source the functions into the current script's environment
    # shellcheck source=qemu-tap-functions.sh
    source "$TAP_FUNCTIONS_SCRIPT"
    check_exit_status $? "Failed to source TAP functions script '$TAP_FUNCTIONS_SCRIPT'"
    
    # Check for commands required ONLY for TAP mode
    check_command "ip" "iproute2" || exit 1
    check_command "brctl" "bridge-utils" || exit 1
    check_command "sudo" "sudo" || exit 1
    
    # Generate TAP device name if not specified in config
    if [ -z "${QEMU_TAP_IFACE:-}" ]; then
        TAP_DEV_NAME=$(generate_tap_name "$CONFIG_NAME")
        info_log "QEMU_TAP_IFACE not set in config, generated TAP name: $TAP_DEV_NAME"
    else
        TAP_DEV_NAME="$QEMU_TAP_IFACE"
        info_log "Using TAP interface name from config: $TAP_DEV_NAME"
    fi
    
    # Generate MAC address if not specified
    if [ -z "${QEMU_MAC_ADDR:-}" ]; then
        MAC_ADDRESS=$(generate_mac_address)
        info_log "QEMU_MAC_ADDR not set in config, generated MAC: $MAC_ADDRESS"
    else
        MAC_ADDRESS="$QEMU_MAC_ADDR"
        info_log "Using MAC address from config: $MAC_ADDRESS"
    fi
    
    # Setup bridge first
    setup_bridge "$BRIDGE_NAME"
    
    # Setup TAP interface for this VM
    setup_tap "$TAP_DEV_NAME" "$BRIDGE_NAME" "$(whoami)"
    
    # Set trap to clean up TAP interface on exit
    # shellcheck disable=SC2064
    trap "cleanup_tap '$TAP_DEV_NAME' '$BRIDGE_NAME'" EXIT SIGINT SIGTERM
    info_log "TAP networking enabled. Cleanup trap set."
}

#######################################
# Setup User Mode networking
# Arguments:
#   None
# Globals:
#   QEMU_USER_SMB_DIR
# Returns:
#   None
#######################################
setup_user_networking() {
    info_log "User Mode networking enabled. No host-side setup or cleanup needed."
    
    if [ -n "${QEMU_USER_SMB_DIR:-}" ]; then
        if [ -d "$QEMU_USER_SMB_DIR" ]; then
            info_log "User mode SMB share configured for directory: $QEMU_USER_SMB_DIR"
        else
            warning_log "QEMU_USER_SMB_DIR specified ('$QEMU_USER_SMB_DIR') but directory does not exist. SMB share will likely fail."
        fi
    fi
}

#######################################
# Setup Passt networking
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if passt command not found
#######################################
setup_passt_networking() {
    info_log "Setting up Passt networking..."
    check_command "passt" "passt package (see https://passt.top/)" || exit 1
    
    # Create socket path for passt
    local socket_dir="/tmp/qemu-passt-$$"
    local socket_path="$socket_dir/passt.socket"
    
    # Create socket directory
    mkdir -p "$socket_dir" || {
        echo "Error: Failed to create passt socket directory '$socket_dir'" >&2
        exit 1
    }
    
    # Start passt daemon with socket
    info_log "Starting passt daemon with socket: $socket_path"
    passt --socket "$socket_path" --foreground &
    local passt_pid=$!
    
    # Wait for socket to be created
    local timeout=5
    while [ $timeout -gt 0 ] && [ ! -S "$socket_path" ]; do
        sleep 1
        ((timeout--))
    done
    
    if [ ! -S "$socket_path" ]; then
        echo "Error: Passt socket not created after 5 seconds" >&2
        kill $passt_pid 2>/dev/null || true
        exit 1
    fi
    
    # Export variables for command building
    export PASST_SOCKET_PATH="$socket_path"
    export PASST_PID="$passt_pid"
    export PASST_SOCKET_DIR="$socket_dir"
    
    # Set cleanup trap for passt
    # shellcheck disable=SC2064
    trap "cleanup_passt '$passt_pid' '$socket_dir'" EXIT SIGINT SIGTERM
    
    info_log "Passt daemon started successfully (PID: $passt_pid)"
}

#######################################
# Clean up passt daemon and socket directory
# Arguments:
#   passt_pid: Process ID of passt daemon
#   socket_dir: Directory containing passt socket
# Globals:
#   None
# Returns:
#   None
#######################################
cleanup_passt() {
    local passt_pid="$1"
    local socket_dir="$2"
    
    if [ -n "$passt_pid" ]; then
        info_log "Stopping passt daemon (PID: $passt_pid)..."
        kill "$passt_pid" 2>/dev/null || true
        wait "$passt_pid" 2>/dev/null || true
    fi
    
    if [ -n "$socket_dir" ] && [ -d "$socket_dir" ]; then
        info_log "Cleaning up passt socket directory: $socket_dir"
        rm -rf "$socket_dir"
    fi
}

#######################################
# Setup networking based on selected type
# Arguments:
#   network_type: Type of networking (tap, user, passt)
# Globals:
#   Various networking globals depending on type
# Returns:
#   None
# Exits:
#   1 if networking setup fails
#######################################
setup_networking() {
    local network_type="$1"
    
    # Validate network type
    case "$network_type" in
        "tap")
            setup_tap_networking
            ;;
        "user")
            setup_user_networking
            ;;
        "passt")
            setup_passt_networking
            ;;
        *)
            echo "Error: Invalid network type '$network_type'. Supported types: tap, user, passt" >&2
            exit 1
            ;;
    esac
}

#######################################
# Build network arguments for QEMU command
# Arguments:
#   network_type: Type of networking (tap, user, passt)
#   qemu_args_var: Name of array variable to append to
# Globals:
#   TAP_DEV_NAME, MAC_ADDRESS, QEMU_USER_SMB_DIR, BRIDGE_NAME
#   QEMU_NETWORK_DEVICE (optional, defaults by architecture)
# Returns:
#   None (modifies array via nameref)
#######################################
build_network_args() {
    local network_type="$1"
    local -n qemu_args_ref=$2
    
    # Determine network device model based on architecture
    local network_device
    if [ -n "${QEMU_NETWORK_DEVICE:-}" ]; then
        network_device="$QEMU_NETWORK_DEVICE"
    elif [ "${ARCH:-}" = "ppc" ]; then
        network_device="rtl8139"  # PowerPC default
    else
        network_device="dp83932"  # 68k default
    fi
    
    case "$network_type" in
        "tap")
            echo "Network: TAP device '$TAP_DEV_NAME' on bridge '$BRIDGE_NAME', MAC: $MAC_ADDRESS, Device: $network_device"
            qemu_args_ref+=(
                "-netdev" "tap,id=net0,ifname=$TAP_DEV_NAME,script=no,downscript=no"
                "-net" "nic,model=$network_device,netdev=net0,macaddr=$MAC_ADDRESS"
            )
            ;;
        "user")
            echo "Network: User Mode Networking, Device: $network_device"
            local user_net_opts="user"
            if [ -n "${QEMU_USER_SMB_DIR:-}" ] && [ -d "$QEMU_USER_SMB_DIR" ]; then
                user_net_opts+=",smb=$QEMU_USER_SMB_DIR"
                echo "SMB share: $QEMU_USER_SMB_DIR"
            elif [ -n "${QEMU_USER_SMB_DIR:-}" ]; then
                warning_log "SMB directory '$QEMU_USER_SMB_DIR' not found, skipping SMB share."
            fi
            qemu_args_ref+=(
                "-net" "nic,model=$network_device"
                "-net" "$user_net_opts"
            )
            ;;
        "passt")
            echo "Network: Passt backend (socket: ${PASST_SOCKET_PATH:-unknown}), Device: $network_device"
            qemu_args_ref+=(
                "-netdev" "stream,id=net0,server=off,addr.type=unix,addr.path=${PASST_SOCKET_PATH}"
                "-net" "nic,model=$network_device,netdev=net0"
            )
            ;;
        *)
            echo "Error: Unknown network type '$network_type' in build_network_args" >&2
            exit 1
            ;;
    esac
}