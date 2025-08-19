#!/bin/bash
#
# QemuMac Dependency Installer - Installs QEMU and required dependencies
# Supports both macOS and Ubuntu/Debian Linux
#

set -Euo pipefail

# --- Color Codes for User-Friendly Output ---
C_RED=$(tput setaf 1)
C_GREEN=$(tput setaf 2)
C_YELLOW=$(tput setaf 3)
C_BLUE=$(tput setaf 4)
C_RESET=$(tput sgr0)

# --- Helper functions for printing colored text ---
info() { >&2 echo "${C_YELLOW}Info: ${1}${C_RESET}"; }
success() { >&2 echo "${C_GREEN}Success: ${1}${C_RESET}"; }
error() { >&2 echo "${C_RED}Error: ${1}${C_RESET}"; }
header() { >&2 echo -e "\n${C_BLUE}=== ${1} ===${C_RESET}"; }

# --- Configuration ---
QEMU_GIT_URL="https://gitlab.com/qemu-project/qemu.git"
QEMU_SOURCE_DIR="qemu-source"
LOCAL_INSTALL_DIR="qemu_install"

# --- Detect OS ---
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]] || [[ "$ID" == "debian" ]]; then
            echo "ubuntu"
        else
            echo "unsupported"
        fi
    else
        echo "unsupported"
    fi
}

# --- Install system dependencies ---
install_system_dependencies() {
    local os_type="$1"
    
    header "Installing System Dependencies"
    
    if [[ "$os_type" == "macos" ]]; then
        info "Checking for Homebrew..."
        if ! command -v brew &>/dev/null; then
            error "Homebrew is not installed. Please install it first:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        
        info "Installing required dependencies via Homebrew..."
        brew install libffi gettext glib pkg-config pixman ninja meson
        
        info "Installing optional but recommended dependencies..."
        brew install sdl2 gtk+3 libusb vde nettle gnutls || true
        
    elif [[ "$os_type" == "ubuntu" ]]; then
        info "Updating package lists..."
        sudo apt-get update
        
        info "Installing required dependencies..."
        sudo apt-get install -y \
            git \
            build-essential \
            python3 \
            ninja-build \
            libglib2.0-dev \
            libfdt-dev \
            libpixman-1-dev \
            zlib1g-dev
        
        info "Installing recommended dependencies..."
        sudo apt-get install -y \
            libsdl2-dev \
            libgtk-3-dev \
            libvte-2.91-dev \
            libslirp-dev \
            libvde-dev \
            libvdeplug-dev \
            libusb-1.0-0-dev \
            libusbredir-dev \
            libssh-dev \
            libncurses5-dev \
            libgnutls28-dev \
            libnettle8-dev \
            libjpeg8-dev \
            libpng-dev \
            curl \
            unzip \
            jq || true
    fi
    
    success "System dependencies installed"
}

# --- Clone QEMU source from Git ---
clone_qemu_source() {
    header "Downloading QEMU Source"
    
    if [[ -d "$QEMU_SOURCE_DIR" ]]; then
        info "Removing existing QEMU source directory..."
        rm -rf "$QEMU_SOURCE_DIR"
    fi
    
    info "Cloning latest QEMU source from GitLab..."
    git clone "$QEMU_GIT_URL" "$QEMU_SOURCE_DIR" || {
        error "Failed to clone QEMU repository"
        exit 1
    }
    
    cd "$QEMU_SOURCE_DIR"
    local qemu_version
    qemu_version=$(git describe --always --tags --dirty)
    info "QEMU version: $qemu_version"
    
    # Only update the minimal required submodules for m68k/ppc builds
    info "Updating minimal required submodules..."
    
    # These are the only submodules typically needed for basic QEMU builds
    # without x86 firmware/BIOS requirements
    local minimal_submodules=(
        "ui/keycodemapdb"
        "tests/fp/berkeley-testfloat-3"
        "tests/fp/berkeley-softfloat-3"
        "dtc"
        "meson"
    )
    
    for submodule in "${minimal_submodules[@]}"; do
        if [[ -d "$submodule" ]]; then
            info "  Updating $submodule..."
            git submodule update --init "$submodule" 2>/dev/null || true
        fi
    done
    
    cd ..
    
    success "QEMU source downloaded"
}

