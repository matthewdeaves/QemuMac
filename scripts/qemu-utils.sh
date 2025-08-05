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
    ["QEMU_AUDIO_BACKEND"]="Audio backend (pa, alsa, none)"
    ["QEMU_AUDIO_LATENCY"]="Audio latency in microseconds"
    ["QEMU_ASC_MODE"]="Apple Sound Chip mode (easc or asc)"
    ["QEMU_TCG_THREAD_MODE"]="TCG threading mode (single or multi)"
    ["QEMU_TB_SIZE"]="Translation block cache size"
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

# Audio backend validation removed - simplified configs use trusted defaults

# ASC mode validation removed - simplified configs use trusted defaults

# CPU model validation removed - simplified configs use trusted defaults

# TCG thread mode validation removed - simplified configs use trusted defaults

# Memory backend validation removed - simplified configs use trusted defaults

# Translation block cache size validation removed - simplified configs use trusted defaults

# SCSI cache mode validation removed - simplified configs use trusted defaults

# SCSI AIO mode validation removed - simplified configs use trusted defaults

# SCSI vendor validation removed - simplified configs use trusted defaults

# SCSI serial prefix validation removed - simplified configs use trusted defaults

# Display device validation removed - simplified configs use trusted defaults

# Resolution preset validation removed - simplified configs use trusted defaults

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

# Floppy readonly validation removed - simplified configs use trusted defaults

# Floppy format validation removed - simplified configs use trusted defaults

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
# Install all QEMU Mac emulation dependencies by building from source
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
    echo "=== Installing QEMU Mac emulation dependencies from source ==="
    echo "This will build the latest QEMU version for optimal Mac emulation compatibility."
    echo ""
    
    # Detect platform and install build dependencies
    if command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu system (apt)"
        install_qemu_ubuntu_dependencies
        build_qemu_from_source
        
    elif command -v brew &> /dev/null; then
        echo "Detected macOS system (Homebrew)"
        install_qemu_macos_dependencies
        build_qemu_from_source_macos
        
    elif command -v dnf &> /dev/null; then
        echo "Detected Fedora/RHEL system (dnf)"
        install_qemu_fedora_dependencies
        build_qemu_from_source
        
    else
        echo "Error: Unsupported system. Currently supported:" >&2
        echo "  - Debian/Ubuntu (apt-get)" >&2
        echo "  - macOS (Homebrew)" >&2
        echo "  - Fedora/RHEL (dnf)" >&2
        return 1
    fi
    
    echo ""
    echo "=== QEMU source build completed successfully! ==="
    echo "Latest QEMU installed with Mac emulation optimizations."
}

#######################################
# Install QEMU build dependencies on Ubuntu/Debian
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if installation fails
#######################################
install_qemu_ubuntu_dependencies() {
    echo "Step 1: Removing any existing QEMU packages..."
    sudo apt remove --purge -y qemu-system qemu-system-ppc qemu-system-x86 qemu-system-arm qemu-system-mips qemu-system-misc qemu-system-s390x qemu-system-sparc qemu-utils qemu-system-gui qemu-system-common qemu-system-data qemu-block-extra qemu-system-modules-opengl qemu-system-modules-spice 2>/dev/null || true
    sudo apt autoremove -y
    echo "✓ Existing QEMU packages removed"
    echo ""
    
    echo "Step 2: Installing build dependencies..."
    sudo apt update
    
    local build_packages=(
        "git" "build-essential" "pkg-config" "libglib2.0-dev" "libfdt-dev" 
        "libpixman-1-dev" "zlib1g-dev" "ninja-build" "libslirp-dev" 
        "libcap-ng-dev" "libattr1-dev" "libssl-dev" "python3-sphinx" 
        "python3-sphinx-rtd-theme" "libaio-dev" "libbluetooth-dev" 
        "libbrlapi-dev" "libbz2-dev" "libcap-dev" "libcurl4-gnutls-dev" 
        "libgtk-3-dev" "libibverbs-dev" "libjpeg8-dev" "libncurses5-dev" 
        "libnuma-dev" "librbd-dev" "librdmacm-dev" "libsasl2-dev" 
        "libsdl2-dev" "libseccomp-dev" "libsnappy-dev" "libssh-dev" 
        "libvde-dev" "libvdeplug-dev" "libvte-2.91-dev" "libxen-dev" 
        "liblzo2-dev" "valgrind" "xfslibs-dev" "libnfs-dev" "libiscsi-dev"
    )
    
    local core_packages=(
        "coreutils"     # Core utilities (dd, printf, etc.)
        "bsdmainutils"  # BSD utilities (hexdump, etc.)
        "jq"            # JSON processor (for mac-library tool)
        "hfsprogs"      # HFS+ filesystem support
        "hfsplus"       # Additional HFS+ tools
    )
    
    sudo apt install -y "${build_packages[@]}" "${core_packages[@]}"
    check_exit_status $? "Failed to install build dependencies"
    echo "✓ Build dependencies installed"
    echo ""
}

