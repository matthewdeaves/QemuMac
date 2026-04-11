#!/usr/bin/env bash
#
# QemuMac Dependency Installer - Installs QEMU and required dependencies
# Supports both macOS and Ubuntu/Debian Linux
#

set -Euo pipefail

# Load common library
source "$(dirname "$0")/lib/common.sh"

# --- Configuration ---
QEMU_GIT_URL="https://gitlab.com/qemu-project/qemu.git"
QEMU_SOURCE_DIR="qemu-source"
LOCAL_INSTALL_DIR="qemu-install"

# --- Install system dependencies ---
install_system_dependencies() {
    local os_type="$1"
    
    header "Installing System Dependencies"
    
    if [[ "$os_type" == "macos" ]]; then
        info "Checking for Homebrew..."
        if ! command_exists "brew"; then
            error "Homebrew is not installed. Please install it first:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            die "Homebrew required"
        fi

        info "Installing required build dependencies via Homebrew..."
        brew install libffi gettext glib pkg-config pixman ninja meson jq curl unzip

        info "Installing display and input dependencies..."
        brew install sdl2 sdl2_image gtk+3 libusb vde || true

        info "Installing crypto and network dependencies..."
        brew install nettle gnutls libssh libslirp || true

        info "Installing image compression dependencies..."
        brew install jpeg libpng || true

        info "Installing HFS filesystem support..."
        brew install hfsutils || true

    elif [[ "$os_type" == "linux" ]]; then
        info "Updating package lists..."
        sudo apt-get update

        info "Installing required build dependencies..."
        sudo apt-get install -y \
            git \
            build-essential \
            python3 \
            python3-venv \
            python3-dev \
            ninja-build \
            meson \
            libglib2.0-dev \
            libfdt-dev \
            libpixman-1-dev \
            zlib1g-dev

        info "Installing display and input dependencies..."
        sudo apt-get install -y \
            libsdl2-dev \
            libsdl2-image-dev \
            libgtk-3-dev \
            libvte-2.91-dev \
            libncurses-dev \
            libusb-1.0-0-dev \
            libusbredirhost-dev \
            libusbredirparser-dev || true

        info "Installing audio dependencies..."
        sudo apt-get install -y \
            libpulse-dev \
            libasound2-dev \
            libpipewire-0.3-dev || true

        info "Installing network dependencies..."
        sudo apt-get install -y \
            libslirp-dev \
            libvde-dev \
            libvdeplug-dev || true

        info "Installing crypto and security dependencies..."
        sudo apt-get install -y \
            libgnutls28-dev \
            nettle-dev \
            libssh-dev || true

        info "Installing image compression dependencies..."
        sudo apt-get install -y \
            libjpeg-dev \
            libpng-dev || true

        info "Installing runtime tools..."
        sudo apt-get install -y \
            curl \
            unzip \
            jq || true

        info "Installing HFS filesystem support..."
        sudo apt-get install -y hfsprogs || true
    fi
    
    success "System dependencies installed"
}

# --- Find latest stable QEMU release tag ---
find_latest_stable_tag() {
    git tag -l 'v[0-9]*.[0-9]*.0' --sort=-v:refname | head -n1
}

