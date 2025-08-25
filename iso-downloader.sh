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
    require_commands jq curl unzip
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

# Handle delivery to the shared disk
_handle_shared_delivery() {
    local temp_file="$1"
    local filename="$2"
    
    info "Mounting shared drive..."
    if ! "$(dirname "$0")/mount-shared.sh"; then
        die "Failed to mount shared drive"
    fi
    
    local dest_path="${SHARED_MOUNT_POINT}/${filename}"
    
    if file_exists "$dest_path"; then
        info "File already exists at '${dest_path}', skipping copy."
        rm -f "$temp_file" # Clean up the unused temp file
    else
        info "Copying file to shared drive..."
        mv "$temp_file" "$dest_path"
    fi
    
    info "Unmounting shared drive..."
    "$(dirname "$0")/mount-shared.sh" -u
    
    success "Successfully delivered to shared drive:"
    echo "  ${C_BLUE}${filename}${C_RESET}"
}

download_file() {
    local software_db="$1"
    local choice="$2"
    
    # Parse choice
    IFS=':' read -r selected_key selected_name item_type <<< "$choice"
    
    info "Preparing to download '${C_BLUE}${selected_name}${C_RESET}'"
    
    # Get all item details
    local item
    item=$(db_item "$software_db" "$selected_key" "$item_type")
    
    local url filename nice_filename md5 delivery
    url=$(echo "$item" | jq -r '.url')
    filename=$(echo "$item" | jq -r '.filename')
    nice_filename=$(echo "$item" | jq -r '.nice_filename // .filename')
    md5=$(echo "$item" | jq -r '.md5')
    delivery=$(echo "$item" | jq -r '.delivery // "iso"')
    
    # Download and verify the file
    local temp_file
    temp_file=$(download_file_to_temp "$url" "$md5")
    trap "rm -f '$temp_file'" EXIT
    
    # Handle delivery
    if [[ "$delivery" == "shared" ]]; then
        _handle_shared_delivery "$temp_file" "$filename"
        trap - EXIT # The temp file was moved or deleted
        return
    fi
    
    # Default delivery to iso/ or roms/
    local dest_path
    if [[ "$item_type" == "rom" ]]; then
        ensure_directory "$ROM_DOWNLOAD_DIR"
        # Special case for the main Quadra 800 ROM
        if [[ "$selected_key" == "quadra800" ]]; then
            dest_path="${ROM_DOWNLOAD_DIR}/800.ROM"
        else
            dest_path="${ROM_DOWNLOAD_DIR}/${filename}"
        fi
    else
        ensure_directory "$ISO_DOWNLOAD_DIR"
        dest_path="${ISO_DOWNLOAD_DIR}/${nice_filename}"
    fi
    
    file_exists "$dest_path" && die "File already exists at '${dest_path}'"
    
    # Move the file to its final destination
    if [[ "$url" == *.zip ]]; then
        info "Extracting from zip archive..."
        local temp_dir
        temp_dir=$(mktemp -d)
        # Unzip the downloaded temp file, not the url
        unzip -q "$temp_file" -d "$temp_dir"
        mv "${temp_dir}/${filename}" "$dest_path"
        rm -rf "$temp_dir"
        rm -f "$temp_file" # remove original zip download
    else
        mv "$temp_file" "$dest_path"
    fi
    
    trap - EXIT # The temp file was moved
    
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