# --- Build and install QEMU ---
build_and_install_qemu() {
    local install_type="$1"
    local os_type="$2"
    
    header "Building QEMU"
    
    cd "$QEMU_SOURCE_DIR"
    
    # Prepare installation prefix
    local install_prefix
    if [[ "$install_type" == "local" ]]; then
        install_prefix="$(pwd)/../${LOCAL_INSTALL_DIR}"
        mkdir -p "$install_prefix"
        install_prefix="$(cd "$install_prefix" && pwd)"  # Get absolute path
    else
        install_prefix="/usr/local"
    fi
    
    info "Installation prefix: $install_prefix"
    
    # Configure QEMU with m68k and ppc targets
    info "Configuring QEMU build..."
    
    # Basic configure arguments
    local configure_args=(
        "--prefix=$install_prefix"
        "--target-list=m68k-softmmu,ppc-softmmu"
        "--enable-slirp"
        "--enable-sdl"
        "--enable-vnc"
        "--disable-docs"  # Skip documentation to speed up build
        "--disable-guest-agent"  # Not needed for Mac emulation
    )
    
    # Add optional features if dependencies are available
    if pkg-config --exists gtk+-3.0 2>/dev/null; then
        configure_args+=("--enable-gtk")
    fi
    
    if pkg-config --exists libusb-1.0 2>/dev/null; then
        configure_args+=("--enable-libusb")
    fi
    
    if pkg-config --exists vdeplug 2>/dev/null; then
        configure_args+=("--enable-vde")
    fi
    
    ./configure "${configure_args[@]}" || {
        error "QEMU configuration failed"
        error "Check the error messages above for missing dependencies"
        exit 1
    }
    
    # Determine number of parallel jobs
    local num_jobs
    if [[ "$os_type" == "macos" ]]; then
        num_jobs=$(sysctl -n hw.ncpu)
    else
        num_jobs=$(nproc)
    fi
    
    info "Building QEMU with $num_jobs parallel jobs..."
    make -j"$num_jobs" || {
        error "QEMU build failed"
        exit 1
    }
    
    info "Installing QEMU..."
    if [[ "$install_type" == "local" ]]; then
        make install || {
            error "QEMU installation failed"
            exit 1
        }
    else
        sudo make install || {
            error "QEMU installation failed"
            exit 1
        }
    fi
    
    cd ..
    success "QEMU built and installed successfully"
}

# --- Verify installation ---
verify_installation() {
    local install_type="$1"
    
    header "Verifying Installation"
    
    local qemu_m68k_path qemu_ppc_path
    
    if [[ "$install_type" == "local" ]]; then
        qemu_m68k_path="${LOCAL_INSTALL_DIR}/bin/qemu-system-m68k"
        qemu_ppc_path="${LOCAL_INSTALL_DIR}/bin/qemu-system-ppc"
    else
        qemu_m68k_path="qemu-system-m68k"
        qemu_ppc_path="qemu-system-ppc"
    fi
    
    # Check m68k
    if command -v "$qemu_m68k_path" &>/dev/null; then
        local m68k_version
        m68k_version=$("$qemu_m68k_path" --version | head -n1)
        success "✓ $m68k_version"
    else
        error "✗ qemu-system-m68k not found"
    fi
    
    # Check ppc
    if command -v "$qemu_ppc_path" &>/dev/null; then
        local ppc_version
        ppc_version=$("$qemu_ppc_path" --version | head -n1)
        success "✓ $ppc_version"
    else
        error "✗ qemu-system-ppc not found"
    fi
}

# --- Main installation flow ---
main() {
    header "QemuMac Dependency Installer"
    
    # Detect OS
    local os_type
    os_type=$(detect_os)
    
    if [[ "$os_type" == "unsupported" ]]; then
        error "Unsupported operating system"
        error "This script supports macOS and Ubuntu/Debian Linux only"
        exit 1
    fi
    
    info "Detected OS: $os_type"
    
    # Ask if user wants to install from source
    local install_from_source
    echo
    echo "${C_YELLOW}Do you want to install QEMU from source?${C_RESET}"
    echo "  1) Yes - Build latest QEMU from Git (recommended for latest features)"
    echo "  2) No - Exit (use package manager manually if needed)"
    read -rp "Choice [1-2]: " choice
    
    case "$choice" in
        1|"")
            install_from_source="yes"
            ;;
        2)
            info "You can install QEMU using:"
            if [[ "$os_type" == "macos" ]]; then
                echo "  brew install qemu"
            else
                echo "  sudo apt-get install qemu-system-m68k qemu-system-ppc"
            fi
            exit 0
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Ask for installation type (local or global)
    local install_type
    echo
    echo "${C_YELLOW}Where do you want to install QEMU?${C_RESET}"
    echo "  1) Local - Install in project folder (./qemu_install/)"
    echo "  2) Global - Install system-wide in /usr/local"
    read -rp "Choice [1-2]: " choice
    
    case "$choice" in
        1|"")
            install_type="local"
            info "Will install QEMU locally in ${LOCAL_INSTALL_DIR}/"
            ;;
        2)
            install_type="global"
            info "Will install QEMU globally in /usr/local"
            ;;
        *)
            error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Install system dependencies
    install_system_dependencies "$os_type"
    
    # Clone and build QEMU
    clone_qemu_source
    build_and_install_qemu "$install_type" "$os_type"
    
    # Verify installation
    verify_installation "$install_type"
    
    # Final instructions
    echo
    header "Installation Complete!"
    
    if [[ "$install_type" == "local" ]]; then
        success "QEMU has been installed locally in ${LOCAL_INSTALL_DIR}/"
        info "Your run-mac.sh script will automatically use this local installation"
    else
        success "QEMU has been installed globally in /usr/local"
        info "You can now use qemu-system-m68k and qemu-system-ppc from anywhere"
    fi
    
    echo
    info "Next steps:"
    echo "  1. Download ROMs and ISOs: ./iso-downloader.sh"
    echo "  2. Create a VM: ./run-mac.sh --create-config my-vm-name"
    echo "  3. Run the VM: ./run-mac.sh --config vms/my-vm-name/my-vm-name.conf"
}

# Run main function
main "$@"