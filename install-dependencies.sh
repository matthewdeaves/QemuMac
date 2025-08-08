#!/usr/bin/env bash

#######################################
# Simplified QEMU Mac Dependency Installer
# Supports Ubuntu/Debian and macOS only
# Based on official QEMU wiki instructions
#######################################

set -eo pipefail

show_help() {
    echo "Simplified QEMU Mac Dependency Installer"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  -c, --check    Check dependencies only"
    echo ""
    echo "Supported platforms:"
    echo "  - Ubuntu/Debian (using apt)"
    echo "  - macOS (using Homebrew)"
    echo ""
    echo "This script:"
    echo "  1. Installs build dependencies"
    echo "  2. Optionally builds QEMU from source"
    echo "  3. Installs HFS+ tools for Mac disk support"
}

#######################################
# Detect platform
#######################################
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/debian_version ]] || command -v apt-get &> /dev/null; then
        echo "ubuntu"
    else
        echo "unsupported"
    fi
}

#######################################
# Check if QEMU is already installed
#######################################
check_qemu() {
    local missing=()
    
    if ! command -v qemu-system-m68k &> /dev/null; then
        missing+=("qemu-system-m68k")
    fi
    
    if ! command -v qemu-system-ppc &> /dev/null; then
        missing+=("qemu-system-ppc")
    fi
    
    if ! command -v qemu-img &> /dev/null; then
        missing+=("qemu-img")
    fi
    
    if [ ${#missing[@]} -eq 0 ]; then
        echo "✓ QEMU is already installed"
        qemu-system-m68k --version | head -1
        qemu-system-ppc --version | head -1
        return 0
    else
        echo "Missing QEMU components: ${missing[*]}"
        return 1
    fi
}

#######################################
# Install Ubuntu dependencies and QEMU
#######################################
install_ubuntu() {
    echo "Installing Ubuntu dependencies..."
    
    # Install basic dependencies from QEMU wiki
    local deps=(
        "git"
        "libglib2.0-dev"
        "libfdt-dev" 
        "libpixman-1-dev"
        "zlib1g-dev"
        "ninja-build"
        "build-essential"
        "pkg-config"
        "libsdl2-dev"
        "libgtk-3-dev"
        "jq"
    )
    
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y "${deps[@]}"
    
    # Install HFS+ tools if available
    echo "Installing HFS+ filesystem support..."
    sudo apt-get install -y hfsprogs hfsplus || echo "Warning: Some HFS+ tools not available"
    
    echo "✓ Ubuntu dependencies installed"
}

#######################################
# Install macOS dependencies and QEMU  
#######################################
install_macos() {
    echo "Installing macOS dependencies..."
    
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found. Please install Homebrew first:" >&2
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
        exit 1
    fi
    
    # Install basic dependencies from QEMU wiki
    local deps=(
        "libffi"
        "gettext"
        "glib"
        "pkg-config"
        "pixman"
        "ninja"
        "meson"
        "git"
        "jq"
    )
    
    echo "Installing build dependencies via Homebrew..."
    for dep in "${deps[@]}"; do
        if ! brew list "$dep" &> /dev/null; then
            echo "Installing $dep..."
            brew install "$dep"
        else
            echo "✓ $dep already installed"
        fi
    done
    
    echo "✓ macOS dependencies installed"
}

#######################################
# Build QEMU from source
#######################################
build_qemu_from_source() {
    echo ""
    echo "=== Build QEMU from source ==="
    echo "This builds the latest QEMU with m68k and PowerPC support"
    echo ""
    
    read -p "Do you want to build QEMU from source? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping QEMU source build"
        return 0
    fi
    
    echo "Cloning QEMU source..."
    if [ -d "qemu" ]; then
        rm -rf qemu
    fi
    
    git clone https://gitlab.com/qemu-project/qemu.git
    cd qemu
    
    echo "Configuring QEMU build..."
    ./configure --target-list=m68k-softmmu,ppc-softmmu --enable-slirp
    
    echo "Building QEMU (this may take 15-30+ minutes)..."
    local cpu_count
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu_count=$(sysctl -n hw.ncpu)
    else
        cpu_count=$(nproc)
    fi
    
    echo "Using $cpu_count CPU cores for compilation..."
    make -j"$cpu_count"
    
    echo "Installing QEMU..."
    sudo make install
    
    cd ..
    rm -rf qemu
    
    echo "✓ QEMU built and installed successfully"
    echo "QEMU installed to: /usr/local/bin/"
    echo ""
    
    echo "Verifying installation..."
    qemu-system-m68k --version | head -1
    qemu-system-ppc --version | head -1
}

#######################################
# Main function
#######################################
main() {
    local check_only=false
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -c|--check) check_only=true ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
        shift
    done
    
    echo "Simplified QEMU Mac Dependency Installer"
    echo ""
    
    # Detect platform
    local platform
    platform=$(detect_platform)
    echo "Detected platform: $platform"
    
    if [ "$platform" = "unsupported" ]; then
        echo "Error: Unsupported platform" >&2
        echo "This script only supports Ubuntu/Debian and macOS" >&2
        exit 1
    fi
    
    # Check existing QEMU installation
    if check_qemu; then
        if [ "$check_only" = true ]; then
            echo "✓ All dependencies satisfied"
            exit 0
        fi
        
        echo ""
        read -p "QEMU is already installed. Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    fi
    
    if [ "$check_only" = true ]; then
        echo "❌ Some dependencies are missing"
        echo "Run without -c/--check to install them"
        exit 1
    fi
    
    # Install platform-specific dependencies
    case $platform in
        ubuntu)
            install_ubuntu
            build_qemu_from_source
            ;;
        macos)
            install_macos
            build_qemu_from_source
            ;;
    esac
    
    echo ""
    echo "=== Installation Complete ==="
    echo "✓ Dependencies installed"
    echo "✓ QEMU built from source"
    echo ""
    echo "You can now run Mac emulation:"
    echo "  ./runmac.sh -C m68k/configs/m68k-macos753.conf"
    echo "  ./runmac.sh -C ppc/configs/ppc-macos91.conf"
}

main "$@"