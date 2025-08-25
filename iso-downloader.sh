#!/bin/bash
#
# QemuMac Asset Downloader - A simple script to download software and ROMs.
#

set -euo pipefail

# Load common library
source "$(dirname "$0")/lib/common.sh"

# Configuration
DEFAULT_JSON_FILE="iso/software-database.json"
CUSTOM_JSON_FILE="iso/custom-software.json"
ISO_DOWNLOAD_DIR="iso"
ROM_DOWNLOAD_DIR="roms"

check_dependencies() {
    for cmd in jq curl unzip; do
        if ! command_exists "$cmd"; then
            die "Required command '${cmd}' is not installed."
        fi
    done
}

load_database() {
    db_load "$DEFAULT_JSON_FILE" "$CUSTOM_JSON_FILE"
}

select_category() {
    local software_db="$1"
    
    header "Select a Category"
    
    local categories
    mapfile -t categories < <(db_categories "$software_db")
    
    menu "Choose a category:" "${categories[@]}"
}


select_item() {
    local software_db="$1"
    local category="$2"
    
    header "Select an item to download"
    
    local software_options
    mapfile -t software_options < <(db_items "$software_db" "$category" | sort)
    
    # Build menu options with special items
    local options=("${software_options[@]}" "Back to Categories")
    
    local choice
    choice=$(menu "Select the software you want to download:" "${options[@]}")
    
    case "$choice" in
        "QUIT") echo "quit" ;;
        "BACK"|"Back"*) echo "back" ;;
        *) echo "$choice" ;;
    esac
}

download_file() {
    local software_db="$1"
    local choice="$2"
    
    # Parse choice
    IFS=':' read -r selected_key selected_name item_type <<< "$choice"
    
    info "Preparing to download '${C_BLUE}${selected_name}${C_RESET}'"
    
    # Get all item details in one call
    local item
    item=$(db_item "$software_db" "$selected_key" "$item_type")
    
    local url filename nice_filename
    url=$(echo "$item" | jq -r '.url')
    filename=$(echo "$item" | jq -r '.filename')
    nice_filename=$(echo "$item" | jq -r '.nice_filename // .filename')
    
    # Determine destination
    local dest_path
    if [[ "$item_type" == "rom" ]]; then
        ensure_directory "$ROM_DOWNLOAD_DIR" "Creating ROM download directory"
        if [[ "$selected_key" == "quadra800" ]]; then
            dest_path="${ROM_DOWNLOAD_DIR}/800.ROM"
        else
            dest_path="${ROM_DOWNLOAD_DIR}/${filename}"
        fi
    else
        ensure_directory "$ISO_DOWNLOAD_DIR" "Creating ISO download directory"
        dest_path="${ISO_DOWNLOAD_DIR}/${nice_filename}"
    fi
    
    file_exists "$dest_path" && die "File already exists at '${dest_path}'"
    
    # Download
    info "Downloading from: ${url}"
    if [[ "$url" == *.zip ]]; then
        # Handle zip files
        local temp_dir
        temp_dir=$(mktemp -d)
        trap "rm -rf '$temp_dir'" EXIT
        
        curl --fail --location --progress-bar -o "${temp_dir}/archive.zip" "$url"
        unzip -q "${temp_dir}/archive.zip" -d "$temp_dir"
        mv "${temp_dir}/${filename}" "$dest_path"
    else
        # Direct download
        curl --fail --location --progress-bar -o "$dest_path" "$url"
    fi
    
    success "Successfully downloaded and installed:"
    echo "  ${C_BLUE}${dest_path}${C_RESET}"
}

main() {
    check_dependencies
    
    local software_db
    software_db=$(load_database)
    
    while true; do
        local category
        category=$(select_category "$software_db")
        
        [[ "$category" == "QUIT" ]] && exit 0
        
        while true; do
            local choice
            choice=$(select_item "$software_db" "$category")
            
            case "$choice" in
                "back") break ;;
                "quit") exit 0 ;;
            esac
            
            download_file "$software_db" "$choice"
            exit 0
        done
    done
}

main "$@"