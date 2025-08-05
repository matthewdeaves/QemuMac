#!/usr/bin/env bash


#######################################
# QEMU Mac Library Menu System
# Interactive menu with colors and download management
#######################################


# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/qemu-utils.sh
source "$SCRIPT_DIR/qemu-utils.sh"


# --- Colors and UI ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m' # No Color


# --- Constants ---
readonly LIBRARY_DIR="$SCRIPT_DIR/../library"
readonly DATABASE_FILE="$LIBRARY_DIR/software-database.json"
readonly DOWNLOADS_DIR="$LIBRARY_DIR/downloads"
readonly CONFIGS_DIR="$SCRIPT_DIR/.."


#######################################
# Print colored header with ASCII art
# Arguments:
#   None
# Globals:
#   Color constants
# Returns:
#   None
#######################################
print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🖥️  Mac Library Manager                    ║"
    echo "║              Classic Macintosh Software & ROMs               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}


#######################################
# Show animated spinner during operations
# Arguments:
#   pid: Process ID to monitor
#   message: Message to show with spinner
# Globals:
#   None
# Returns:
#   None
#######################################
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    printf "${YELLOW}%s " "$message"
    while kill -0 $pid 2>/dev/null; do
        printf "\b${spin:$i:1}"
        i=$(((i+1) % ${#spin}))
        sleep 0.1
    done
    printf "\b%b✓%b\n" "$GREEN" "$NC"
}


#######################################
# Show download progress bar
# Arguments:
#   current: Current bytes downloaded
#   total: Total bytes to download
# Globals:
#   Color constants
# Returns:
#   None
#######################################
show_progress() {
    local current=$1
    local total=$2
    local percent=$(( current * 100 / total ))
    local completed=$(( percent / 2 ))
    local remaining=$(( 50 - completed ))
    
    printf "\r${CYAN}Downloading: ["
    printf "%*s" $completed | tr ' ' '█'
    printf "%*s" $remaining | tr ' ' '░'
    printf "] ${percent}%%${NC}"
}


#######################################
# Initialize library directories
# Arguments:
#   None
# Globals:
#   LIBRARY_DIR, DOWNLOADS_DIR
# Returns:
#   None
# Exits:
#   1 if initialization fails
#######################################
init_library() {
    ensure_directory "$LIBRARY_DIR" "library directory"
    ensure_directory "$DOWNLOADS_DIR" "downloads directory"
    
    if [ ! -f "$DATABASE_FILE" ]; then
        echo -e "${RED}Error: Database file not found: $DATABASE_FILE${NC}" >&2
        exit 1
    fi
}


#######################################
# Parse JSON database and extract CD information sorted by category then name
# Arguments:
#   None
# Globals:
#   DATABASE_FILE
# Returns:
#   Prints CD keys to stdout, sorted by category (Operating Systems first, then Games) and then alphabetically by name
#######################################
get_cd_list() {
    jq -r '.cds | to_entries | sort_by(.value.category, .value.name) | .[].key' "$DATABASE_FILE" 2>/dev/null
}


#######################################
# Get CD information by key
# Arguments:
#   cd_key: Key of the CD in database
#   field: Field to extract (name, description, filename, url, etc.)
# Globals:
#   DATABASE_FILE
# Returns:
#   Field value via stdout
#######################################
get_cd_info() {
    local cd_key="$1"
    local field="$2"
    
    if command -v jq &> /dev/null; then
        jq -r ".cds.\"$cd_key\".\"$field\" // empty" "$DATABASE_FILE" 2>/dev/null
    else
        # Fallback: simple grep-based parsing
        case "$field" in
            "name")
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"name\"" | cut -d'"' -f4
                ;;
            "description") 
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"description\"" | cut -d'"' -f4
                ;;
            "filename")
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"filename\"" | cut -d'"' -f4
                ;;
            "nice_filename") # Add fallback for nice_filename
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"nice_filename\"" | cut -d'"' -f4
                ;;
            "url")
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"url\"" | cut -d'"' -f4
                ;;
            "md5")
                grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep "\"md5\"" | cut -d'"' -f4
                ;;
        esac
    fi
}


#######################################
# Get ROM information by key
# Arguments:
#   rom_key: Key of the ROM in database
#   field: Field to extract
# Globals:
#   DATABASE_FILE
# Returns:
#   Field value via stdout
#######################################
get_rom_info() {
    local rom_key="$1"
    local field="$2"
    
    if command -v jq &> /dev/null; then
        jq -r ".roms.\"$rom_key\".\"$field\" // empty" "$DATABASE_FILE" 2>/dev/null
    else
        # Fallback parsing
        case "$field" in
            "name")
                grep -A20 "\"$rom_key\"" "$DATABASE_FILE" | grep "\"name\"" | cut -d'"' -f4
                ;;
            "filename")
                grep -A20 "\"$rom_key\"" "$DATABASE_FILE" | grep "\"filename\"" | cut -d'"' -f4
                ;;
            "url")
                grep -A20 "\"$rom_key\"" "$DATABASE_FILE" | grep "\"url\"" | cut -d'"' -f4
                ;;
            "md5")
                grep -A20 "\"$rom_key\"" "$DATABASE_FILE" | grep "\"md5\"" | cut -d'"' -f4
                ;;
        esac
    fi
}