#######################################
# Install QEMU build dependencies on macOS with Homebrew
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if installation fails
#######################################
install_qemu_macos_dependencies() {
    echo "Step 1: Installing build dependencies via Homebrew..."
    
    # Remove existing QEMU if installed via Homebrew
    if brew list qemu &> /dev/null; then
        echo "Removing existing Homebrew QEMU package..."
        brew uninstall qemu || true
    fi
    
    local build_packages=(
        "libffi" "gettext" "glib" "pkg-config" "pixman" "ninja" "meson"
        "git" "bash" "jq"
    )
    
    for package in "${build_packages[@]}"; do
        if ! brew list "$package" &> /dev/null; then
            echo "Installing $package..."
            brew install "$package" || {
                echo "Error: Failed to install $package via Homebrew" >&2
                return 1
            }
        else
            echo "✓ $package already installed"
        fi
    done
    
    echo "✓ Build dependencies installed"
    echo ""
}

#######################################
# Install QEMU build dependencies on Fedora/RHEL
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if installation fails
#######################################
install_qemu_fedora_dependencies() {
    echo "Step 1: Removing any existing QEMU packages..."
    sudo dnf remove -y qemu-system-m68k qemu-system-ppc qemu-img 2>/dev/null || true
    echo "✓ Existing QEMU packages removed"
    echo ""
    
    echo "Step 2: Installing build dependencies..."
    local build_packages=(
        "git" "make" "gcc" "gcc-c++" "pkg-config" "glib2-devel" 
        "libfdt-devel" "pixman-devel" "zlib-devel" "ninja-build"
        "libslirp-devel" "libcap-ng-devel" "libattr-devel" 
        "openssl-devel" "python3-sphinx" "libaio-devel" 
        "bluez-libs-devel" "bzip2-devel" "libcap-devel" 
        "libcurl-devel" "gtk3-devel" "libjpeg-turbo-devel" 
        "ncurses-devel" "numactl-devel" "libseccomp-devel" 
        "snappy-devel" "libssh-devel" "lzo-devel" "jq" "hfsprogs"
    )
    
    sudo dnf install -y "${build_packages[@]}"
    check_exit_status $? "Failed to install build dependencies"
    echo "✓ Build dependencies installed"
    echo ""
}

