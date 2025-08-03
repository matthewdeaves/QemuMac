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
    readonly DEFAULT_AUDIO_BACKEND="pa"
    readonly DEFAULT_AUDIO_LATENCY="50000"
    readonly DEFAULT_ASC_MODE="easc"
    readonly DEFAULT_SCSI_CACHE_MODE="writethrough"
    readonly DEFAULT_SCSI_AIO_MODE="threads"
    readonly DEFAULT_SCSI_VENDOR="SEAGATE"
    readonly DEFAULT_SCSI_SERIAL_PREFIX="QOS"
    readonly DEFAULT_DISPLAY_DEVICE="built-in"
    readonly DEFAULT_RESOLUTION_PRESET="mac_standard"
    readonly DEFAULT_FLOPPY_READONLY="true"
    readonly DEFAULT_FLOPPY_FORMAT="mac"
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
    ["QEMU_AUDIO_BACKEND"]="Audio backend (pa, alsa, sdl, none)"
    ["QEMU_AUDIO_LATENCY"]="Audio latency in microseconds"
    ["QEMU_ASC_MODE"]="Apple Sound Chip mode (easc or asc)"
    ["QEMU_CPU_MODEL"]="Explicit CPU model (m68000-m68060)"
    ["QEMU_TCG_THREAD_MODE"]="TCG threading mode (single or multi)"
    ["QEMU_TB_SIZE"]="Translation block cache size"
    ["QEMU_MEMORY_BACKEND"]="Memory backend type (ram, file, memfd)"
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