#######################################
# Get additional files for a CD
# Arguments:
#   cd_key: Key of the CD in database
# Globals:
#   DATABASE_FILE
# Returns:
#   Array of additional files via stdout (one per line)
#######################################
get_cd_additional_files() {
    local cd_key="$1"
    
    if command -v jq &> /dev/null; then
        jq -r ".cds.\"$cd_key\".additional_files[]? | \"\(.filename)|\(.description // .filename)\"" "$DATABASE_FILE" 2>/dev/null
    else
        # Fallback: look for additional_files section
        # This is a simple implementation - could be enhanced
        grep -A50 "\"$cd_key\"" "$DATABASE_FILE" | grep -A20 "additional_files" | grep "filename" | cut -d'"' -f4
    fi
}


#######################################
# Get CD architectures as array
# Arguments:
#   cd_key: Key of the CD in database
# Globals:
#   DATABASE_FILE
# Returns:
#   Architectures array elements via stdout (one per line)
#######################################
get_cd_architectures() {
    local cd_key="$1"
    
    if command -v jq &> /dev/null; then
        jq -r ".cds.\"$cd_key\".architectures[]? // empty" "$DATABASE_FILE" 2>/dev/null
    else
        # Fallback: simple grep-based parsing for architectures array
        grep -A20 "\"$cd_key\"" "$DATABASE_FILE" | grep -A5 "architectures" | grep -o '"[^"]*"' | tr -d '"' | grep -E '^(m68k|ppc)$'
    fi
}


#######################################
# Get list of available config files, optionally filtered by architectures
# Arguments:
#   architectures: Optional space-separated list of architectures to filter by
# Globals:
#   CONFIGS_DIR
# Returns:
#   Config filenames via stdout
#######################################
get_config_list() {
    local filter_architectures="$1"
    
    # If no filter specified, return all configs
    if [ -z "$filter_architectures" ]; then
        find "$CONFIGS_DIR/m68k/configs" "$CONFIGS_DIR/ppc/configs" -maxdepth 1 -name "*.conf" -type f 2>/dev/null | while read -r config; do
            basename "$config"
        done | sort
        return
    fi
    
    # Filter configs based on architectures
    local configs=()
    
    # Check if m68k is in the filter
    if echo "$filter_architectures" | grep -q "m68k"; then
        while IFS= read -r config; do
            [ -n "$config" ] && configs+=("$config")
        done < <(find "$CONFIGS_DIR/m68k/configs" -maxdepth 1 -name "*.conf" -type f 2>/dev/null | while read -r config; do basename "$config"; done)
    fi
    
    # Check if ppc is in the filter
    if echo "$filter_architectures" | grep -q "ppc"; then
        while IFS= read -r config; do
            [ -n "$config" ] && configs+=("$config")
        done < <(find "$CONFIGS_DIR/ppc/configs" -maxdepth 1 -name "*.conf" -type f 2>/dev/null | while read -r config; do basename "$config"; done)
    fi
    
    # Output sorted unique configs
    printf '%s\n' "${configs[@]}" | sort -u
}


#######################################
# Verify MD5 checksum of a file
# Arguments:
#   file_path: Path to file to verify
#   expected_md5: Expected MD5 hash
# Globals:
#   Color constants
# Returns:
#   0 if valid, 1 if invalid
#######################################
verify_md5() {
    local file_path="$1"
    local expected_md5="$2"
    
    if [ -z "$expected_md5" ]; then
        echo -e "${YELLOW}⚠ No MD5 hash provided, skipping verification${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Verifying MD5 checksum...${NC}"
    
    local actual_md5
    if command -v md5sum &> /dev/null; then
        actual_md5=$(md5sum "$file_path" | cut -d' ' -f1)
    elif command -v md5 &> /dev/null; then
        actual_md5=$(md5 -q "$file_path")
    else
        echo -e "${YELLOW}⚠ No MD5 tool available, skipping verification${NC}"
        return 0
    fi
    
    if [ "$actual_md5" = "$expected_md5" ]; then
        echo -e "${GREEN}✓ MD5 checksum verified${NC}"
        return 0
    else
        echo -e "${RED}✗ MD5 mismatch!${NC}"
        echo -e "${RED}Expected: $expected_md5${NC}"
        echo -e "${RED}Actual:   $actual_md5${NC}"
        return 1
    fi
}


