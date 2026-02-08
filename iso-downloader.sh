#!/usr/bin/env bash
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
    
    local categories=()
    local line
    while IFS= read -r line; do
        categories+=("$line")
    done < <(db_categories "$software_db")
    
    menu "Choose a category:" "${categories[@]}"
}


select_item() {
    local software_db="$1"
    local category="$2"

    header "Select an item to download"

    local software_options=()
    local line
    while IFS= read -r line; do
        software_options+=("$line")
    done < <(db_items "$software_db" "$category" | sort)

    # Extract display names for menu
    local display_options=()
    for item in "${software_options[@]}"; do
        display_options+=("$(echo "$item" | cut -d: -f2)")
    done

    local options=("${display_options[@]}" "Back to Categories")

    local choice
    choice=$(menu "Select the software you want to download:" "${options[@]}")

    case "$choice" in
        "QUIT") echo "quit" ;;
        "BACK"|"Back"*) echo "back" ;;
        *)
            # Find matching original item by comparing the name part
            for item in "${software_options[@]}"; do
                local item_name
                item_name=$(echo "$item" | cut -d: -f2)
                if [[ "$item_name" == "$choice" ]]; then
                    echo "$item"
                    return
                fi
            done
            ;;
    esac
}

# Handle delivery to the shared disk (Linux - uses loop mount)
_handle_shared_delivery_linux() {
    local temp_file="$1"
    local filename="$2"

    info "Mounting shared drive..."
    if ! "$(dirname "$0")/mount-shared.sh"; then
        rm -f "$temp_file"
        die "Failed to mount shared drive"
    fi

    local dest_path="${SHARED_MOUNT_POINT}/${filename}"

    if file_exists "$dest_path"; then
        info "File already exists, replacing..."
    else
        info "Copying file to shared drive..."
    fi

    mv -f "$temp_file" "$dest_path"

    info "Unmounting shared drive..."
    "$(dirname "$0")/mount-shared.sh" -u

    success "Successfully delivered to shared drive:"
    echo "  ${C_BLUE}${filename}${C_RESET}"
}

# Handle delivery to the shared disk (macOS - uses hfsutils)
_handle_shared_delivery_macos() {
    local temp_file="$1"
    local filename="$2"
    local shared_disk="shared/shared-disk.img"

    require_commands hmount hcopy humount
    require_file "$shared_disk" "Shared disk not found. Run a VM first to create it."

    info "Mounting shared disk with hfsutils..."
    if ! hmount "$shared_disk" >/dev/null 2>&1; then
        rm -f "$temp_file"
        die "Failed to mount shared disk. Install hfsutils: brew install hfsutils"
    fi

    info "Copying file to shared drive..."
    # hcopy uses : prefix for destination on HFS volume
    if ! hcopy "$temp_file" ":${filename}" 2>/dev/null; then
        humount 2>/dev/null || true
        rm -f "$temp_file"
        die "Failed to copy file to shared disk"
    fi

    info "Releasing shared disk..."
    humount 2>/dev/null || true

    # Clean up temp file
    rm -f "$temp_file"

    success "Successfully delivered to shared drive:"
    echo "  ${C_BLUE}${filename}${C_RESET}"
}

# Handle delivery to the shared disk (dispatcher)
_handle_shared_delivery() {
    local temp_file="$1"
    local filename="$2"
    local host_os
    host_os=$(detect_os)

    case "$host_os" in
        macos) _handle_shared_delivery_macos "$temp_file" "$filename" ;;
        ubuntu) _handle_shared_delivery_linux "$temp_file" "$filename" ;;
        *) rm -f "$temp_file"; die "Unsupported OS for shared delivery: $host_os" ;;
    esac
}

download_file() {
    local software_db="$1"
    local choice="$2"

    # Parse choice (format: key:name:description:type)
    IFS=':' read -r selected_key selected_name selected_description item_type <<< "$choice"

    info "Preparing to download '${C_BLUE}${selected_name}${C_RESET}'"

    # Get all item details
    local item
    item=$(db_item "$software_db" "$selected_key" "$item_type")

    local url filename nice_filename md5 delivery serial
    url=$(echo "$item" | jq -r '.url')
    filename=$(echo "$item" | jq -r '.filename')
    nice_filename=$(echo "$item" | jq -r '.nice_filename // .filename')
    md5=$(echo "$item" | jq -r '.md5')
    delivery=$(echo "$item" | jq -r '.delivery // "iso"')
    serial=$(echo "$item" | jq -r '.serial // null')

    # Display serial number if available
    if [[ "$serial" != "null" && -n "$serial" ]]; then
        info "Serial number: ${C_GREEN}${serial}${C_RESET}"
    fi

    # Handle delivery
    if [[ "$delivery" == "shared" ]]; then
        local temp_file
        temp_file=$(download_file_to_temp "$url" "$md5")
        _handle_shared_delivery "$temp_file" "$filename"

        # Display description after successful download
        if [[ -n "$selected_description" ]]; then
            echo ""
            echo -e "${C_BLUE}About ${selected_name}:${C_RESET}" >&2
            echo "  ${selected_description}" >&2
        fi
        return
    fi

    # Resolve destination path and download file
    local dest_path
    dest_path=$(resolve_download_path "$item_type" "$selected_key" "$filename" "$nice_filename")
    file_exists "$dest_path" && die "File already exists at '${dest_path}'"
    download_and_place_file "$url" "$md5" "$dest_path" "$filename"

    success "Successfully downloaded and installed:"
    echo "  ${C_BLUE}${dest_path}${C_RESET}"

    # Display description after successful download
    if [[ -n "$selected_description" ]]; then
        echo ""
        echo -e "${C_BLUE}About ${selected_name}:${C_RESET}" >&2
        echo "  ${selected_description}" >&2
    fi
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