# --- Clone QEMU source from Git ---
clone_qemu_source() {
    header "Downloading QEMU Source"

    if dir_exists "$QEMU_SOURCE_DIR"; then
        info "Removing existing QEMU source directory..."
        rm -rf "$QEMU_SOURCE_DIR"
    fi

    info "Cloning QEMU source from GitLab..."
    git clone "$QEMU_GIT_URL" "$QEMU_SOURCE_DIR" || die "Failed to clone QEMU repository"

    cd "$QEMU_SOURCE_DIR"

    # Check out the latest stable release instead of HEAD (which may be an RC)
    local stable_tag
    stable_tag=$(find_latest_stable_tag)
    if [[ -n "$stable_tag" ]]; then
        info "Checking out latest stable release: $stable_tag"
        git checkout "$stable_tag" || info "Failed to checkout $stable_tag, using HEAD"
    else
        info "Could not determine latest stable tag, using HEAD"
    fi

    local qemu_version
    qemu_version=$(git describe --always --tags --dirty)
    info "QEMU version: $qemu_version"

    # Modern QEMU uses Meson wraps (subprojects/*.wrap) for build dependencies
    # which are fetched automatically during configure. We only need to init
    # submodules required for our target architectures (PPC needs OpenBIOS).
    info "Initialising required submodules..."
    git submodule update --init roms/openbios 2>/dev/null || true
    git submodule update --init roms/QemuMacDrivers 2>/dev/null || true
    git submodule update --init roms/SLOF 2>/dev/null || true

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
        ensure_directory "$install_prefix" "Creating local installation directory"
        install_prefix="$(cd "$install_prefix" && pwd)"  # Get absolute path
    else
        install_prefix="/usr/local"
    fi
    
    info "Installation prefix: $install_prefix"
    
    # Configure QEMU with m68k and ppc targets and full feature support
    info "Configuring QEMU build..."

    # Core configure arguments
    local configure_args=(
        "--prefix=$install_prefix"
        "--target-list=m68k-softmmu,ppc-softmmu"
        "--disable-docs"
        "--disable-guest-agent"
    )

    # Display backends
    configure_args+=("--enable-sdl")
    configure_args+=("--enable-sdl-image")
    configure_args+=("--enable-vnc")
    configure_args+=("--enable-vnc-jpeg")

    if [[ "$os_type" == "macos" ]]; then
        configure_args+=("--enable-cocoa")
    fi

    # Audio backends (platform-specific)
    if [[ "$os_type" == "macos" ]]; then
        configure_args+=("--audio-drv-list=coreaudio,sdl")
    else
        # Build list of available Linux audio backends
        local audio_drivers="sdl"
        if pkg-config --exists libpulse 2>/dev/null; then
            audio_drivers+=",pa"
        fi
        if pkg-config --exists libpipewire-0.3 2>/dev/null; then
            audio_drivers+=",pipewire"
        fi
        configure_args+=("--audio-drv-list=${audio_drivers}")
    fi

    # Networking
    configure_args+=("--enable-slirp")

    # Crypto and TLS
    if pkg-config --exists gnutls 2>/dev/null; then
        configure_args+=("--enable-gnutls")
    fi
    if pkg-config --exists nettle 2>/dev/null; then
        configure_args+=("--enable-nettle")
    fi

    # Image compression (for VNC and PNG screenshots)
    if pkg-config --exists libpng 2>/dev/null || pkg-config --exists libpng16 2>/dev/null; then
        configure_args+=("--enable-png")
    fi

    # Optional features - enable if dependencies are available
    if pkg-config --exists gtk+-3.0 2>/dev/null; then
        configure_args+=("--enable-gtk")
    fi
    if pkg-config --exists libusb-1.0 2>/dev/null; then
        configure_args+=("--enable-libusb")
    fi
    if pkg-config --exists libusbredirparser-0.5 2>/dev/null; then
        configure_args+=("--enable-usb-redir")
    fi
    if pkg-config --exists vdeplug 2>/dev/null; then
        configure_args+=("--enable-vde")
    fi
    if pkg-config --exists libssh 2>/dev/null; then
        configure_args+=("--enable-libssh")
    fi
    if pkg-config --exists ncurses 2>/dev/null || pkg-config --exists ncursesw 2>/dev/null; then
        configure_args+=("--enable-curses")
    fi
    
    ./configure "${configure_args[@]}" || {
        error "QEMU configuration failed"
        error "Check the error messages above for missing dependencies"
        die "QEMU configuration failed"
    }
    
    # Determine number of parallel jobs
    local num_jobs
    if [[ "$os_type" == "macos" ]]; then
        num_jobs=$(sysctl -n hw.ncpu)
    else
        num_jobs=$(nproc)
    fi
    
    info "Building QEMU with $num_jobs parallel jobs..."
    make -j"$num_jobs" || die "QEMU build failed"
    
    info "Installing QEMU..."
    if [[ "$install_type" == "local" ]]; then
        make install || die "QEMU installation failed"
    else
        sudo make install || die "QEMU installation failed"
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
    if command_exists "$qemu_m68k_path"; then
        local m68k_version
        m68k_version=$("$qemu_m68k_path" --version | head -n1)
        success "✓ $m68k_version"
    else
        error "✗ qemu-system-m68k not found"
    fi
    
    # Check ppc
    if command_exists "$qemu_ppc_path"; then
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
        die "Unsupported OS"
    fi
    
    info "Detected OS: $os_type"
    
    # Ask if user wants to install from source
    local source_choice
    source_choice=$(ask_choice \
        "Do you want to install QEMU from source?" \
        "Yes - Build latest QEMU from Git (recommended for latest features)" \
        "No - Exit (use package manager manually if needed)")

    if [[ "$source_choice" == "2" ]]; then
        # Still install minimal runtime dependencies needed by QemuMac scripts
        header "Installing Runtime Dependencies"
        if [[ "$os_type" == "macos" ]]; then
            info "Installing runtime dependencies via Homebrew..."
            brew install jq curl unzip hfsutils || true
        else
            info "Installing runtime dependencies via apt..."
            sudo apt-get update
            sudo apt-get install -y jq curl unzip hfsprogs || true
        fi
        success "Runtime dependencies installed"

        info "You can install QEMU using:"
        if [[ "$os_type" == "macos" ]]; then
            echo "  brew install qemu"
        else
            echo "  sudo apt-get install qemu-system-misc qemu-system-ppc qemu-img"
        fi
        exit 0
    fi
    
    # Ask for installation type (local or global)
    local install_choice
    install_choice=$(ask_choice \
        "Where do you want to install QEMU?" \
        "Local - Install in project folder (./qemu-install/)" \
        "Global - Install system-wide in /usr/local")
    
    local install_type
    if [[ "$install_choice" == "1" ]]; then
        install_type="local"
        info "Will install QEMU locally in ${LOCAL_INSTALL_DIR}/"
    else
        install_type="global"
        info "Will install QEMU globally in /usr/local"
    fi
    
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