#######################################
# Extract ZIP file and clean up
# Arguments:
#   zip_file: Path to ZIP file
#   extract_dir: Directory to extract to
# Globals:
#   Color constants
# Returns:
#   0 if successful, 1 if failed
#######################################
extract_zip() {
    local zip_file="$1"
    local extract_dir="$2"
    
    echo -e "${BLUE}Extracting ZIP file...${NC}"
    
    if ! command -v unzip &> /dev/null; then
        echo -e "${RED}Error: unzip command not found${NC}" >&2
        return 1
    fi
    
    # Extract to temp directory first
    local temp_dir="$extract_dir/temp_extract"
    mkdir -p "$temp_dir"
    
    if unzip -q "$zip_file" -d "$temp_dir"; then
        # Move extracted files to downloads directory (case-insensitive)
        find "$temp_dir" -iname "*.iso" -o -iname "*.img" -o -iname "*.dmg" | while read -r file; do
            mv "$file" "$extract_dir/"
            echo -e "${GREEN}✓ Extracted: $(basename "$file")${NC}"
        done
        
        # Clean up
        rm -rf "$temp_dir"
        rm -f "$zip_file"
        echo -e "${GREEN}✓ ZIP file extracted and cleaned up${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to extract ZIP file${NC}" >&2
        rm -rf "$temp_dir"
        return 1
    fi
}


#######################################
# Download file with real-time progress tracking, verification, and extraction
# Arguments:
#   url: URL to download
#   output_file: Local file path to save to
#   expected_md5: Expected MD5 hash (optional)
# Globals:
#   Color constants
# Returns:
#   0 if successful, 1 if failed
#######################################
download_file() {
    local url="$1"
    local output_file="$2"
    local expected_md5="$3"
    
    echo -e "${BLUE}Downloading from: ${url}${NC}"
    echo -e "${BLUE}Saving to: ${output_file}${NC}"
    echo
    
    # Determine if this is a ZIP file
    local is_zip=false
    if [[ "$url" =~ \.zip$ ]]; then
        is_zip=true
        # Use temporary filename for ZIP
        output_file="${output_file}.zip"
    fi
    
    local download_success=false
    
    # Try wget first with better progress display
    if command -v wget &> /dev/null; then
        echo -e "${CYAN}Using wget for download...${NC}"
        # Simple approach: let wget handle its own progress display
        if wget --progress=bar:force --show-progress -O "$output_file" "$url"; then
            download_success=true
        else
            # Fallback to basic wget
            echo -e "${YELLOW}Retrying with basic wget...${NC}"
            if wget -O "$output_file" "$url"; then
                download_success=true
            fi
        fi
    elif command -v curl &> /dev/null; then
        echo -e "${CYAN}Using curl for download...${NC}"
        # Use curl's built-in progress meter with custom format
        if curl -L -# -o "$output_file" "$url"; then
            download_success=true
        else
            # Fallback to curl without progress bar
            echo -e "${YELLOW}Retrying with basic curl...${NC}"
            if curl -L -s -o "$output_file" "$url"; then
                download_success=true
            fi
        fi
    else
        echo -e "${RED}Error: Neither wget nor curl is available${NC}" >&2
        return 1
    fi
    
    # Check if download was successful
    if [ "$download_success" = false ]; then
        echo -e "${RED}Error: Download failed${NC}" >&2
        return 1
    fi
    
    # Verify file was downloaded
    if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
        echo -e "${RED}Error: Download failed or file is empty${NC}" >&2
        return 1
    fi
    
    echo -e "${GREEN}✓ Download completed successfully${NC}"
    
    # Get file size for user info
    local file_size
    if command -v stat &> /dev/null; then
        file_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "unknown")
        if [ "$file_size" != "unknown" ] && [ "$file_size" -gt 0 ]; then
            local size_mb=$((file_size / 1024 / 1024))
            echo -e "${BLUE}Downloaded: ${size_mb} MB${NC}"
        fi
    fi
    
    # Verify MD5 if provided
    if [ -n "$expected_md5" ]; then
        echo -e "${BLUE}Verifying download integrity...${NC}"
        if ! verify_md5 "$output_file" "$expected_md5"; then
            echo -e "${RED}MD5 verification failed, removing file${NC}"
            rm -f "$output_file"
            return 1
        fi
    fi
    
    # Extract ZIP if needed
    if [ "$is_zip" = true ]; then
        echo -e "${BLUE}Processing ZIP file...${NC}"
        local extract_dir=$(dirname "$output_file")
        if extract_zip "$output_file" "$extract_dir"; then
            echo -e "${GREEN}✓ ZIP extraction completed${NC}"
        else
            echo -e "${RED}✗ ZIP extraction failed${NC}" >&2
            return 1
        fi
    fi
    
    return 0
}


