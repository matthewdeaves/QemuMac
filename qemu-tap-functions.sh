#!/bin/bash
# qemu-tap-functions.sh
# Contains functions for setting up and tearing down TAP networking for QEMU VMs.
# To be sourced by the main QEMU runner script.

# Function to generate a random MAC address if not provided
generate_mac() {
    local hexchars="0123456789ABCDEF"
    # QEMU MAC prefix 52:54:00
    echo "52:54:00:$(for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/\1:/g' -e 's/:$//')"
}

# Function to set up the network bridge
# Takes bridge name as argument
setup_bridge() {
    local bridge="$1"
    echo "--- Network Setup (TAP) ---"
    echo "Ensuring bridge '$bridge' exists and is up..."
    if ! ip link show "$bridge" &> /dev/null; then
        echo "Bridge '$bridge' not found. Creating..."
        sudo ip link add name "$bridge" type bridge
        if [ $? -ne 0 ]; then echo "Error: Failed to create bridge '$bridge'."; exit 1; fi
        echo "Bringing bridge '$bridge' up..."
        sudo ip link set "$bridge" up
        if [ $? -ne 0 ]; then echo "Error: Failed to bring up bridge '$bridge'."; exit 1; fi
        echo "Bridge '$bridge' created and up."
    else
        # Ensure bridge is up even if it exists
        if ! ip link show "$bridge" | grep -q "state UP"; then
             echo "Bridge '$bridge' exists but is down. Bringing up..."
             sudo ip link set "$bridge" up
             if [ $? -ne 0 ]; then echo "Error: Failed to bring up bridge '$bridge'."; exit 1; fi
        else
             echo "Bridge '$bridge' already exists and is up."
        fi
    fi
    echo "---------------------------"
}

# Function to set up the TAP interface for the VM
# Takes TAP name, Bridge name, and User as arguments
setup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    local current_user="$3" # Pass user explicitly

    echo "--- Network Setup (TAP) ---"
    echo "Setting up TAP interface '$tap_name' for user '$current_user' on bridge '$bridge_name'..."

    # Check if TAP device already exists (maybe from a crashed previous run)
    if ip link show "$tap_name" &> /dev/null; then
        echo "Warning: TAP device '$tap_name' already exists. Trying to reuse/reconfigure."
        # Ensure it's down before potential deletion or reconfiguration
        sudo ip link set "$tap_name" down &> /dev/null
        # Attempt to remove from bridge just in case it's stuck
        sudo brctl delif "$bridge_name" "$tap_name" &> /dev/null
    fi

    echo "Creating TAP device '$tap_name'..."
    sudo ip tuntap add dev "$tap_name" mode tap user "$current_user"
    if [ $? -ne 0 ]; then echo "Error: Failed to create TAP device '$tap_name'."; exit 1; fi

    echo "Bringing TAP device '$tap_name' up..."
    sudo ip link set "$tap_name" up
    if [ $? -ne 0 ]; then echo "Error: Failed to bring up TAP device '$tap_name'."; sudo ip tuntap del dev "$tap_name" mode tap; exit 1; fi

    echo "Adding TAP device '$tap_name' to bridge '$bridge_name'..."
    sudo brctl addif "$bridge_name" "$tap_name"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to add TAP device '$tap_name' to bridge '$bridge_name'."
        sudo ip link set "$tap_name" down
        sudo ip tuntap del dev "$tap_name" mode tap
        exit 1
    fi

    echo "TAP device '$tap_name' is up and added to bridge '$bridge_name'."
    echo "---------------------------"
}

# Function to clean up the TAP interface
# Takes TAP name and Bridge name as arguments
cleanup_tap() {
    local tap_name="$1"
    local bridge_name="$2"
    echo # Newline for clarity after QEMU exits
    echo "--- Network Cleanup (TAP) ---"
    echo "Cleaning up TAP interface '$tap_name' from bridge '$bridge_name'..."

    # Check if the interface exists before trying to manipulate it
    if ip link show "$tap_name" &> /dev/null; then
        echo "Removing TAP device '$tap_name' from bridge '$bridge_name'..."
        sudo brctl delif "$bridge_name" "$tap_name"
        # Don't exit on error here, proceed to bring down and delete

        echo "Bringing TAP device '$tap_name' down..."
        sudo ip link set "$tap_name" down

        echo "Deleting TAP device '$tap_name'..."
        sudo ip tuntap del dev "$tap_name" mode tap
    else
        echo "TAP device '$tap_name' not found, cleanup skipped."
    fi
    echo "---------------------------"
}

# --- TAP Specific Variable Generation ---
# These functions might be called by the main script *if* TAP mode is selected
# and config values are missing.

# Function to generate TAP device name if not provided in config
# Takes config file base name as argument
generate_tap_name() {
    local conf_base_name="$1"
    # Sanitize config file name for use as part of tap name
    local sanitized_name=$(echo "$conf_base_name" | sed 's/[^a-zA-Z0-9]//g')
    # Limit length to avoid exceeding interface name limits (IFNAMSIZ is often 16)
    echo "tap_${sanitized_name:0:10}"
}

# Note: generate_mac is already defined above
