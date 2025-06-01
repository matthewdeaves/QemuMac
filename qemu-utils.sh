#!/usr/bin/env bash

#######################################
# QEMU Mac Emulation Shared Utilities
# Contains common functions used across multiple scripts
# to reduce code duplication and improve maintainability
#######################################

# --- Default Configuration ---
# Only declare readonly variables if not already set
if [ "${QEMU_UTILS_INITIALIZED:-false}" != true ]; then
    readonly QEMU_UTILS_VERSION="1.0"
    readonly DEFAULT_QEMU_RAM="128"
    readonly DEFAULT_HDD_SIZE="1G"
    readonly DEFAULT_SHARED_HDD_SIZE="200M"
    readonly DEFAULT_BRIDGE_NAME="br0"
    readonly DEFAULT_MOUNT_POINT="/mnt/mac_shared"
    readonly SUPPORTED_FILESYSTEMS=("hfs" "hfsplus")
    readonly QEMU_MAC_PREFIX="52:54:00"
fi

# --- Error Handling and Validation Functions ---

#######################################
# Standard error checking with context and optional cleanup
# Arguments:
#   exit_code: The exit code to check
#   error_message: Error message to display
#   cleanup_function: Optional cleanup function to call on error
# Globals:
#   None
# Returns:
#   None
# Exits:
#   exit_code if non-zero
#######################################
check_exit_status() {
    local exit_code=$1
    local error_message="$2"
    local cleanup_function="${3:-}"
    
    if [ $exit_code -ne 0 ]; then
        echo "Error: $error_message" >&2
        if [ -n "$cleanup_function" ]; then
            $cleanup_function
        fi
        exit $exit_code
    fi
}

#######################################
# Enhanced error handler for strict mode
# Arguments:
#   line_no: Line number where error occurred
#   error_code: Exit code (optional, defaults to 1)
# Globals:
#   None
# Returns:
#   None
# Exits:
#   error_code
#######################################
error_exit() {
    local line_no=$1
    local error_code=${2:-1}
    echo "Error occurred in script at line: $line_no. Exit code: $error_code" >&2
    exit "$error_code"
}

#######################################
# Check if a command exists and is executable
# Arguments:
#   command_name: Name of the command to check
#   package_suggestion: Optional package installation suggestion
# Globals:
#   None
# Returns:
#   0 if command exists, 1 if not found
#######################################
check_command() {
    local command_name="$1"
    local package_suggestion="${2:-}"
    
    if ! command -v "$command_name" &> /dev/null; then
        echo "Error: Command '$command_name' not found." >&2
        if [ -n "$package_suggestion" ]; then
            echo "Please install it. Suggestion: $package_suggestion" >&2
        fi
        return 1
    fi
    return 0
}

# --- Directory and File Management Functions ---

#######################################
# Create directory with error handling and descriptive output
# Arguments:
#   dir_path: Path to directory to create
#   description: Optional description for logging (defaults to "directory")
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if directory creation fails
#######################################
ensure_directory() {
    local dir_path="$1"
    local description="${2:-directory}"
    
    if [ ! -d "$dir_path" ]; then
        echo "Creating $description: $dir_path"
        mkdir -p "$dir_path"
        check_exit_status $? "Failed to create $description '$dir_path'"
    fi
}

#######################################
# Validate file exists and is readable
# Arguments:
#   file_path: Path to file to validate
#   description: Optional description for error messages
# Globals:
#   None
# Returns:
#   0 if file exists and is readable, 1 otherwise
#######################################
validate_file_exists() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [ ! -f "$file_path" ]; then
        echo "Error: $description not found: $file_path" >&2
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        echo "Error: $description is not readable: $file_path" >&2
        return 1
    fi
    
    return 0
}

# --- Configuration Management Functions ---

#######################################
# Configuration schema definition for validation
# These associative arrays define required and optional configuration variables
#######################################
declare -A REQUIRED_CONFIG_VARS=(
    ["QEMU_MACHINE"]="QEMU machine type (e.g., q800)"
    ["QEMU_ROM"]="ROM file path"
    ["QEMU_HDD"]="Hard disk image path"
    ["QEMU_SHARED_HDD"]="Shared disk image path"
    ["QEMU_RAM"]="RAM amount in MB"
    ["QEMU_GRAPHICS"]="Graphics settings (e.g., 1152x870x8)"
    ["QEMU_PRAM"]="PRAM file path"
)