#######################################
# Check if file is already downloaded
# Arguments:
#   filename: Name of file to check
# Globals:
#   DOWNLOADS_DIR
# Returns:
#   0 if file exists, 1 if not
#######################################
is_downloaded() {
    local filename="$1"
    
    # Check exact filename first
    if [ -f "$DOWNLOADS_DIR/$filename" ] && [ -s "$DOWNLOADS_DIR/$filename" ]; then
        return 0
    fi
    
    # Check for similar filenames (spaces vs underscores, etc.)
    local base_name="${filename%.*}"
    local extension="${filename##*.}"
    
    # Try various filename variations
    local variations=(
        "${base_name// /_}.$extension"    # spaces to underscores
        "${base_name//_/ }.$extension"    # underscores to spaces
        "$filename"                       # original
    )
    
    for variant in "${variations[@]}"; do
        if [ -f "$DOWNLOADS_DIR/$variant" ] && [ -s "$DOWNLOADS_DIR/$variant" ]; then
            return 0
        fi
    done
    
    return 1
}


#######################################
# Find actual downloaded filename
# Arguments:
#   expected_filename: Expected filename from database
# Globals:
#   DOWNLOADS_DIR
# Returns:
#   Actual filename via stdout, or empty if not found
#######################################
find_downloaded_file() {
    local expected_filename="$1"
    
    # Check exact filename first
    if [ -f "$DOWNLOADS_DIR/$expected_filename" ] && [ -s "$DOWNLOADS_DIR/$expected_filename" ]; then
        echo "$expected_filename"
        return 0
    fi
    
    # Check for similar filenames
    local base_name="${expected_filename%.*}"
    local extension="${expected_filename##*.}"
    
    # Try various filename variations
    local variations=(
        "${base_name// /_}.$extension"    # spaces to underscores
        "${base_name//_/ }.$extension"    # underscores to spaces
    )
    
    for variant in "${variations[@]}"; do
        if [ -f "$DOWNLOADS_DIR/$variant" ] && [ -s "$DOWNLOADS_DIR/$variant" ]; then
            echo "$variant"
            return 0
        fi
    done
    
    # No file found
    return 1
}


#######################################
# Display main menu and handle user selection
# Arguments:
#   None
# Globals:
#   Various constants and functions
# Returns:
#   None
#######################################
show_main_menu() {
    while true; do
        print_header
        
        echo -e "${WHITE}${BOLD}Main Menu:${NC}"
        echo
        echo -e "${GREEN}1)${NC} 📀 Browse & Launch Software CDs"
        echo -e "${GREEN}2)${NC} 💾 Download ROM Files"
        echo -e "${GREEN}3)${NC} 📂 View Downloaded Files"
        echo -e "${GREEN}4)${NC} ⚙️  System Information"
        echo -e "${GREEN}q)${NC} 🚪 Quit"
        echo
        echo -e -n "${YELLOW}Select an option: ${NC}"
        
        read -r choice
        
        case $choice in
            1) show_cd_menu ;;
            2) show_rom_menu ;;
            3) show_downloads ;;
            4) show_system_info ;;
            q|Q) 
                echo -e "\n${CYAN}Thanks for using Mac Library Manager!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid option. Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
}


#######################################
# Display CD selection menu
# Arguments:
#   None
# Globals:
#   Various functions and constants
# Returns:
#   None
#######################################
show_cd_menu() {
    while true; do
        print_header
        echo -e "${WHITE}${BOLD}📀 Software Library:${NC}"
        echo
        
        local cd_keys=()
        local i=1
        local current_category=""
        
        # Read CD list into array with category headers
        while IFS= read -r cd_key; do
            [ -n "$cd_key" ] || continue
            cd_keys+=("$cd_key")
            
            local name=$(get_cd_info "$cd_key" "name")
            local description=$(get_cd_info "$cd_key" "description")
            # --- MODIFIED ---
            # Use the helper function to get the correct local filename
            local effective_filename
            effective_filename=$(_get_local_filename "$cd_key")
            local category=$(get_cd_info "$cd_key" "category")
            
            # Display category header when category changes
            if [ "$category" != "$current_category" ]; then
                if [ -n "$current_category" ]; then
                    echo  # Add spacing between categories
                fi
                case "$category" in
                    "Operating Systems")
                        echo -e "${CYAN}${BOLD}📀 Operating Systems:${NC}"
                        ;;
                    "Games")
                        echo -e "${MAGENTA}${BOLD}🎮 Games:${NC}"
                        ;;
                    *)
                        echo -e "${YELLOW}${BOLD}📁 $category:${NC}"
                        ;;
                esac
                echo
                current_category="$category"
            fi
            
            # --- MODIFIED ---
            # Check status using the effective filename
            local status
            if is_downloaded "$effective_filename"; then
                status="${GREEN}✓ Downloaded${NC}"
            else
                status="${DIM}Not downloaded${NC}"
            fi
            
            printf "%b%2d)%b %b%s%b\n" "$GREEN" $i "$NC" "$BOLD" "$name" "$NC"
            printf "     %b%s%b\n" "$DIM" "$description" "$NC"
            printf "     Status: %b\n" "$status"
            echo
            
            ((i++))
        done < <(get_cd_list)
        
        echo -e "${GREEN}b)${NC} 🔙 Back to main menu"
        echo
        echo -e -n "${YELLOW}Select a CD to launch (or 'b' for back): ${NC}"
        
        read -r choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#cd_keys[@]}" ]; then
            local selected_cd="${cd_keys[$((choice-1))]}"
            handle_cd_selection "$selected_cd"
        else
            echo -e "\n${RED}Invalid selection. Press Enter to continue...${NC}"
            read -r
        fi
    done
}