#######################################
# Build QEMU from source (Linux systems)
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if build fails
#######################################
build_qemu_from_source() {
    echo "Step 3: Cloning QEMU source..."
    
    # Remove existing qemu directory if it exists
    if [ -d "qemu" ]; then
        echo "Removing existing qemu directory..."
        rm -rf qemu
    fi
    
    git clone https://gitlab.com/qemu-project/qemu.git
    check_exit_status $? "Failed to clone QEMU source"
    cd qemu
    echo "✓ QEMU source cloned"
    echo ""
    
    echo "Step 4: Configuring build..."
    ./configure --target-list=m68k-softmmu,ppc-softmmu --enable-slirp \
        --enable-gtk --enable-sdl --enable-curses --enable-vnc \
        --enable-tools --enable-guest-agent
    check_exit_status $? "Failed to configure QEMU build"
    echo "✓ Build configured"
    echo ""
    
    echo "Step 5: Building QEMU (this will take 15-30+ minutes)..."
    echo "Using $(nproc) CPU cores for parallel compilation..."
    make -j$(nproc)
    check_exit_status $? "Failed to build QEMU"
    echo "✓ QEMU built successfully"
    echo ""
    
    echo "Step 6: Installing QEMU system-wide..."
    sudo make install
    check_exit_status $? "Failed to install QEMU"
    echo "✓ QEMU installed to /usr/local/bin/"
    echo ""
    
    # Clean up source directory
    echo "Step 7: Cleaning up source directory..."
    cd ..
    rm -rf qemu
    echo "✓ Source directory cleaned up"
    echo ""
    
    echo "Step 8: Verifying installation..."
    echo "QEMU PowerPC version:"
    qemu-system-ppc --version | head -1
    echo ""
    echo "QEMU m68k version:"
    qemu-system-m68k --version | head -1
    echo ""
    echo "Installation paths:"
    which qemu-system-ppc
    which qemu-system-m68k
    echo ""
}

#######################################
# Build QEMU from source on macOS
# Arguments:
#   None
# Globals:
#   None
# Returns:
#   None
# Exits:
#   1 if build fails
#######################################
build_qemu_from_source_macos() {
    echo "Step 2: Cloning QEMU source..."
    
    # Remove existing qemu directory if it exists
    if [ -d "qemu" ]; then
        echo "Removing existing qemu directory..."
        rm -rf qemu
    fi
    
    git clone https://gitlab.com/qemu-project/qemu.git
    check_exit_status $? "Failed to clone QEMU source"
    cd qemu
    echo "✓ QEMU source cloned"
    echo ""
    
    echo "Step 3: Configuring build..."
    ./configure --target-list=m68k-softmmu,ppc-softmmu --enable-slirp \
        --enable-cocoa --enable-curses --enable-vnc --enable-tools \
        --enable-guest-agent
    check_exit_status $? "Failed to configure QEMU build"
    echo "✓ Build configured"
    echo ""
    
    echo "Step 4: Building QEMU (this will take 15-30+ minutes)..."
    echo "Using $(sysctl -n hw.ncpu) CPU cores for parallel compilation..."
    gmake -j$(sysctl -n hw.ncpu) 2>/dev/null || make -j$(sysctl -n hw.ncpu)
    check_exit_status $? "Failed to build QEMU"
    echo "✓ QEMU built successfully"
    echo ""
    
    echo "Step 5: Installing QEMU system-wide..."
    sudo gmake install 2>/dev/null || sudo make install
    check_exit_status $? "Failed to install QEMU"
    echo "✓ QEMU installed to /usr/local/bin/"
    echo ""
    
    # Clean up source directory
    echo "Step 6: Cleaning up source directory..."
    cd ..
    rm -rf qemu
    echo "✓ Source directory cleaned up"
    echo ""
    
    echo "Step 7: Verifying installation..."
    echo "QEMU PowerPC version:"
    /usr/local/bin/qemu-system-ppc --version | head -1
    echo ""
    echo "QEMU m68k version:"
    /usr/local/bin/qemu-system-m68k --version | head -1
    echo ""
    echo "Installation paths:"
    which qemu-system-ppc
    which qemu-system-m68k
    echo ""
    
    echo "macOS Notes:"
    echo "  - User-mode networking is used by default (no additional setup required)"
    echo "  - Supports both m68k and PowerPC Mac emulation"
    echo "  - You may need to restart your terminal or run 'hash -r' to refresh PATH cache"
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