#!/usr/bin/env bash

#######################################
# QEMU Configuration Management Module
# Handles loading, validation, and management of QEMU configuration files
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

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
# Load and validate PPC QEMU configuration
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
load_and_validate_ppc_config() {
    local config_file="$1"
    local network_type="$2"
    
    validate_file_exists "$config_file" "Configuration file" || exit 1
    
    echo "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file"
    check_exit_status $? "Failed to source configuration file '$config_file'"
    
    # Extract config name for potential use
    CONFIG_NAME=$(basename "$config_file" .conf)
    
    # PPC-specific validation (no ROM/PRAM required)
    validate_ppc_config_schema "$config_file"
    
    # Perform network-specific validation
    validate_network_config "$network_type"
    
    # Set defaults for optional variables
    QEMU_HDD_SIZE="${QEMU_HDD_SIZE:-2G}"
    QEMU_SHARED_HDD_SIZE="${QEMU_SHARED_HDD_SIZE:-200M}" 
}

#######################################
# Validate PPC configuration against schema (different from 68k)
# Arguments:
#   config_file: Path to configuration file (for error messages)
# Globals:
#   Reads all configuration variables
# Returns:
#   None
# Exits:
#   1 if required variables are missing
#######################################
validate_ppc_config_schema() {
    local config_file="$1"
    local missing_vars=()
    
    # PPC-specific required variables (no ROM/PRAM needed)
    local -A PPC_REQUIRED_VARS=(
        ["QEMU_MACHINE"]="QEMU machine type (e.g., mac99, g3beige)"
        ["QEMU_HDD"]="Hard disk image path"
        ["QEMU_SHARED_HDD"]="Shared disk image path"
        ["QEMU_RAM"]="RAM amount in MB"
        ["QEMU_GRAPHICS"]="Graphics settings (e.g., 1024x768x8)"
        ["ARCH"]="Architecture (must be 'ppc')"
    )
    
    # Check required variables
    for var in "${!PPC_REQUIRED_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var (${PPC_REQUIRED_VARS[$var]})")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "Error: Config file $config_file is missing required PPC variables:" >&2
        printf "  - %s\n" "${missing_vars[@]}" >&2
        exit 1
    fi
    
    # Validate architecture is PPC
    if [ "${ARCH:-}" != "ppc" ]; then
        echo "Error: Config file $config_file has invalid architecture. Expected 'ppc', got '${ARCH:-}'" >&2
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