#######################################
# Handle CD selection and system choice
# Arguments:
#   cd_key: Selected CD key
# Globals:
#   Various functions and constants
# Returns:
#   None
#######################################
handle_cd_selection() {
    local cd_key="$1"
    local name=$(get_cd_info "$cd_key" "name")
    # --- MODIFIED ---
    # Use helper function for the filename throughout this function
    local effective_filename
    effective_filename=$(_get_local_filename "$cd_key")
    local url=$(get_cd_info "$cd_key" "url")
    local md5=$(get_cd_info "$cd_key" "md5")
    
    print_header
    echo -e "${WHITE}${BOLD}Selected: $name${NC}"
    echo
    
    # --- MODIFIED ---
    # Download if not already downloaded, using the effective filename
    if ! is_downloaded "$effective_filename"; then
        echo -e "${YELLOW}CD not downloaded. Downloading now...${NC}"
        echo
        
        if download_file "$url" "$DOWNLOADS_DIR/$effective_filename" "$md5"; then
            echo -e "${GREEN}✓ Download completed!${NC}"
        else
            echo -e "${RED}✗ Download failed. Press Enter to continue...${NC}"
            read -r
            return
        fi
        echo
    else
        echo -e "${GREEN}✓ CD already downloaded${NC}"
        echo
    fi
    
    # --- MODIFIED ---
    # The default selected filename is now the effective_filename
    local selected_filename="$effective_filename"
    local additional_files_info
    additional_files_info=$(get_cd_additional_files "$cd_key")
    
    if [ -n "$additional_files_info" ]; then
        # Build list of available files
        local available_files=()
        local file_descriptions=()
        
        # --- MODIFIED ---
        # Add main file if it exists, using the effective filename
        if [ -f "$DOWNLOADS_DIR/$effective_filename" ]; then
            available_files+=("$effective_filename")
            file_descriptions+=("Main Game/Software")
        fi
        
        # Add additional files if they exist (this logic remains the same)
        while IFS='|' read -r add_filename add_description; do
            [ -n "$add_filename" ] || continue
            if [ -f "$DOWNLOADS_DIR/$add_filename" ]; then
                available_files+=("$add_filename")
                file_descriptions+=("$add_description")
            fi
        done <<< "$additional_files_info"
        
        # If multiple files available, show selection menu
        if [ ${#available_files[@]} -gt 1 ]; then
            echo -e "${WHITE}${BOLD}Multiple disc images found:${NC}"
            echo
            
            local i=1
            for idx in "${!available_files[@]}"; do
                printf "%b%2d)%b %s %b(%s)%b\n" "$GREEN" $i "$NC" "${file_descriptions[$idx]}" "$DIM" "${available_files[$idx]}" "$NC"
                ((i++))
            done
            
            echo
            echo -e -n "${YELLOW}Which disc would you like to boot? [1-${#available_files[@]}]: ${NC}"
            
            read -r disc_choice
            
            if [[ "$disc_choice" =~ ^[0-9]+$ ]] && [ "$disc_choice" -ge 1 ] && [ "$disc_choice" -le "${#available_files[@]}" ]; then
                selected_filename="${available_files[$((disc_choice-1))]}"
                echo -e "${GREEN}✓ Selected: $selected_filename${NC}"
            else
                # --- MODIFIED ---
                # Fallback to the effective filename
                echo -e "${RED}Invalid selection, using default: $effective_filename${NC}"
                selected_filename="$effective_filename"
            fi
            echo
        fi
    fi
    
    # Get architectures supported by this CD
    local cd_architectures
    cd_architectures=$(get_cd_architectures "$cd_key" | tr '\n' ' ' | sed 's/ $//')
    
    # Show system selection
    echo -e "${WHITE}${BOLD}Select Mac OS System:${NC}"
    if [ -n "$cd_architectures" ]; then
        echo -e "${DIM}Showing configurations compatible with: $cd_architectures${NC}"
    fi
    echo
    
    local configs=()
    local i=1
    
    while IFS= read -r config; do
        [ -n "$config" ] || continue
        configs+=("$config")
        
        # Extract system info from config name
        local system_name
        case "$config" in
            sys753*) system_name="Mac OS 7.5.3" ;;
            sys761*) system_name="Mac OS 7.6.1" ;;
            sys710*) system_name="Mac OS 7.1.0" ;;
            *) system_name="$(basename "$config" .conf)" ;;
        esac
        
        printf "%b%2d)%b %s %b(%s)%b\n" "$GREEN" $i "$NC" "$system_name" "$DIM" "$config" "$NC"
        ((i++))
    done < <(get_config_list "$cd_architectures")
    
    echo
    echo -e "${GREEN}b)${NC} 🔙 Back to CD selection"
    echo
    echo -e -n "${YELLOW}Select system configuration: ${NC}"
    
    read -r choice
    
    if [[ "$choice" == "b" || "$choice" == "B" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#configs[@]}" ]; then
        local selected_config="${configs[$((choice-1))]}"
        launch_vm "$selected_config" "$DOWNLOADS_DIR/$selected_filename" "$cd_key"
    else
        echo -e "\n${RED}Invalid selection. Press Enter to continue...${NC}"
        read -r
    fi
}


#######################################
# Show boot options menu with smart defaults
# Arguments:
#   cd_key: CD key to determine category and defaults
#   software_name: Name of the software for display
# Globals:
#   Color constants
# Returns:
#   Sets BOOT_OPTION_RESULT global variable ("" for boot from Mac, "-b" for boot from CD)
#######################################
show_boot_options() {
    local cd_key="$1"
    local software_name="$2"
    local category=$(get_cd_info "$cd_key" "category")
    
    # Determine smart default based on category
    local default_option=1
    local default_text="Boot from Virtual Mac"
    local recommendation=""
    
    if [ "$category" = "Operating Systems" ]; then
        default_option=2
        default_text="Boot from CD-ROM"
        recommendation="Recommended for OS installation"
    else
        recommendation="Recommended for applications and games"
    fi
    
    echo
    echo -e "${WHITE}${BOLD}Boot Options for: $software_name${NC}"
    echo -e "${DIM}Category: $category${NC}"
    echo
    
    # Show options with default highlighted
    if [ "$default_option" -eq 1 ]; then
        echo -e "${GREEN} 1)${NC} 🖥️  Boot from Virtual Mac ${YELLOW}[RECOMMENDED]${NC} ${DIM}(CD available on desktop)${NC}"
        echo -e "${GREEN} 2)${NC} 💿  Boot from CD-ROM ${DIM}(for installation/CD-based software)${NC}"
    else
        echo -e "${GREEN} 1)${NC} 🖥️  Boot from Virtual Mac ${DIM}(CD available on desktop)${NC}"
        echo -e "${GREEN} 2)${NC} 💿  Boot from CD-ROM ${YELLOW}[RECOMMENDED]${NC} ${DIM}(for installation/CD-based software)${NC}"
    fi
    
    echo
    echo -e "${DIM}$recommendation${NC}"
    echo
    echo -e -n "${YELLOW}Choose boot method [1-2] or press Enter for recommended [$default_option]: ${NC}"
    
    read -r boot_choice
    
    # Handle user input
    if [ -z "$boot_choice" ]; then
        boot_choice="$default_option"
    fi
    
    case "$boot_choice" in
        1)
            echo -e "${GREEN}✓ Selected: Boot from Virtual Mac - CD will be available on desktop${NC}"
            BOOT_OPTION_RESULT=""
            ;;
        2)
            echo -e "${GREEN}✓ Selected: Boot from CD-ROM - use for installation or CD-based software${NC}"
            BOOT_OPTION_RESULT="-b"
            ;;
        *)
            echo -e "${RED}Invalid selection, using recommended option ($default_option)${NC}"
            if [ "$default_option" -eq 2 ]; then
                BOOT_OPTION_RESULT="-b"
            else
                BOOT_OPTION_RESULT=""
            fi
            ;;
    esac
}

