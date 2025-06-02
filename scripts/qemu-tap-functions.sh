#!/usr/bin/env bash

#######################################
# QEMU TAP Networking Functions
# Contains functions for setting up and tearing down TAP networking for QEMU VMs.
# To be sourced by the main QEMU runner script.
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

#######################################
# Generate a random MAC address with QEMU prefix
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   MAC address string via stdout in format 52:54:00:XX:XX:XX
#######################################
generate_mac() {
    generate_mac_address
}

#######################################
# Generate TAP device name from config name
# Arguments:
#   config_base_name: Base name of config file (without .conf extension)
# Globals:
#   None
# Returns:
#   TAP interface name via stdout (format: tap_configname)
#######################################
generate_tap_name() {
    local config_base_name="$1"
    
    if [ -z "$config_base_name" ]; then
        echo "Error: Config base name is required for TAP name generation" >&2
        exit 1
    fi
    
    local sanitized_name
    sanitized_name=$(sanitize_string "$config_base_name")
    # Limit length to avoid exceeding interface name limits (IFNAMSIZ is often 16)
    echo "tap_${sanitized_name:0:10}"
}

#######################################
# Set up the network bridge
# Creates the bridge if it doesn't exist and ensures it's up
# Arguments:
#   bridge_name: Name of the bridge to create/configure
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if bridge creation or configuration fails
#######################################
setup_bridge() {
    local bridge_name="$1"
    
    if [ -z "$bridge_name" ]; then
        echo "Error: Bridge name is required" >&2
        exit 1
    fi
    
    echo "--- Network Setup (TAP) ---"
    echo "Ensuring bridge '$bridge_name' exists and is up..."
    
    if ! ip link show "$bridge_name" &> /dev/null; then
        echo "Bridge '$bridge_name' not found. Creating..."
        sudo ip link add name "$bridge_name" type bridge
        check_exit_status $? "Failed to create bridge '$bridge_name'"
        
        echo "Bringing bridge '$bridge_name' up..."
        sudo ip link set "$bridge_name" up
        check_exit_status $? "Failed to bring up bridge '$bridge_name'"
        
        echo "Bridge '$bridge_name' created and up."
    else
        # Ensure bridge is up even if it exists
        if ! ip link show "$bridge_name" | grep -q "state UP"; then
            echo "Bridge '$bridge_name' exists but is down. Bringing up..."
            sudo ip link set "$bridge_name" up
            check_exit_status $? "Failed to bring up existing bridge '$bridge_name'"
        else
            echo "Bridge '$bridge_name' already exists and is up."
        fi
    fi
    echo "---------------------------"
}

#######################################
# Set up the TAP interface for the VM
# Creates the TAP device, assigns it to the user, and adds it to the bridge
# Arguments:
#   tap_name: Name of the TAP interface to create
#   bridge_name: Name of the bridge to add the TAP interface to
#   username: Username to assign ownership of the TAP device
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if TAP setup fails at any stage
#######################################
setup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    local username="$3"
    
    # Validate arguments
    if [ -z "$tap_name" ] || [ -z "$bridge_name" ] || [ -z "$username" ]; then
        echo "Error: TAP setup requires tap_name, bridge_name, and username" >&2
        exit 1
    fi
    
    echo "--- Network Setup (TAP) ---"
    echo "Setting up TAP interface '$tap_name' for user '$username' on bridge '$bridge_name'..."
    
    # Check if TAP device already exists (maybe from a crashed previous run)
    if ip link show "$tap_name" &> /dev/null; then
        warning_log "TAP device '$tap_name' already exists. Trying to reuse/reconfigure."
        # Ensure it's down before potential deletion or reconfiguration
        sudo ip link set "$tap_name" down &> /dev/null
        # Attempt to remove from bridge just in case it's stuck
        sudo brctl delif "$bridge_name" "$tap_name" &> /dev/null || true
    fi
    
    echo "Creating TAP device '$tap_name'..."
    sudo ip tuntap add dev "$tap_name" mode tap user "$username"
    check_exit_status $? "Failed to create TAP device '$tap_name'"
    
    echo "Bringing TAP device '$tap_name' up..."
    sudo ip link set "$tap_name" up
    if [ $? -ne 0 ]; then
        echo "Error: Failed to bring up TAP device '$tap_name'" >&2
        sudo ip tuntap del dev "$tap_name" mode tap &> /dev/null || true
        exit 1
    fi
    
    echo "Adding TAP device '$tap_name' to bridge '$bridge_name'..."
    sudo brctl addif "$bridge_name" "$tap_name"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add TAP device '$tap_name' to bridge '$bridge_name'" >&2
        sudo ip link set "$tap_name" down &> /dev/null || true
        sudo ip tuntap del dev "$tap_name" mode tap &> /dev/null || true
        exit 1
    fi
    
    echo "TAP device '$tap_name' is up and added to bridge '$bridge_name'."
    echo "---------------------------"
}

#######################################
# Clean up the TAP interface
# Removes the TAP interface from the bridge and deletes it
# Called automatically by the trap set in the main script
# Arguments:
#   tap_name: Name of the TAP interface to clean up
#   bridge_name: Name of the bridge to remove the TAP interface from
# Globals:
#   None
# Returns:
#   None
#######################################
cleanup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    
    # Validate arguments
    if [ -z "$tap_name" ] || [ -z "$bridge_name" ]; then
        echo "Error: TAP cleanup requires tap_name and bridge_name" >&2
        return 1
    fi
    
    echo # Newline for clarity after QEMU exits
    echo "--- Network Cleanup (TAP) ---"
    echo "Cleaning up TAP interface '$tap_name' from bridge '$bridge_name'..."
    
    # Check if the interface exists before trying to manipulate it
    if ip link show "$tap_name" &> /dev/null; then
        echo "Removing TAP device '$tap_name' from bridge '$bridge_name'..."
        sudo brctl delif "$bridge_name" "$tap_name" 2>/dev/null || true
        
        echo "Bringing TAP device '$tap_name' down..."
        sudo ip link set "$tap_name" down 2>/dev/null || true
        
        echo "Deleting TAP device '$tap_name'..."
        sudo ip tuntap del dev "$tap_name" mode tap 2>/dev/null || true
        
        echo "TAP interface '$tap_name' cleaned up successfully."
    else
        echo "TAP device '$tap_name' not found, cleanup skipped."
    fi
    echo "---------------------------"
}