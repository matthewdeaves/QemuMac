#!/bin/bash
#
# QemuMac Common Library - Shared utilities for all QemuMac scripts
#

# Color constants for consistent output
C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_RESET=$(tput sgr0)

# Helper functions for colored output
info() { echo -e "${C_YELLOW}Info: ${1}${C_RESET}" >&2; }
success() { echo -e "${C_GREEN}Success: ${1}${C_RESET}" >&2; }
error() { echo -e "${C_RED}Error: ${1}${C_RESET}" >&2; }
header() { echo -e "\n${C_BLUE}--- ${1} ---${C_RESET}" >&2; }

# Utility function for consistent error handling
die() {
    error "$1"
    exit "${2:-1}"
}

# File validation functions
require_file() {
    local file="$1"
    local msg="${2:-File not found: $file}"
    [[ -f "$file" ]] || die "$msg"
}

require_executable() {
    local file="$1"
    local msg="${2:-Executable not found: $file}"
    [[ -x "$file" ]] || die "$msg"
}

require_directory() {
    local dir="$1"
    local msg="${2:-Directory not found: $dir}"
    [[ -d "$dir" ]] || die "$msg"
}

file_exists() {
    [[ -f "$1" ]]
}

dir_exists() {
    [[ -d "$1" ]]
}

# Menu utility functions for consistent user interaction

# Basic menu with simple string options
# Usage: selected=$(show_menu "Choose option:" option1 option2 option3)
# Returns: selected option string, or exits on "Quit"
show_menu() {
    local prompt="$1"
    shift
    local options=("$@")
    
    # Always add Quit option if not present
    local has_quit=false
    for opt in "${options[@]}"; do
        [[ "$opt" == "Quit" ]] && has_quit=true
    done
    [[ "$has_quit" == false ]] && options+=("Quit")
    
    PS3="${C_YELLOW}${prompt} ${C_RESET}"
    select choice in "${options[@]}"; do
        case "$choice" in
            "Quit") info "Exiting"; exit 0 ;;
            "") error "Invalid selection" ;;
            *) echo "$choice"; return 0 ;;
        esac
    done
}

# Enhanced menu that returns index into source array  
# Usage: idx=$(show_indexed_menu "Choose:" options_array source_array offset)
# Returns: index into source_array, -2 for special first option, -1 for back, or exits on quit
show_indexed_menu() {
    local prompt="$1"
    local -n options_ref="$2"
    local -n source_array_ref="$3"
    local offset="${4:-0}"
    
    PS3="${C_YELLOW}${prompt} ${C_RESET}"
    select choice in "${options_ref[@]}"; do
        case "$choice" in
            "Quit") info "Exiting"; exit 0 ;;
            "Back to Categories"|"Back") echo "-1"; return 0 ;;
            "None"*) echo "-2"; return 0 ;;  # Special handling for "None" options
            "") error "Invalid selection" ;;
            *)
                if [[ -n "$choice" ]]; then
                    local index=$((REPLY - 1 - offset))
                    echo "$index"; return 0
                fi
                ;;
        esac
    done
}