#######################################
# Launch VM with selected config and CD
# Arguments:
#   config_file: Configuration file to use
#   cd_path: Path to CD image
# Globals:
#   CONFIGS_DIR
# Returns:
#   None
#######################################
launch_vm() {
    local config_file="$1"
    local cd_path="$2"
    local cd_key="$3"
    local config_path
    
    # Find the full path to config file in architecture-specific directories
    if [ -f "$CONFIGS_DIR/m68k/configs/$config_file" ]; then
        config_path="m68k/configs/$config_file"
    elif [ -f "$CONFIGS_DIR/ppc/configs/$config_file" ]; then
        config_path="ppc/configs/$config_file"
    else
        echo -e "${RED}Error: Config file not found: $config_file${NC}" >&2
        echo -e "Press Enter to continue..."
        read -r
        return
    fi
    
    # Get software name for display
    local software_name=$(get_cd_info "$cd_key" "name")
    
    # Show boot options menu and get user choice
    local boot_flag
    show_boot_options "$cd_key" "$software_name"
    boot_flag="$BOOT_OPTION_RESULT"
    
    echo
    echo -e "${CYAN}${BOLD}Launching Virtual Machine...${NC}"
    echo -e "${WHITE}Config: $config_file${NC}"
    echo -e "${WHITE}CD: $(basename "$cd_path")${NC}"
    echo
    echo -e "${GREEN}Manual command (for testing):${NC}"
    echo -e "${DIM}./runmac.sh -C \"$config_path\" -c \"$cd_path\" $boot_flag${NC}"
    echo
    echo -e "${DIM}Press Ctrl+Alt+G to release mouse, Ctrl+Alt+F to toggle fullscreen${NC}"
    echo -e "${DIM}Close QEMU window to return to menu${NC}"
    echo
    echo -e "${YELLOW}Starting in 3 seconds...${NC}"
    sleep 3
    
    # Launch the VM using unified dispatcher with appropriate boot flag
    cd "$CONFIGS_DIR" || return
    ./runmac.sh -C "$config_path" -c "$cd_path" $boot_flag
    
    echo
    echo -e "${GREEN}VM session ended. Press Enter to continue...${NC}"
    read -r
}


