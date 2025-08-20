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
        if ! command -v "$cmd" &>/dev/null; then
            die "Required command '${cmd}' is not installed."
        fi
    done
}

load_database() {
    require_file "$DEFAULT_JSON_FILE" "Software database not found at '${DEFAULT_JSON_FILE}'"

    if file_exists "$CUSTOM_JSON_FILE"; then
        info "Merging custom software database"
        jq -s '.[0] * .[1]' "$DEFAULT_JSON_FILE" "$CUSTOM_JSON_FILE"
    else
        cat "$DEFAULT_JSON_FILE"
    fi
}

select_category() {
    local software_db="$1"
    
    header "Select a Category"
    
    local categories
    mapfile -t categories < <(echo "$software_db" | jq -r '(.cds, .roms) | .[] | .category // "Miscellaneous"' | sort -u)
    
    show_menu "Choose a category:" "${categories[@]}"
}

build_software_options() {
    local software_db="$1"
    local category="$2"
    
    # Define category matching filter for reusability
    local category_filter='(.value.category == $cat or ($cat == "Miscellaneous" and (.value.category == null or .value.category == "")))'
    
    # Get CDs matching the category
    echo "$software_db" | jq -r --arg cat "$category" \
        ".cds | to_entries[] | select($category_filter) | \"\(.key):\(.value.name):cd\""
    
    # Get ROMs matching the category  
    echo "$software_db" | jq -r --arg cat "$category" \
        ".roms | to_entries[] | select($category_filter) | \"\(.key):\(.value.name):rom\""
}

select_item() {
    local software_db="$1"
    local category="$2"
    
    header "Select an item to download"
    
    local options software_options
    mapfile -t software_options < <(build_software_options "$software_db" "$category" | sort)
    
    # Build menu options with special items
    options=("${software_options[@]}" "Back to Categories" "Quit")
    
    PS3="${C_YELLOW}Select the software you want to download: ${C_RESET}"
    select choice in "${options[@]}"; do
        case "$choice" in
            "Quit") info "Exiting"; exit 0 ;;
            "Back to Categories") echo "back"; return ;;
            "") error "Invalid selection" ;;
            *) echo "$choice"; return ;;
        esac
    done
}

download_file() {
    local software_db="$1"
    local choice="$2"
    
    # Parse choice
    IFS=':' read -r selected_key selected_name item_type <<< "$choice"
    
    info "Preparing to download '${C_BLUE}${selected_name}${C_RESET}'"
    
    # Get file info
    local json_path=".${item_type}s"
    local url filename
    url=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".url")
    filename=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".filename")
    
    # Determine destination
    local dest_path
    if [[ "$item_type" == "rom" ]]; then
        mkdir -p "$ROM_DOWNLOAD_DIR"
        if [[ "$selected_key" == "quadra800" ]]; then
            dest_path="${ROM_DOWNLOAD_DIR}/800.ROM"
        else
            dest_path="${ROM_DOWNLOAD_DIR}/${filename}"
        fi
    else
        mkdir -p "$ISO_DOWNLOAD_DIR"
        local nice_filename
        nice_filename=$(echo "$software_db" | jq -r "${json_path}.\"$selected_key\".nice_filename // \"$filename\"")
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
        
        while true; do
            local choice
            choice=$(select_item "$software_db" "$category")
            
            if [[ "$choice" == "back" ]]; then
                break
            fi
            
            download_file "$software_db" "$choice"
            exit 0
        done
    done
}

main "$@"