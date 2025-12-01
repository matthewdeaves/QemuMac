#!/usr/bin/env bash
#
# QemuMac Common Library - Shared utilities for all QemuMac scripts
#

# Configuration constants
SHARED_MOUNT_POINT="/tmp/qemu-shared"

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

# Downloads a file to a temporary location, verifies checksum, and returns the temp path
download_file_to_temp() {
    local url="$1"
    local md5="$2"
    local quiet="${3:-false}"
    
    local temp_file
    temp_file=$(mktemp)
    
    [[ "$quiet" != "true" ]] && info "Downloading from: ${url}"
    # Follow redirects, fail on error, show progress bar, and output to temp file
    curl --fail -L --progress-bar -o "$temp_file" "$url"
    
    if [[ -n "$md5" && "$md5" != "null" ]]; then
        info "Verifying checksum..."
        local downloaded_md5
        downloaded_md5=$(md5sum "$temp_file" | awk '{print $1}')
        if [[ "$downloaded_md5" != "$md5" ]]; then
            rm -f "$temp_file"
            die "Checksum mismatch! Expected ${md5}, got ${downloaded_md5}"
        fi
        success "Checksum verified."
    fi
    
    echo "$temp_file"
}

# Download file and place in final destination with automatic extraction
download_and_place_file() {
    local url="$1" md5="$2" dest_path="$3" filename="$4"
    
    # Ensure destination directory exists
    ensure_directory "$(dirname "$dest_path")"
    
    # Check if file already exists
    if file_exists "$dest_path"; then
        info "File already exists: $(basename "$dest_path")"
        return 0
    fi
    
    info "Downloading: $(basename "$dest_path")"
    
    # Download to temp location
    local temp_file
    temp_file=$(download_file_to_temp "$url" "$md5" "true")
    
    # Handle ZIP extraction or direct move
    if [[ "$url" == *.zip ]]; then
        info "Extracting from zip archive..."
        local temp_dir
        temp_dir=$(mktemp -d)
        unzip -q "$temp_file" -d "$temp_dir"
        mv "${temp_dir}/${filename}" "$dest_path"
        rm -rf "$temp_dir"
        rm -f "$temp_file"
    else
        mv "$temp_file" "$dest_path"
    fi
    
    success "File ready: $dest_path"
    echo "$dest_path"  # Return the final path
}

# Resolve final download path based on item type and metadata
resolve_download_path() {
    local item_type="$1" selected_key="$2" filename="$3" nice_filename="$4"
    
    local dest_path
    case "$item_type" in
        "rom")
            # Special case for main Quadra 800 ROM
            if [[ "$selected_key" == "quadra800" ]]; then
                dest_path="roms/800.ROM"
            else
                dest_path="roms/${filename}"
            fi
            ;;
        "cd"|*)
            dest_path="iso/${nice_filename}"
            ;;
    esac
    
    echo "$dest_path"
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

# Additional utility functions

command_exists() {
    command -v "$1" &>/dev/null
}

executable_exists() {
    [[ -x "$1" ]]
}

require_commands() {
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            die "Required command '${cmd}' is not installed."
        fi
    done
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif file_exists "/etc/os-release"; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            echo "ubuntu"
        else
            echo "unsupported"
        fi
    else
        echo "unsupported"
    fi
}

ensure_directory() {
    local dir="$1"
    local msg="${2:-Creating directory: $dir}"
    
    if ! dir_exists "$dir"; then
        info "$msg"
        mkdir -p "$dir" || die "Failed to create directory: $dir"
    fi
}

# Menu utility functions for consistent user interaction

# Simple universal menu - handles all cases
# Usage: result=$(menu "prompt" options...)
# Returns: selected option string, or exits on quit
menu() {
    local prompt="$1"
    shift
    local options=("$@")

    # Always add Quit if not present
    [[ ! " ${options[*]} " =~ " Quit " ]] && options+=("Quit")

    # Set COLUMNS to 1 to force one option per line in select menu
    local COLUMNS=1
    PS3="${C_YELLOW}${prompt} ${C_RESET}"
    select choice in "${options[@]}"; do
        case "$choice" in
            "Quit") info "Exiting"; echo "QUIT"; return 0 ;;
            "Back"*) echo "BACK"; return 0 ;;
            "None"*) echo "NONE"; return 0 ;;
            "") error "Invalid selection" ;;
            *) echo "$choice"; return 0 ;;
        esac
    done
}

# Helper for file-based selections (returns index)
menu_files() {
    local prompt="$1"
    shift
    local files=("$@")
    
    local options
    for file in "${files[@]}"; do
        options+=("$(basename "$(dirname "$file")")")
    done
    
    local choice
    choice=$(menu "$prompt" "${options[@]}")
    
    # Return index of selected item
    for i in "${!options[@]}"; do
        [[ "${options[$i]}" == "$choice" ]] && echo "$i" && return
    done
}

# File discovery utility functions

# Find files and extract display names for menus
# Sets global arrays FOUND_FILES and FOUND_NAMES
find_files_with_names() {
    local find_path="$1" pattern="$2" name_extractor="$3" 
    local extra_args="${4:-}"
    
    local files=()
    if [[ -n "$extra_args" ]]; then
        mapfile -t files < <(find "$find_path" $extra_args -name "$pattern" | sort)
    else
        mapfile -t files < <(find "$find_path" -name "$pattern" | sort)
    fi
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    local names=()
    case "$name_extractor" in
        "parent_dir") 
            for f in "${files[@]}"; do names+=("$(basename "$(dirname "$f")")"); done ;;
        "basename"|*)
            for f in "${files[@]}"; do names+=("$(basename "$f")"); done ;;
    esac
    
    # Return both arrays via global variables (bash limitation)
    FOUND_FILES=("${files[@]}")
    FOUND_NAMES=("${names[@]}")
    return 0
}

# Simple binary choice with default
ask_choice() {
    local prompt="$1" option1="$2" option2="$3" default="${4:-1}"
    
    echo >&2
    echo "${C_YELLOW}${prompt}${C_RESET}" >&2
    echo "  1) ${option1}" >&2
    echo "  2) ${option2}" >&2
    read -rp "Choice [1-2]: " choice
    
    case "${choice:-$default}" in
        1) echo "1" ;;
        2) echo "2" ;;
        *) die "Invalid choice. Please enter 1 or 2." ;;
    esac
}

# Database utility functions for JSON handling

# Load database once, cache in variable  
db_load() {
    local default_file="$1"
    local custom_file="$2"
    
    require_file "$default_file"
    
    if file_exists "$custom_file"; then
        jq -s '.[0] * .[1]' "$default_file" "$custom_file"
    else
        cat "$default_file"
    fi
}

# Get all categories (merged, sorted, unique)
db_categories() {
    local db="$1"
    echo "$db" | jq -r '[(.cds, .roms) | .[] | .category // "Miscellaneous"] | unique | sort[]'
}

# Get items for category (returns "key:name:description:type" format)
db_items() {
    local db="$1"
    local category="$2"

    echo "$db" | jq -r --arg cat "$category" '
        [
            (.cds | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and (.value.category == null or .value.category == ""))) | "\(.key):\(.value.name):\(.value.description // ""):cd"),
            (.roms | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and (.value.category == null or .value.category == ""))) | "\(.key):\(.value.name):\(.value.description // ""):rom")
        ] | sort[]'
}

# Get item details (single call gets everything)
db_item() {
    local db="$1" 
    local key="$2"
    local type="$3"
    
    local path
    [[ "$type" == "cd" ]] && path=".cds" || path=".roms"
    
    echo "$db" | jq -r --arg key "$key" "${path}[\$key]"
}
