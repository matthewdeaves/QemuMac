#!/bin/bash
#
# QemuMac Asset Downloader - A simple script to download software and ROMs.
#

set -Euo pipefail

# --- Configuration ---
DEFAULT_JSON_FILE="iso/software-database.json"
CUSTOM_JSON_FILE="iso/custom-software.json"
ISO_DOWNLOAD_DIR="iso"
ROM_DOWNLOAD_DIR="roms"

# --- Color Codes for User-Friendly Output ---
C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_RESET=$(tput sgr0)

# --- Helper functions for printing colored text ---
info() { >&2 echo -e "${C_YELLOW}Info: ${1}${C_RESET}"; }
success() { >&2 echo -e "${C_GREEN}Success: ${1}${C_RESET}"; }
error() { >&2 echo -e "${C_RED}Error: ${1}${C_RESET}"; }
header() { >&2 echo -e "\n${C_BLUE}--- ${1} ---${C_RESET}"; }

#
# Checks for required command-line tools.
#
check_dependencies() {
    for cmd in jq curl unzip; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command '${cmd}' is not installed. Please install it to continue."
            exit 1
        fi
    done
}

# --- SCRIPT ENTRY POINT ---
main() {
    check_dependencies

    if [[ ! -f "$DEFAULT_JSON_FILE" ]]; then
        error "Software database not found at '${DEFAULT_JSON_FILE}'"
        exit 1
    fi

    local software_db

    # Check if a custom JSON file exists and merge it with the default.
    if [[ -f "$CUSTOM_JSON_FILE" ]]; then
        info "Custom software database found. Merging with default."
        software_db=$(jq -s '.[0] * .[1]' "$DEFAULT_JSON_FILE" "$CUSTOM_JSON_FILE")
    else
        software_db=$(cat "$DEFAULT_JSON_FILE")
    fi

    # --- Step 1: Select a Category ---
    header "Select a Category"

    # Get all unique categories from both 'cds' and 'roms'.
    # Fallback to "Miscellaneous" if a category is missing.
    mapfile -t categories < <(echo "$software_db" | jq -r '(.cds, .roms) | .[] | .category // "Miscellaneous"' | sort -u)
    categories+=("Quit")

    local selected_category
    PS3="${C_YELLOW}Choose a category: ${C_RESET}"
    select category_choice in "${categories[@]}"; do
        if [[ "$category_choice" == "Quit" ]]; then
            info "Exiting."
            exit 0
        fi
        if [[ -n "$category_choice" ]]; then
            selected_category="$category_choice"
            break
        else
            error "Invalid selection. Please try again."
        fi
    done

    # --- Step 2: Select an item from within the chosen category ---
    header "Select an item to download"

    # Build a menu of items filtered by the selected category.
    # The format is "key:name" to easily retrieve the details later.
    mapfile -t options < <(echo "$software_db" | jq -r --arg cat "$selected_category" '
        (.cds | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and .value.category == null))) as $cd | "\($cd.key):\(.name):cd",
        (.roms | to_entries[] | select(.value.category == $cat or ($cat == "Miscellaneous" and .value.category == null))) as $rom | "\($rom.key):\(.name):rom"
    ' | sort)
    options+=("Back to Categories")
    options+=("Quit")

    local selected_key selected_name item_type
    PS3="${C_YELLOW}Select the software you want to download: ${C_RESET}"
    select choice in "${options[@]}"; do
        if [[ "$choice" == "Quit" ]]; then info "Exiting."; exit 0; fi
        if [[ "$choice" == "Back to Categories" ]]; main; exit 0; fi # Restart the script
        if [[ -z "$choice" ]]; then error "Invalid selection."; continue; fi

        # Parse the choice string "key:name:type"
        IFS=':' read -r selected_key selected_name item_type <<< "$choice"
        break
    done

    echo
    info "Preparing to download '${C_BLUE}${selected_name}${C_RESET}'..."

    # Determine the correct JSON path (.cds or .roms) based on the item type
    local json_path=".${item_type}s"
    
    # --- Step 3: Download and Place the File ---
    local url filename dest_dir dest_path
    url=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".url")
    filename=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".filename")
    
    # ROMs go into ROM_DOWNLOAD_DIR, everything else goes to ISO_DOWNLOAD_DIR
    if [[ "$item_type" == "rom" ]]; then
        dest_dir="$ROM_DOWNLOAD_DIR"
        # Special case for the Quadra 800 ROM filename
        if [[ "$selected_key" == "quadra800" ]]; then
            dest_path="${dest_dir}/800.ROM"
        else
            dest_path="${dest_dir}/${filename}"
        fi
    else
        dest_dir="$ISO_DOWNLOAD_DIR"
        local nice_filename
        nice_filename=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".nice_filename // \"$filename\"")
        dest_path="${dest_dir}/${nice_filename}"
    fi

    if [[ -f "$dest_path" ]]; then
        error "File already exists at '${dest_path}'. Skipping download."
        exit 1
    fi

    local temp_dir downloaded_archive
    temp_dir=$(mktemp -d)
    trap 'rm -rf -- "$temp_dir"' EXIT # Cleanup temp dir on exit
    downloaded_archive="${temp_dir}/download_file"

    info "Downloading from: ${url}"
    curl --fail --location --progress-bar -o "$downloaded_archive" "$url"
    success "Download complete."

    local source_file_path="$downloaded_archive"
    if [[ "$url" == *.zip ]]; then
        info "Extracting from zip archive..."
        # Extract to temp_dir and find the source file within it
        unzip -d "$temp_dir" "$downloaded_archive" > /dev/null
        source_file_path="${temp_dir}/${filename}"
    fi

    if [[ ! -f "$source_file_path" ]]; then
        error "Could not find expected file '${filename}' after download/extraction."
        exit 1
    fi
    
    info "Moving file to '${dest_path}'..."
    mkdir -p "$dest_dir"
    mv "$source_file_path" "$dest_path"

    success "Successfully downloaded and installed:"
    echo "  ${C_BLUE}${dest_path}${C_RESET}"
}

main "$@"
