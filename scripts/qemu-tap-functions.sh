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
#   bridge_ip: The IP address to assign to the bridge (e.g., 192.168.99.1/24)
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if bridge creation or configuration fails
#######################################
setup_bridge() {
    local bridge_name="$1"
    local bridge_ip="$2"
    
    if [ -z "$bridge_name" ] || [ -z "$bridge_ip" ]; then
        echo "Error: Bridge name and IP address are required" >&2
        exit 1
    fi
    
    echo "--- Network Setup (TAP) ---"
    echo "Ensuring bridge '$bridge_name' exists and is up..."
    
    if ! ip link show "$bridge_name" &> /dev/null; then
        echo "Bridge '$bridge_name' not found. Creating..."
        sudo ip link add name "$bridge_name" type bridge
        check_exit_status $? "Failed to create bridge '$bridge_name'"
    fi

    echo "Assigning IP $bridge_ip to bridge '$bridge_name'..."
    sudo ip addr flush dev "$bridge_name"
    sudo ip addr add "$bridge_ip" dev "$bridge_name"
    check_exit_status $? "Failed to assign IP to bridge '$bridge_name'"

    echo "Bringing bridge '$bridge_name' up..."
    sudo ip link set "$bridge_name" up
    check_exit_status $? "Failed to bring up bridge '$bridge_name'"

    echo "Bridge '$bridge_name' is up with IP $bridge_ip."
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

#######################################
# Configure host for internet sharing (NAT) and DHCP for a bridge
# Arguments:
#   bridge_name: The name of the bridge interface
#   dhcp_range: The DHCP address range for dnsmasq (e.g., 192.168.99.100,192.168.99.200)
# Globals:
#   None
# Returns:
#   A string containing the original ip_forward value and dnsmasq PID, separated by a semicolon.
# Exits:
#   1 if setup fails
#######################################
setup_nat_and_dhcp_for_bridge() {
    local bridge_name="$1"
    local dhcp_range="$2"

    info_log "Configuring host for internet sharing (NAT) and DHCP..."
    check_command "dnsmasq" "dnsmasq" || exit 1

    local primary_iface
    primary_iface=$(ip route show default | awk '/default/ {print $5}' | head -n1)

    if [ -z "$primary_iface" ]; then
        warning_log "Could not automatically determine primary network interface. Internet sharing will not be enabled."
        echo "no_change;"
        return
    fi

    info_log "Detected primary network interface: $primary_iface"

    # Enable IP forwarding and store original value
    local original_ip_forward
    original_ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$original_ip_forward" -eq 0 ]; then
        info_log "Enabling kernel IP forwarding..."
        sudo sysctl -w net.ipv4.ip_forward=1
    else
        info_log "Kernel IP forwarding is already enabled."
    fi

    # Add iptables rule for NAT/Masquerade
    info_log "Adding iptables NAT rule..."
    sudo iptables -t nat -A POSTROUTING -o "$primary_iface" -j MASQUERADE
    check_exit_status $? "Failed to add iptables NAT rule."

    # Start dnsmasq for DHCP
    info_log "Starting dnsmasq for DHCP on bridge '$bridge_name'..."
    local dnsmasq_pid_file
    dnsmasq_pid_file="/tmp/qemu-dnsmasq-$$.pid"
    sudo dnsmasq 
        --interface="$bridge_name" 
        --bind-interfaces 
        --dhcp-range="$dhcp_range" 
        --except-interface=lo 
        --pid-file="$dnsmasq_pid_file"
    check_exit_status $? "Failed to start dnsmasq."
    local dnsmasq_pid
    dnsmasq_pid=$(cat "$dnsmasq_pid_file")
    info_log "dnsmasq started with PID $dnsmasq_pid."

    # Return original value and PID so they can be used for cleanup
    echo "$original_ip_forward;$dnsmasq_pid"
}

#######################################
# Clean up NAT rules, IP forwarding, and dnsmasq
# Arguments:
#   cleanup_info: A string containing the original ip_forward value and dnsmasq PID
# Globals:
#   None
# Returns:
#   None
#######################################
cleanup_nat_and_dhcp() {
    local cleanup_info="$1"
    local original_ip_forward_val
    local dnsmasq_pid
    original_ip_forward_val=$(echo "$cleanup_info" | cut -d';' -f1)
    dnsmasq_pid=$(echo "$cleanup_info" | cut -d';' -f2)

    # Stop dnsmasq
    if [ -n "$dnsmasq_pid" ]; then
        info_log "--- Network Cleanup (DHCP) ---"
        info_log "Stopping dnsmasq (PID: $dnsmasq_pid)..."
        sudo kill "$dnsmasq_pid"
        rm -f "/tmp/qemu-dnsmasq-$$.pid"
        echo "---------------------------"
    fi
    
    # Don't do anything else if no change was made
    if [ "$original_ip_forward_val" = "no_change" ]; then
        return
    fi

    info_log "--- Network Cleanup (NAT) ---"
    info_log "Cleaning up host internet sharing (NAT)..."

    local primary_iface
    primary_iface=$(ip route show default | awk '/default/ {print $5}' | head -n1)

    if [ -n "$primary_iface" ]; then
        info_log "Removing iptables NAT rule for interface '$primary_iface'..."
        if sudo iptables-save -t nat | grep -q -- "-A POSTROUTING -o $primary_iface -j MASQUERADE"; then
            sudo iptables -t nat -D POSTROUTING -o "$primary_iface" -j MASQUERADE
        else
            warning_log "NAT rule not found, skipping removal."
        fi
    fi

    # Restore original IP forwarding setting
    if [ -n "$original_ip_forward_val" ] && [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "$original_ip_forward_val" ]; then
        info_log "Restoring net.ipv4.ip_forward to its original value ('$original_ip_forward_val')..."
        sudo sysctl -w net.ipv4.ip_forward="$original_ip_forward_val"
    fi
    echo "---------------------------"
}