#######################################
# Show ROM download menu
# Arguments:
#   None
# Globals:
#   Various functions
# Returns:
#   None
#######################################
show_rom_menu() {
    while true; do
        print_header
        echo -e "${WHITE}${BOLD}💾 ROM Files:${NC}"
        echo
        echo -e "${DIM}ROM files are required for Mac emulation${NC}"
        echo
        
        local rom_keys=()
        local i=1
        
        # Read ROM list into array
        if command -v jq &> /dev/null; then
            while IFS= read -r rom_key; do
                [ -n "$rom_key" ] || continue
                rom_keys+=("$rom_key")
                
                local name=$(get_rom_info "$rom_key" "name")
                local filename=$(get_rom_info "$rom_key" "filename")
                
                # Check if ROM already exists in m68k directory (PPC uses built-in BIOS)
                local rom_path="$CONFIGS_DIR/m68k/$filename"
                
                if [ -n "$rom_path" ] && [ -f "$rom_path" ]; then
                    local status="${GREEN}✓ Installed${NC}"
                else
                    local status="${DIM}Not installed${NC}"
                fi
                
                printf "%b%2d)%b %b%s%b\n" "$GREEN" $i "$NC" "$BOLD" "$name" "$NC"
                printf "     File: %s\n" "$filename"
                printf "     Status: %b\n" "$status"
                echo
                
                ((i++))
            done < <(jq -r '.roms | keys[]' "$DATABASE_FILE" 2>/dev/null)
        else
            # Fallback for no jq
            echo -e "${YELLOW}⚠ jq not available, showing limited ROM info${NC}"
            echo -e "${GREEN}1)${NC} Quadra 800 ROM (800.ROM)"
            echo
            rom_keys=("quadra800")
        fi
        
        echo -e "${GREEN}b)${NC} 🔙 Back to main menu"
        echo
        echo -e -n "${YELLOW}Select ROM to download: ${NC}"
        
        read -r choice
        
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#rom_keys[@]}" ]; then
            local selected_rom="${rom_keys[$((choice-1))]}"
            handle_rom_download "$selected_rom"
        else
            echo -e "\n${RED}Invalid selection. Press Enter to continue...${NC}"
            read -r
        fi
    done
}


