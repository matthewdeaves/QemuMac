#!/usr/bin/env bash

#######################################
# Mac Library Manager
# Simple tool to browse, download, and launch classic Mac software
#######################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the menu system
# shellcheck source=scripts/qemu-menu.sh  
source "$SCRIPT_DIR/scripts/qemu-menu.sh"

#######################################
# Main entry point
# Arguments:
#   All command line arguments
# Globals:
#   Various from menu system
# Returns:
#   None
#######################################
main() {
    # Initialize library
    init_library
    
    # Check for command line arguments
    if [ $# -eq 0 ]; then
        # No arguments - show interactive menu
        show_main_menu
    else
        # Handle command line arguments
        case "$1" in
            "help"|"--help"|"-h")
                show_help
                ;;
            "list")
                list_software
                ;;
            "download")
                if [ -z "$2" ]; then
                    echo "Error: Please specify software to download" >&2
                    echo "Usage: $0 download <software_key>" >&2
                    exit 1
                fi
                download_software "$2"
                ;;
            "launch")
                if [ -z "$2" ] || [ -z "$3" ]; then
                    echo "Error: Please specify software and config" >&2
                    echo "Usage: $0 launch <software_key> <config_file>" >&2
                    exit 1
                fi
                launch_software "$2" "$3"
                ;;
            *)
                echo "Error: Unknown command '$1'" >&2
                echo "Use '$0 help' for usage information" >&2
                exit 1
                ;;
        esac
    fi
}

#######################################
# Show help information
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
#######################################
show_help() {
    echo "Mac Library Manager - Classic Macintosh Software Launcher"
    echo
    echo "Usage:"
    echo "  $0                              Launch interactive menu"
    echo "  $0 list                         List available software"
    echo "  $0 download <software_key>      Download specific software"
    echo "  $0 launch <software_key> <config> Launch software with config"
    echo "  $0 help                         Show this help"
    echo
    echo "Examples:"
    echo "  $0                              # Interactive menu"
    echo "  $0 list                         # Show all available CDs"
    echo "  $0 download marathon            # Download Marathon" 
    echo "  $0 launch marathon sys753-standard.conf  # Launch Marathon with 7.5.3"
    echo
    echo "Interactive mode provides a colorful menu with progress bars and"
    echo "automatic downloads. Command line mode is useful for scripting."
}

#######################################
# List available software (command line mode)
# Arguments:
#   None
# Globals:
#   Various from menu system
# Returns:
#   None
#######################################
list_software() {
    echo "Available Software CDs:"
    echo
    
    while IFS= read -r cd_key; do
        [ -n "$cd_key" ] || continue
        
        local name=$(get_cd_info "$cd_key" "name")
        local description=$(get_cd_info "$cd_key" "description")
        local filename=$(get_cd_info "$cd_key" "filename")
        
        if is_downloaded "$filename"; then
            local status="[Downloaded]"
        else
            local status="[Not Downloaded]"
        fi
        
        printf "%-20s %-15s %s\n" "$cd_key" "$status" "$name"
        printf "%-20s %-15s %s\n" "" "" "$description"
        echo
    done < <(get_cd_list)
    
    echo "Available Configs:"
    while IFS= read -r config; do
        [ -n "$config" ] || continue
        echo "  $config"
    done < <(get_config_list)
}

#######################################
# Download software (command line mode)
# Arguments:
#   software_key: Key of software to download
# Globals:
#   Various from menu system
# Returns:
#   None
# Exits:
#   1 if download fails
#######################################
download_software() {
    local cd_key="$1"
    local name=$(get_cd_info "$cd_key" "name")
    local filename=$(get_cd_info "$cd_key" "filename")
    local url=$(get_cd_info "$cd_key" "url")
    
    if [ -z "$name" ]; then
        echo "Error: Software '$cd_key' not found in database" >&2
        exit 1
    fi
    
    echo "Downloading: $name"
    
    if is_downloaded "$filename"; then
        echo "Already downloaded: $filename"
        return 0
    fi
    
    if download_file "$url" "$DOWNLOADS_DIR/$filename"; then
        echo "Download completed: $filename"
    else
        echo "Download failed" >&2
        exit 1
    fi
}

#######################################
# Launch software (command line mode)
# Arguments:
#   software_key: Key of software to launch
#   config_file: Configuration file to use
# Globals:
#   Various from menu system
# Returns:
#   None
# Exits:
#   1 if launch fails
#######################################
launch_software() {
    local cd_key="$1"
    local config_file="$2"
    local name=$(get_cd_info "$cd_key" "name")
    local filename=$(get_cd_info "$cd_key" "filename")
    local url=$(get_cd_info "$cd_key" "url")
    
    if [ -z "$name" ]; then
        echo "Error: Software '$cd_key' not found in database" >&2
        exit 1
    fi
    
    # Download if needed
    if ! is_downloaded "$filename"; then
        echo "Software not downloaded. Downloading now..."
        if ! download_file "$url" "$DOWNLOADS_DIR/$filename"; then
            echo "Download failed" >&2
            exit 1
        fi
    fi
    
    # Verify config exists
    local config_path
    if [ -f "$SCRIPT_DIR/$config_file" ]; then
        config_path="$SCRIPT_DIR/$config_file"
    elif [ -f "$SCRIPT_DIR/configs/$config_file" ]; then
        config_path="$SCRIPT_DIR/configs/$config_file"
    else
        echo "Error: Config file not found: $config_file" >&2
        exit 1
    fi
    
    echo "Launching: $name with $config_file"
    
    # Launch VM
    cd "$SCRIPT_DIR" || exit 1
    ./run68k.sh -C "$config_path" -c "$DOWNLOADS_DIR/$filename"
}

# --- Script Entry Point ---
main "$@"