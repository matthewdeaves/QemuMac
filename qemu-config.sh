#!/usr/bin/env bash

#######################################
# QEMU Configuration Management Module
# Handles loading, validation, and management of QEMU configuration files
#######################################

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-utils.sh
source "$SCRIPT_DIR/qemu-utils.sh"

#######################################
# Enhanced configuration schema validation specific to TAP networking
# Arguments:
#   network_type: Type of networking being used (tap, user, passt)
# Globals:
#   BRIDGE_NAME, CONFIG_FILE
# Returns:
#   None
# Exits:
#   1 if TAP-specific validation fails
#######################################
validate_network_config() {
    local network_type="$1"
    
    # Check BRIDGE_NAME only if TAP is selected
    if [ "$network_type" = "tap" ] && [ -z "${BRIDGE_NAME:-}" ]; then
        echo "Error: Config file $CONFIG_FILE is missing required variable for TAP mode: BRIDGE_NAME" >&2
        exit 1
    fi
}

#######################################
# Load and validate complete QEMU configuration
# Arguments:
#   config_file: Path to configuration file
#   network_type: Type of networking to validate for
# Globals:
#   Sources all configuration variables
# Returns:
#   None
# Exits:
#   1 if configuration loading or validation fails
#######################################
load_and_validate_config() {
    local config_file="$1"
    local network_type="$2"
    
    # Use shared utility for basic config loading
    load_qemu_config "$config_file"
    
    # Additional validation specific to networking
    validate_network_config "$network_type"
    
    # Set defaults for optional variables
    QEMU_HDD_SIZE="${QEMU_HDD_SIZE:-$DEFAULT_HDD_SIZE}"
    QEMU_SHARED_HDD_SIZE="${QEMU_SHARED_HDD_SIZE:-$DEFAULT_SHARED_HDD_SIZE}"
    BRIDGE_NAME="${BRIDGE_NAME:-$DEFAULT_BRIDGE_NAME}"
    
    debug_log "Configuration loaded and validated successfully"
    debug_log "Config name: ${CONFIG_NAME:-unknown}"
    debug_log "Machine: ${QEMU_MACHINE:-unknown}, RAM: ${QEMU_RAM:-unknown}MB"
}