#######################################
# Handle ROM download to root directory
# Arguments:
#   rom_key: Selected ROM key
# Globals:
#   Various functions and constants
# Returns:
#   None
#######################################
handle_rom_download() {
    local rom_key="$1"
    local name=$(get_rom_info "$rom_key" "name")
    local filename=$(get_rom_info "$rom_key" "filename")
    local url=$(get_rom_info "$rom_key" "url")
    local md5=$(get_rom_info "$rom_key" "md5")
    
    print_header
    echo -e "${WHITE}${BOLD}Selected: $name${NC}"
    echo
    
    # ROM files are only needed for 68k architecture (PPC uses built-in BIOS)
    local rom_path="$CONFIGS_DIR/m68k/$filename"
    
    # Check if ROM already exists in architecture-specific location
    if [ -f "$rom_path" ]; then
        echo -e "${GREEN}✓ ROM already exists: $rom_path${NC}"
        echo -e "Press Enter to continue..."
        read -r
        return
    fi
    
    # Download ROM to m68k directory (68k architecture only)
    echo -e "${YELLOW}ROM not found. Downloading now...${NC}"
    echo
    
    # Ensure target directory exists
    mkdir -p "$(dirname "$rom_path")"
    
    if download_file "$url" "$rom_path" "$md5"; then
        echo -e "${GREEN}✓ ROM downloaded successfully!${NC}"
        echo -e "${GREEN}✓ Saved to: $rom_path${NC}"
    else
        echo -e "${RED}✗ ROM download failed${NC}"
    fi
    
    echo
    echo -e "Press Enter to continue..."
    read -r
}


#######################################
# Show downloaded files
# Arguments:
#   None
# Globals:
#   DOWNLOADS_DIR
# Returns:
#   None
#######################################
show_downloads() {
    print_header
    echo -e "${WHITE}${BOLD}📂 Downloaded Files:${NC}"
    echo
    
    if [ ! -d "$DOWNLOADS_DIR" ] || [ -z "$(ls -A "$DOWNLOADS_DIR" 2>/dev/null)" ]; then
        echo -e "${DIM}No files downloaded yet${NC}"
    else
        echo -e "${GREEN}Location: ${NC}$DOWNLOADS_DIR"
        echo
        
        local total_size=0
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
                local size_mb=$((size / 1024 / 1024))
                total_size=$((total_size + size))
                
                printf "%b•%b %b%s%b %b(%d MB)%b\n" "$GREEN" "$NC" "$BOLD" "$(basename "$file")" "$NC" "$DIM" "$size_mb" "$NC"
            fi
        done < <(find "$DOWNLOADS_DIR" -type f 2>/dev/null)
        
        echo
        local total_mb=$((total_size / 1024 / 1024))
        echo -e "${CYAN}Total: ${total_mb} MB${NC}"
    fi
    
    echo
    echo -e "${GREEN}b)${NC} 🔙 Back to main menu"
    echo
    echo -e -n "${YELLOW}Press 'b' for back or Enter to continue: ${NC}"
    read -r choice
}


#######################################
# Show system information
# Arguments:
#   None
# Globals:
#   Various paths and commands
# Returns:
#   None
#######################################
show_system_info() {
    print_header
    echo -e "${WHITE}${BOLD}⚙️  System Information:${NC}"
    echo
    
    # Check QEMU
    if command -v qemu-system-m68k &> /dev/null; then
        local qemu_version=$(qemu-system-m68k --version | head -n1)
        echo -e "${GREEN}✓${NC} QEMU: $qemu_version"
    else
        echo -e "${RED}✗${NC} QEMU m68k not found"
    fi
    
    # Check JSON parser
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}✓${NC} JSON Parser: jq available"
    else
        echo -e "${YELLOW}⚠${NC} JSON Parser: Using fallback (consider installing jq)"
    fi
    
    # Check download tools
    if command -v wget &> /dev/null; then
        echo -e "${GREEN}✓${NC} Download: wget available"
    elif command -v curl &> /dev/null; then
        echo -e "${GREEN}✓${NC} Download: curl available"
    else
        echo -e "${RED}✗${NC} Download: Neither wget nor curl found"
    fi
    
    echo
    echo -e "${WHITE}${BOLD}Library Status:${NC}"
    
    # Database
    if [ -f "$DATABASE_FILE" ]; then
        local cd_count=$(get_cd_list | wc -l)
        echo -e "${GREEN}✓${NC} Database: $cd_count CDs available"
    else
        echo -e "${RED}✗${NC} Database: Not found"
    fi
    
    # Downloads directory
    if [ -d "$DOWNLOADS_DIR" ]; then
        local download_count=$(find "$DOWNLOADS_DIR" -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}✓${NC} Downloads: $download_count files cached"
    else
        echo -e "${YELLOW}⚠${NC} Downloads: Directory will be created when needed"
    fi
    
    # Config files
    local config_count=$(get_config_list | wc -l)
    echo -e "${GREEN}✓${NC} Configs: $config_count system configurations found"
    
    echo
    echo -e "${GREEN}b)${NC} 🔙 Back to main menu"
    echo
    echo -e -n "${YELLOW}Press 'b' for back or Enter to continue: ${NC}"
    read -r choice
}
