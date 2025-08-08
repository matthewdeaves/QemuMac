#!/usr/bin/env bash

#######################################
# Simplified QEMU Utilities
# Essential functions only - reduced from 1,206 lines
#######################################

# Basic error handling (no strict mode)
set -eo pipefail

#######################################
# Check if a command exists
#######################################
check_command() {
    local command_name="$1"
    if ! command -v "$command_name" &> /dev/null; then
        echo "Error: Command '$command_name' not found." >&2
        return 1
    fi
    return 0
}

#######################################
# Validate file exists and is readable
#######################################
validate_file_exists() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [ ! -f "$file_path" ]; then
        echo "Error: $description not found: $file_path" >&2
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "Error: $description is not readable: $file_path" >&2
        return 1
    fi
    
    return 0
}

#######################################
# Create directory with error handling
#######################################
ensure_directory() {
    local dir_path="$1"
    
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path" || {
            echo "Error: Failed to create directory '$dir_path'" >&2
            return 1
        }
    fi
}

#######################################
# Simple debug output
#######################################
debug_log() {
    local message="$1"
    if [ "${DEBUG_MODE:-false}" = true ]; then
        echo "[DEBUG] $message" >&2
    fi
}

#######################################
# Simple info message
#######################################
info_log() {
    local message="$1"
    echo "Info: $message" >&2
}

#######################################
# Simple warning message  
#######################################
warning_log() {
    local message="$1"
    echo "Warning: $message" >&2
}

# Simplified initialization - no complex error trapping
readonly QEMU_UTILS_INITIALIZED=true