declare -A OPTIONAL_CONFIG_VARS=(
    ["QEMU_CPU"]="CPU type override"
    ["QEMU_HDD_SIZE"]="Hard disk size (default: $DEFAULT_HDD_SIZE)"
    ["QEMU_SHARED_HDD_SIZE"]="Shared disk size (default: $DEFAULT_SHARED_HDD_SIZE)"
    ["BRIDGE_NAME"]="Network bridge name (default: $DEFAULT_BRIDGE_NAME)"
    ["QEMU_TAP_IFACE"]="TAP interface name"
    ["QEMU_MAC_ADDR"]="MAC address"
    ["QEMU_USER_SMB_DIR"]="SMB share directory for user mode"
)

#######################################
# Load and validate QEMU configuration from file
# Arguments:
#   config_file: Path to configuration file
# Globals:
#   Sources all variables from config file
# Returns:
#   None
# Exits:
#   1 if config file not found or validation fails
#######################################
load_qemu_config() {
    local config_file="$1"
    
    validate_file_exists "$config_file" "Configuration file" || exit 1
    
    echo "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file"
    check_exit_status $? "Failed to source configuration file '$config_file'"
    
    # Extract config name for potential use
    CONFIG_NAME=$(basename "$config_file" .conf)
    
    validate_config_schema "$config_file"
}

#######################################
# Validate configuration against schema
# Arguments:
#   config_file: Path to configuration file (for error messages)
# Globals:
#   Reads all configuration variables
# Returns:
#   None
# Exits:
#   1 if required variables are missing
#######################################
validate_config_schema() {
    local config_file="$1"
    local missing_vars=()
    
    # Check required variables
    for var in "${!REQUIRED_CONFIG_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var (${REQUIRED_CONFIG_VARS[$var]})")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "Error: Config file $config_file is missing required variables:" >&2
        printf "  - %s\n" "${missing_vars[@]}" >&2
        exit 1
    fi
    
    # Validate ROM file exists (critical check)
    validate_file_exists "$QEMU_ROM" "ROM file" || exit 1
}

#######################################
# Validate configuration filename format
# Arguments:
#   config_filename: Name of config file to validate
# Globals:
#   None
# Returns:
#   0 if valid format, 1 if invalid
#######################################
validate_config_filename() {
    local config_filename="$1"
    
    # Only allow alphanumeric, dots, dashes, underscores, and must end with .conf
    if [[ ! "$config_filename" =~ ^[a-zA-Z0-9._-]+\.conf$ ]]; then
        echo "Error: Invalid config filename format: $config_filename" >&2
        echo "Config files must contain only alphanumeric characters, dots, dashes, underscores and end with .conf" >&2
        return 1
    fi
    
    return 0
}

# --- Security and Input Validation Functions ---

#######################################
# Sanitize string for use in system commands
# Arguments:
#   input_string: String to sanitize
# Globals:
#   None
# Returns:
#   Sanitized string via stdout
#######################################
sanitize_string() {
    local input_string="$1"
    # Remove non-alphanumeric characters except dots, dashes, underscores
    echo "$input_string" | sed 's/[^a-zA-Z0-9._-]//g'
}

#######################################
# Build command array safely to avoid injection
# Arguments:
#   Array elements passed as arguments
# Globals:
#   Sets cmd_array variable
# Returns:
#   None
#######################################
build_safe_command() {
    cmd_array=("$@")
}

# --- Network Utility Functions ---

#######################################
# Generate a random MAC address with QEMU prefix
# Arguments:
#   None
# Globals:
#   QEMU_MAC_PREFIX
# Returns:
#   MAC address string via stdout
#######################################
generate_mac_address() {
    local hexchars="0123456789ABCDEF"
    local mac_suffix=""
    
    # Generate 6 random hex characters for the suffix
    for i in {1..6}; do
        mac_suffix+="${hexchars:$(( RANDOM % 16 )):1}"
    done
    
    # Format with colons: XX:XX:XX
    echo "$QEMU_MAC_PREFIX:$(echo "$mac_suffix" | sed -e 's/\(..\)/\1:/g' -e 's/:$//')"
}

#######################################
# Generate TAP device name from config name
# Arguments:
#   config_base_name: Base name of config file
# Globals:
#   None
# Returns:
#   TAP interface name via stdout
#######################################
generate_tap_name() {
    local config_base_name="$1"
    local sanitized_name
    
    sanitized_name=$(sanitize_string "$config_base_name")
    # Limit length to avoid exceeding interface name limits (IFNAMSIZ is often 16)
    echo "tap_${sanitized_name:0:10}"
}

# --- Package Management Functions ---

#######################################
# Check if a Debian/Ubuntu package is installed
# Arguments:
#   package_name: Name of package to check
# Globals:
#   None
# Returns:
#   0 if package is installed, 1 if not
#######################################
check_package_installed() {
    local package_name="$1"
    dpkg -l "$package_name" &> /dev/null
    return $?
}

