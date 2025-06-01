#!/usr/bin/env bash

#######################################
# QEMU Display Management Module
# Handles display type detection and configuration
#######################################

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=qemu-utils.sh
source "$SCRIPT_DIR/qemu-utils.sh"

#######################################
# Determine the display type to use based on system
# Arguments:
#   display_type_override: Optional display type override (can be empty)
# Globals:
#   OSTYPE
# Returns:
#   Display type via stdout
#######################################
determine_display_type() {
    local display_type_override="$1"
    
    if [ -n "$display_type_override" ]; then
        echo "$display_type_override"
        return 0
    fi
    
    # Auto-detect based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info_log "Detected macOS, using 'cocoa' display. Use -d to override."
        echo "cocoa"
    else
        info_log "Defaulting to 'sdl' display on this system. Use -d to override (e.g., -d gtk)."
        echo "sdl"
    fi
}

#######################################
# Validate display type is supported
# Arguments:
#   display_type: Display type to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_display_type() {
    local display_type="$1"
    local supported_types=("sdl" "gtk" "cocoa" "vnc" "none")
    
    for supported in "${supported_types[@]}"; do
        if [ "$display_type" = "$supported" ]; then
            return 0
        fi
    done
    
    echo "Error: Unsupported display type '$display_type'" >&2
    echo "Supported types: ${supported_types[*]}" >&2
    return 1
}