#######################################
# Validate audio backend configuration
# Arguments:
#   audio_backend: Audio backend to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_audio_backend() {
    local audio_backend="$1"
    local valid_backends=("pa" "alsa" "sdl" "oss" "none" "wav" "spice" "dbus" "pipewire")
    
    if [ -z "$audio_backend" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for backend in "${valid_backends[@]}"; do
        if [ "$audio_backend" = "$backend" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid audio backend '$audio_backend'" >&2
    echo "Valid backends: ${valid_backends[*]}" >&2
    return 1
}

#######################################
# Validate ASC mode configuration
# Arguments:
#   asc_mode: ASC mode to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_asc_mode() {
    local asc_mode="$1"
    local valid_modes=("easc" "asc")
    
    if [ -z "$asc_mode" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for mode in "${valid_modes[@]}"; do
        if [ "$asc_mode" = "$mode" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid ASC mode '$asc_mode'" >&2
    echo "Valid modes: ${valid_modes[*]}" >&2
    return 1
}

#######################################
# Validate CPU model for m68k emulation
# Arguments:
#   cpu_model: CPU model to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_cpu_model() {
    local cpu_model="$1"
    local valid_models=("m68000" "m68010" "m68020" "m68030" "m68040" "m68060")
    
    if [ -z "$cpu_model" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    for model in "${valid_models[@]}"; do
        if [ "$cpu_model" = "$model" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid CPU model '$cpu_model'" >&2
    echo "Valid m68k CPU models: ${valid_models[*]}" >&2
    return 1
}

#######################################
# Validate TCG thread mode
# Arguments:
#   thread_mode: TCG threading mode to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_tcg_thread_mode() {
    local thread_mode="$1"
    local valid_modes=("single" "multi")
    
    if [ -z "$thread_mode" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    for mode in "${valid_modes[@]}"; do
        if [ "$thread_mode" = "$mode" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid TCG thread mode '$thread_mode'" >&2
    echo "Valid modes: ${valid_modes[*]}" >&2
    return 1
}

#######################################
# Validate memory backend type
# Arguments:
#   backend_type: Memory backend type to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_memory_backend() {
    local backend_type="$1"
    local valid_backends=("ram" "file" "memfd")
    
    if [ -z "$backend_type" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    for backend in "${valid_backends[@]}"; do
        if [ "$backend_type" = "$backend" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid memory backend type '$backend_type'" >&2
    echo "Valid backends: ${valid_backends[*]}" >&2
    return 1
}

#######################################
# Validate translation block cache size
# Arguments:
#   tb_size: Translation block cache size to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_tb_size() {
    local tb_size="$1"
    
    if [ -z "$tb_size" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    # Check if it's a positive integer
    if ! [[ "$tb_size" =~ ^[0-9]+$ ]] || [ "$tb_size" -le 0 ]; then
        echo "Error: Invalid translation block cache size '$tb_size'" >&2
        echo "Must be a positive integer (recommended: 64-1024)" >&2
        return 1
    fi
    
    # Warn for unusual values
    if [ "$tb_size" -lt 64 ] || [ "$tb_size" -gt 1024 ]; then
        warning_log "TB cache size '$tb_size' is outside recommended range (64-1024)"
    fi
    
    return 0
}

#######################################
# Validate SCSI cache mode
# Arguments:
#   cache_mode: SCSI cache mode to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_scsi_cache_mode() {
    local cache_mode="$1"
    local valid_modes=("writethrough" "writeback" "none" "directsync")
    
    if [ -z "$cache_mode" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    for mode in "${valid_modes[@]}"; do
        if [ "$cache_mode" = "$mode" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid SCSI cache mode '$cache_mode'" >&2
    echo "Valid modes: ${valid_modes[*]}" >&2
    echo "  writethrough: Safe, writes go through to disk" >&2
    echo "  writeback: Fast, but requires proper VM shutdown" >&2
    echo "  none: Safest, direct I/O to disk" >&2
    echo "  directsync: Direct I/O with sync" >&2
    return 1
}

#######################################
# Validate SCSI AIO mode
# Arguments:
#   aio_mode: SCSI AIO mode to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_scsi_aio_mode() {
    local aio_mode="$1"
    local valid_modes=("threads" "native")
    
    if [ -z "$aio_mode" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    for mode in "${valid_modes[@]}"; do
        if [ "$aio_mode" = "$mode" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid SCSI AIO mode '$aio_mode'" >&2
    echo "Valid modes: ${valid_modes[*]}" >&2
    echo "  threads: Multi-threaded AIO (default, works everywhere)" >&2
    echo "  native: Native AIO (Linux only, better performance)" >&2
    return 1
}

#######################################
# Validate SCSI vendor string
# Arguments:
#   vendor: SCSI vendor string to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_scsi_vendor() {
    local vendor="$1"
    
    if [ -z "$vendor" ]; then
        return 0  # Empty is valid (will use QEMU default)
    fi
    
    # SCSI vendor field is 8 characters max, alphanumeric and spaces
    if [ ${#vendor} -gt 8 ]; then
        echo "Error: SCSI vendor string '$vendor' too long (max 8 characters)" >&2
        return 1
    fi
    
    if ! [[ "$vendor" =~ ^[A-Z0-9\ ]+$ ]]; then
        echo "Error: SCSI vendor string '$vendor' contains invalid characters" >&2
        echo "Must contain only uppercase letters, numbers, and spaces" >&2
        return 1
    fi
    
    return 0
}

#######################################
# Validate SCSI serial prefix
# Arguments:
#   serial_prefix: SCSI serial number prefix to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_scsi_serial_prefix() {
    local serial_prefix="$1"
    
    if [ -z "$serial_prefix" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    # Serial prefix should be 3-4 characters, alphanumeric
    if [ ${#serial_prefix} -lt 2 ] || [ ${#serial_prefix} -gt 4 ]; then
        echo "Error: SCSI serial prefix '$serial_prefix' must be 2-4 characters" >&2
        return 1
    fi
    
    if ! [[ "$serial_prefix" =~ ^[A-Z0-9]+$ ]]; then
        echo "Error: SCSI serial prefix '$serial_prefix' contains invalid characters" >&2
        echo "Must contain only uppercase letters and numbers" >&2
        return 1
    fi
    
    return 0
}

#######################################
# Validate display device type
# Arguments:
#   display_device: Display device type to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_display_device() {
    local display_device="$1"
    local valid_devices=("built-in" "nubus-macfb")
    
    if [ -z "$display_device" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for device in "${valid_devices[@]}"; do
        if [ "$display_device" = "$device" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid display device '$display_device'" >&2
    echo "Valid devices: ${valid_devices[*]}" >&2
    echo "  built-in: Standard Q800 built-in display" >&2
    echo "  nubus-macfb: NuBus framebuffer device" >&2
    return 1
}

#######################################
# Validate resolution preset
# Arguments:
#   resolution_preset: Resolution preset name to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_resolution_preset() {
    local resolution_preset="$1"
    local valid_presets=("mac_standard" "vga" "svga" "xga" "sxga")
    
    if [ -z "$resolution_preset" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for preset in "${valid_presets[@]}"; do
        if [ "$resolution_preset" = "$preset" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid resolution preset '$resolution_preset'" >&2
    echo "Valid presets: ${valid_presets[*]}" >&2
    echo "  mac_standard: 1152x870x8 (Mac 21-inch)" >&2
    echo "  vga: 640x480x8 (VGA)" >&2
    echo "  svga: 800x600x8 (Super VGA)" >&2
    echo "  xga: 1024x768x8 (Extended VGA)" >&2
    echo "  sxga: 1280x1024x8 (Super XGA)" >&2
    return 1
}

#######################################
# Get resolution from preset name
# Arguments:
#   resolution_preset: Resolution preset name
# Globals:
#   None
# Returns:
#   Resolution string via stdout
#######################################
get_resolution_from_preset() {
    local resolution_preset="$1"
    
    case "$resolution_preset" in
        "mac_standard")
            echo "1152x870x8"
            ;;
        "vga")
            echo "640x480x8"
            ;;
        "svga")
            echo "800x600x8"
            ;;
        "xga")
            echo "1024x768x8"
            ;;
        "sxga")
            echo "1280x1024x8"
            ;;
        *)
            echo "1152x870x8"  # Default fallback
            ;;
    esac
}

#######################################
# Validate floppy readonly setting
# Arguments:
#   readonly_mode: Floppy readonly mode to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_floppy_readonly() {
    local readonly_mode="$1"
    local valid_modes=("true" "false")
    
    if [ -z "$readonly_mode" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for mode in "${valid_modes[@]}"; do
        if [ "$readonly_mode" = "$mode" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid floppy readonly mode '$readonly_mode'" >&2
    echo "Valid modes: ${valid_modes[*]}" >&2
    echo "  true: Read-only access (safe, prevents data loss)" >&2
    echo "  false: Read-write access (allows modifications)" >&2
    return 1
}

#######################################
# Validate floppy format
# Arguments:
#   floppy_format: Floppy format to validate
# Globals:
#   None
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_floppy_format() {
    local floppy_format="$1"
    local valid_formats=("mac" "pc")
    
    if [ -z "$floppy_format" ]; then
        return 0  # Empty is valid (will use default)
    fi
    
    for format in "${valid_formats[@]}"; do
        if [ "$floppy_format" = "$format" ]; then
            return 0
        fi
    done
    
    echo "Error: Invalid floppy format '$floppy_format'" >&2
    echo "Valid formats: ${valid_formats[*]}" >&2
    echo "  mac: Mac-formatted floppy disks" >&2
    echo "  pc: PC-formatted floppy disks" >&2
    return 1
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

#######################################
# Install all QEMU Mac emulation dependencies
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if installation fails or unsupported system
#######################################
install_qemu_dependencies() {
    echo "Installing QEMU Mac emulation dependencies..."
    
    # Detect package manager and install accordingly
    if command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu system (apt)"
        local core_packages=(
            "qemu-system-m68k"      # QEMU m68k emulation
            "qemu-utils"            # QEMU utilities (qemu-img, etc.)
            "coreutils"             # Core utilities (dd, printf, etc.)
            "bsdmainutils"          # BSD utilities (hexdump, etc.)
            "jq"                    # JSON processor (for mac-library tool)
        )
        
        local networking_packages=(
            "bridge-utils"          # Bridge utilities (brctl)
            "iproute2"              # IP route utilities
            "passt"                 # Modern userspace networking
        )
        
        local filesystem_packages=(
            "hfsprogs"              # HFS+ filesystem support
            "hfsplus"               # Additional HFS+ tools
        )
        
        echo "Installing core QEMU packages..."
        install_packages "${core_packages[@]}"
        
        echo "Installing networking packages..."
        install_packages "${networking_packages[@]}"
        
        echo "Installing filesystem packages..."
        install_packages "${filesystem_packages[@]}"
        
    elif command -v brew &> /dev/null; then
        echo "Detected macOS system (Homebrew)"
        local brew_packages=(
            "qemu"                  # QEMU (includes m68k support)
            "bash"                  # Modern bash (macOS default is old)
            "jq"                    # JSON processor (for mac-library tool)
        )
        
        echo "Installing packages via Homebrew..."
        for package in "${brew_packages[@]}"; do
            if ! brew list "$package" &> /dev/null; then
                echo "Installing $package..."
                brew install "$package" || {
                    echo "Warning: Failed to install $package via Homebrew" >&2
                }
            else
                echo "$package is already installed"
            fi
        done
        
        echo ""
        echo "macOS Networking Notes:"
        echo "  - TAP networking requires Linux-specific tools and is not available on macOS"
        echo "  - Passt networking is Linux-only and not available via Homebrew"
        echo "  - Use User Mode networking (-N user) for internet access on macOS"
        echo "  - Bridge utilities and iproute2 are Linux-specific"
        echo ""
        echo "Recommended network mode for macOS: ./run68k.sh -C config.conf -N user"
        
    elif command -v dnf &> /dev/null; then
        echo "Detected Fedora/RHEL system (dnf)"
        local fedora_packages=(
            "qemu-system-m68k"
            "qemu-img"
            "bridge-utils"
            "iproute"
            "passt"
            "hfsprogs"
            "jq"
        )
        
        echo "Installing packages via dnf..."
        sudo dnf install -y "${fedora_packages[@]}" || {
            echo "Error: Failed to install packages via dnf" >&2
            return 1
        }
        
    else
        echo "Error: Unsupported package manager. Please manually install:" >&2
        echo "  - qemu-system-m68k (QEMU m68k emulation)" >&2
        echo "  - qemu-utils (QEMU utilities)" >&2
        echo "  - bridge-utils (for TAP networking)" >&2
        echo "  - iproute2 (for TAP networking)" >&2
        echo "  - passt (modern networking)" >&2
        echo "  - hfsprogs (HFS+ support)" >&2
        return 1
    fi
    
    echo "Dependency installation completed successfully!"
    echo "You can now run QEMU Mac emulation with all networking modes supported."
}

#######################################
# Check and offer to install missing dependencies
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
#######################################
check_and_offer_install() {
    local missing_deps=()
    
    # Check core dependencies
    if ! command -v qemu-system-m68k &> /dev/null; then
        missing_deps+=("qemu-system-m68k")
    fi
    
    if ! command -v qemu-img &> /dev/null; then
        missing_deps+=("qemu-img")
    fi
    
    # Check networking dependencies
    if ! command -v brctl &> /dev/null; then
        missing_deps+=("bridge-utils")
    fi
    
    if ! command -v ip &> /dev/null; then
        missing_deps+=("iproute2")
    fi
    
    if ! command -v passt &> /dev/null; then
        missing_deps+=("passt")
    fi
    
    # If dependencies are missing, offer to install
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing dependencies detected: ${missing_deps[*]}"
        echo "Would you like to install them automatically? [y/N]"
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_qemu_dependencies
        else
            echo "Please install the missing dependencies manually before running the emulation."
            return 1
        fi
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