#######################################
# Install required packages with error checking
# Arguments:
#   List of package names
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if package installation fails
#######################################
install_packages() {
    local packages=("$@")
    local packages_to_install=()
    
    echo "Checking for required packages..."
    
    # Check which packages need installation
    for package in "${packages[@]}"; do
        if ! check_package_installed "$package"; then
            packages_to_install+=("$package")
        fi
    done
    
    # Install packages if needed
    if [ ${#packages_to_install[@]} -gt 0 ]; then
        echo "Installing required packages: ${packages_to_install[*]}"
        sudo apt-get update
        sudo apt-get install -y "${packages_to_install[@]}"
        check_exit_status $? "Failed to install required packages: ${packages_to_install[*]}"
        echo "Required packages installed successfully."
    else
        echo "All required packages are already installed."
    fi
}

# --- Logging and Debug Functions ---

#######################################
# Enhanced debug output with timestamp
# Arguments:
#   message: Debug message to display
# Globals:
#   DEBUG_MODE: Whether debug mode is enabled
# Returns:
#   None
#######################################
debug_log() {
    local message="$1"
    if [ "${DEBUG_MODE:-false}" = true ]; then
        echo "[DEBUG $(date '+%H:%M:%S')] $message" >&2
    fi
}

#######################################
# Display information message with consistent formatting
# Arguments:
#   message: Information message to display
# Globals:
#   None
# Returns:
#   None
#######################################
info_log() {
    local message="$1"
    echo "Info: $message" >&2
}

#######################################
# Display warning message with consistent formatting
# Arguments:
#   message: Warning message to display
# Globals:
#   None
# Returns:
#   None
#######################################
warning_log() {
    local message="$1"
    echo "Warning: $message" >&2
}

# --- Version and Compatibility Functions ---

#######################################
# Compare version strings
# Arguments:
#   version1: First version string
#   operator: Comparison operator (>=, <=, ==, !=, >, <)
#   version2: Second version string
# Globals:
#   None
# Returns:
#   0 if comparison is true, 1 if false
#######################################
version_compare() {
    local version1="$1"
    local operator="$2"
    local version2="$3"
    
    # Use sort -V for version comparison
    local comparison_result
    case "$operator" in
        ">=")
            printf '%s\n%s\n' "$version2" "$version1" | sort -V | head -n1 | grep -Fxq "$version2"
            ;;
        "<=")
            printf '%s\n%s\n' "$version1" "$version2" | sort -V | head -n1 | grep -Fxq "$version1"
            ;;
        "==")
            [ "$version1" = "$version2" ]
            ;;
        "!=")
            [ "$version1" != "$version2" ]
            ;;
        ">")
            ! version_compare "$version1" "<=" "$version2"
            ;;
        "<")
            ! version_compare "$version1" ">=" "$version2"
            ;;
        *)
            echo "Error: Unknown comparison operator: $operator" >&2
            return 1
            ;;
    esac
}

#######################################
# Check QEMU version compatibility
# Arguments:
#   required_version: Minimum required version
# Globals:
#   None
# Returns:
#   None (displays warning if version is incompatible)
#######################################
check_qemu_version() {
    local required_version="$1"
    local current_version
    
    if ! check_command "qemu-system-m68k" "qemu-system-m68k package"; then
        return 1
    fi
    
    current_version=$(qemu-system-m68k --version | sed -n 's/.*version \([0-9.]*\).*/\1/p' | head -n1)
    
    if [ -z "$current_version" ]; then
        warning_log "Could not determine QEMU version"
        return 1
    fi
    
    if ! version_compare "$current_version" ">=" "$required_version"; then
        warning_log "QEMU version $current_version may not be compatible. Required: $required_version+"
    else
        debug_log "QEMU version $current_version meets requirements (>= $required_version)"
    fi
}

# --- Initialization ---

#######################################
# Initialize shared utilities with strict mode
# Arguments:
#   None
# Globals:
#   Sets up error handling and strict mode
# Returns:
#   None
#######################################
init_qemu_utils() {
    # Set strict bash mode for better error handling
    set -o errexit   # Exit immediately if a command exits with a non-zero status
    set -o nounset   # Treat unset variables as an error when substituting
    set -o pipefail  # Pipelines return status of the last command to exit with non-zero status
    
    # Set up error trap for enhanced error reporting
    trap 'error_exit ${LINENO}' ERR
    
    debug_log "QEMU utilities initialized (version $QEMU_UTILS_VERSION)"
}

# Auto-initialize when sourced (only if not already initialized)
if [ "${QEMU_UTILS_INITIALIZED:-false}" != true ]; then
    init_qemu_utils
    readonly QEMU_UTILS_INITIALIZED=true
fi