#!/usr/bin/env bash
#
# QemuMac Common Library - Shared utilities for all QemuMac scripts
#

# Configuration constants. Consumed by the scripts that source this library,
# which shellcheck analyses separately - hence the directive.
# shellcheck disable=SC2034
SHARED_MOUNT_POINT="/tmp/qemu-shared"
# shellcheck disable=SC2034
DEFAULT_SHARED_DISK="shared/shared-disk.img"

# Color constants for consistent output (gracefully handle missing terminal)
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]]; then
    C_RED=$(tput setaf 1 2>/dev/null || echo "")
    C_GREEN=$(tput setaf 2 2>/dev/null || echo "")
    C_YELLOW=$(tput setaf 3 2>/dev/null || echo "")
    C_BLUE=$(tput setaf 4 2>/dev/null || echo "")
    C_RESET=$(tput sgr0 2>/dev/null || echo "")
else
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_RESET=""
fi

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

# Compute an MD5 digest. Linux/coreutils has md5sum, BSD/macOS has md5.
# Recent macOS ships both; older macOS ships only md5.
compute_md5() {
    if command_exists md5sum; then
        md5sum "$1" | awk '{print $1}'
    elif command_exists md5; then
        md5 -q "$1"
    else
        return 1
    fi
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
    # Checked explicitly: run-mac.sh does not use `set -e`, so an unchecked
    # failure here would install a truncated/empty file as if it were valid.
    # --retry covers transient failures (timeouts and 5xx). archive.org
    # intermittently answers 500 under load, and without this a single blip
    # aborts an install that would have worked on a second attempt.
    if ! curl --fail -L --progress-bar --retry 3 --retry-delay 2 -o "$temp_file" "$url"; then
        rm -f "$temp_file"
        die "Download failed: ${url}"
    fi

    if [[ -n "$md5" && "$md5" != "null" ]]; then
        info "Verifying checksum..."
        local downloaded_md5
        if downloaded_md5=$(compute_md5 "$temp_file"); then
            if [[ "$downloaded_md5" != "$md5" ]]; then
                rm -f "$temp_file"
                die "Checksum mismatch! Expected ${md5}, got ${downloaded_md5}"
            fi
            success "Checksum verified."
        else
            error "No md5sum or md5 command found - SKIPPING checksum verification"
        fi
    else
        # Say so rather than skipping quietly: the database entry has no
        # checksum, so a truncated or tampered download cannot be detected.
        # Printing the digest lets the user contribute one back.
        error "No checksum in the database for this item - integrity NOT verified"
        local actual
        if actual=$(compute_md5 "$temp_file"); then
            info "Computed md5: ${actual}"
        fi
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

    # download_file_to_temp runs in a command substitution, so its die() only
    # exits that subshell - the status has to be checked here or a failed
    # download would fall through and "install" an empty file.
    local temp_file
    temp_file=$(download_file_to_temp "$url" "$md5" "true") \
        || die "Download failed: $(basename "$dest_path")"
    [[ -s "$temp_file" ]] || die "Download failed: $(basename "$dest_path") is empty"

    # Handle ZIP extraction or direct move. Every step is checked: callers rely
    # on a non-zero exit (or a die) to mean "nothing was installed". Returning
    # success with no file at dest_path would let run-mac.sh create the disk
    # image anyway, and the VM would be stranded on a blank drive.
    if [[ "$url" == *.zip ]]; then
        info "Extracting from zip archive..."
        local temp_dir
        temp_dir=$(mktemp -d)

        if ! unzip -q "$temp_file" -d "$temp_dir"; then
            rm -rf "$temp_dir"; rm -f "$temp_file"
            die "Failed to extract archive for $(basename "$dest_path")"
        fi

        # The database's `filename` is the path *inside* the archive. If it
        # does not match, say so and list what is actually there - silently
        # succeeding here is what strands a VM.
        if [[ ! -f "${temp_dir}/${filename}" ]]; then
            error "Archive does not contain '${filename}'. It holds:"
            (cd "$temp_dir" && find . -type f | sed 's|^\./|  |') >&2
            rm -rf "$temp_dir"; rm -f "$temp_file"
            die "Cannot install $(basename "$dest_path") - fix 'filename' in the software database"
        fi

        mv "${temp_dir}/${filename}" "$dest_path" || {
            rm -rf "$temp_dir"; rm -f "$temp_file"
            die "Failed to install $(basename "$dest_path")"
        }
        rm -rf "$temp_dir"
        rm -f "$temp_file"
    else
        mv "$temp_file" "$dest_path" || {
            rm -f "$temp_file"
            die "Failed to install $(basename "$dest_path")"
        }
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
    local msg="${2:-File not found}"
    [[ -f "$file" ]] || die "${msg} (${file})"
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

# QEMU version handling
#
# The floor below is what every feature QemuMac passes on the command line is
# guaranteed by: q800 audiodev and Cocoa zoom-to-fit both landed in QEMU 8.2.
# Ubuntu 24.04 LTS ships 8.2.2, which is the oldest QEMU anyone is likely to
# have without building one, so nothing is gained by supporting less.
QEMU_MIN_VERSION="8.2"

# True when version $1 is at least version $2.
version_at_least() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# Version number of a QEMU binary, e.g. "8.2.2". Empty if it cannot be read.
# `sed -n ...p` rather than a bare substitution: an unrecognised version banner
# must yield nothing, not the whole unmatched line, or callers would compare a
# sentence against a version number.
qemu_version() {
    "$1" --version 2>/dev/null | head -n1 | sed -nE 's/.*version ([0-9][0-9.]*).*/\1/p'
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$(uname -s)" == "Linux" ]]; then
        echo "linux"
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

# Shared disk helpers
#
# The shared disk is a single raw HFS image that every VM mounts. Nothing
# arbitrates access, so two writers - two VMs, or a VM and the host - will
# corrupt the volume. Every entry point checks disk_in_use() first.

# Path to the shared disk, honouring a per-VM SHARED_DISK override.
shared_disk_path() {
    echo "${SHARED_DISK:-$DEFAULT_SHARED_DISK}"
}

# Is a disk image currently held open by another process (usually a VM)?
#   0 - in use
#   1 - free
#   2 - cannot tell (neither lsof nor fuser is installed)
# lsof ships with macOS; on Debian/Ubuntu either tool may be absent, hence
# the explicit "unknown" status rather than a silent assumption.
disk_in_use() {
    local disk="$1"

    file_exists "$disk" || return 1

    if command_exists lsof; then
        lsof -- "$disk" >/dev/null 2>&1
        return $(( $? == 0 ? 0 : 1 ))
    elif command_exists fuser; then
        fuser -- "$disk" >/dev/null 2>&1
        return $(( $? == 0 ? 0 : 1 ))
    fi
    return 2
}

# Is it safe for the *host* to write to the shared disk right now?
#   0 - yes, proceed
#   1 - no, a VM (or another process) holds it open
# A disk_in_use status of 2 ("cannot tell") warns and proceeds rather than
# blocking, but is never silently folded into "free" - a plain
# `if disk_in_use ...` test would do exactly that, because `if` reads 2 as
# false. Callers that want to degrade instead of refusing (run-mac.sh drops
# the disk from the command line) inspect disk_in_use directly.
shared_disk_is_writable() {
    local disk="$1"

    disk_in_use "$disk"
    case $? in
        0) return 1 ;;
        2)
            info "Neither lsof nor fuser is installed - cannot verify the disk is free"
            info "Make sure no VM is running before continuing"
            ;;
    esac
    return 0
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
    local choice result=""

    # `select` writes a stray newline to stdout when it reaches EOF, which
    # would end up in whatever the caller captured with $(menu ...). Running
    # the loop with stdout on stderr keeps the captured value to just the
    # selection, echoed below.
    {
        select choice in "${options[@]}"; do
            case "$choice" in
                "Quit")  result="QUIT"; break ;;
                "Back"*) result="BACK"; break ;;
                "None"*) result="NONE"; break ;;
                "")      error "Invalid selection" ;;
                *)       result="$choice"; break ;;
            esac
        done
    } >&2

    # Empty means EOF (Ctrl-D) - treat it as quitting rather than returning
    # nothing and letting the caller act on an empty selection.
    [[ -n "$result" ]] || result="QUIT"
    [[ "$result" == "QUIT" ]] && info "Exiting"
    echo "$result"
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
    local line
    if [[ -n "$extra_args" ]]; then
        # extra_args is deliberately unquoted: it carries several find flags
        # that must word-split into separate arguments.
        # shellcheck disable=SC2086
        while IFS= read -r line; do
            files+=("$line")
        done < <(find "$find_path" $extra_args -name "$pattern" | sort)
    else
        while IFS= read -r line; do
            files+=("$line")
        done < <(find "$find_path" -name "$pattern" | sort)
    fi
    
    [[ ${#files[@]} -eq 0 ]] && return 1
    
    local names=()
    case "$name_extractor" in
        "parent_dir") 
            for f in "${files[@]}"; do names+=("$(basename "$(dirname "$f")")"); done ;;
        "basename"|*)
            for f in "${files[@]}"; do names+=("$(basename "$f")"); done ;;
    esac
    
    # Return both arrays via global variables (bash 3.2 has no namerefs).
    # Read by the sourcing script, so shellcheck cannot see the use.
    # shellcheck disable=SC2034
    FOUND_FILES=("${files[@]}")
    # shellcheck disable=SC2034
    FOUND_NAMES=("${names[@]}")
    return 0
}

# Free-text prompt with a default. Echoes the answer.
ask_text() {
    local prompt="$1" default="${2:-}"
    local answer

    echo >&2
    read -rp "$(echo -e "${C_YELLOW}${prompt}${C_RESET} [${default}]: ")" answer
    echo "${answer:-$default}"
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

# Get items for category (returns tab-delimited "key\tname\tdescription\ttype" format)
db_items() {
    local db="$1"
    local category="$2"

    echo "$db" | jq -r --arg cat "$category" '
        [
            (.cds | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and (.value.category == null or .value.category == ""))) | "\(.key)\t\(.value.name)\t\(.value.description // "")\tcd"),
            (.roms | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and (.value.category == null or .value.category == ""))) | "\(.key)\t\(.value.name)\t\(.value.description // "")\trom")
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
