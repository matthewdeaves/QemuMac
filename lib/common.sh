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