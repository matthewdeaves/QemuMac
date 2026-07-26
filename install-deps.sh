#!/usr/bin/env bash
#
# QemuMac Dependency Installer - Installs QEMU and required dependencies
# Supports macOS (Homebrew) and Ubuntu/Debian Linux (apt)
#

set -Eeuo pipefail

# Load common library
source "$(dirname "$0")/lib/common.sh"

# --- Configuration ---
QEMU_GIT_URL="https://gitlab.com/qemu-project/qemu.git"
QEMU_SOURCE_DIR="qemu-source"
LOCAL_INSTALL_DIR="qemu-install"

# Minimum QEMU that supports everything QemuMac uses. Older builds still run
# VMs; check_qemu_features reports exactly what is missing.
QEMU_MIN_VERSION="8.2"

# Assembled by build_and_install_qemu and add_if_available
CONFIGURE_ARGS=()

# ============================================================================
# Runtime dependencies (needed by the QemuMac scripts themselves)
# ============================================================================

install_runtime_dependencies() {
    local os_type="$1"

    header "Installing Runtime Dependencies"

    if [[ "$os_type" == "macos" ]]; then
        info "Installing via Homebrew: jq, hfsutils"
        brew install jq hfsutils || error "Some runtime dependencies failed to install"
    else
        info "Installing via apt: jq, curl, unzip, hfsprogs"
        sudo apt-get update
        # hfsprogs lives in universe and may be unavailable on some derivatives
        sudo apt-get install -y jq curl unzip || error "Some runtime dependencies failed to install"
        sudo apt-get install -y hfsprogs || \
            error "hfsprogs unavailable - ./mount-shared.sh will not work until it is installed"
    fi

    success "Runtime dependencies installed"
}

# ============================================================================
# QEMU via package manager (fast path)
# ============================================================================

install_qemu_from_packages() {
    local os_type="$1"

    header "Installing QEMU from Package Manager"

    if [[ "$os_type" == "macos" ]]; then
        info "Installing QEMU via Homebrew..."
        brew install qemu || die "Failed to install QEMU via Homebrew"
    else
        info "Installing QEMU via apt..."
        # qemu-system-misc provides qemu-system-m68k on Debian/Ubuntu.
        # qemu-utils provides qemu-img (there is no 'qemu-img' package).
        sudo apt-get update
        sudo apt-get install -y \
            qemu-system-misc \
            qemu-system-ppc \
            qemu-utils || die "Failed to install QEMU via apt"
    fi

    success "QEMU installed"
}

# ============================================================================
# Build dependencies (source build only)
# ============================================================================

install_build_dependencies() {
    local os_type="$1"

    header "Installing Build Dependencies"

    if [[ "$os_type" == "macos" ]]; then
        if ! command_exists "brew"; then
            error "Homebrew is not installed. Install it first:"
            echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            die "Homebrew required"
        fi

        info "Installing core build toolchain..."
        brew install libffi gettext glib pkg-config pixman ninja meson \
            || die "Failed to install core build dependencies"

        info "Installing optional feature dependencies..."
        # Each is probed by pkg-config at configure time, so failures are not fatal
        brew install sdl2 sdl2_image libusb vde nettle gnutls libssh libslirp jpeg libpng || true
    else
        info "Installing core build toolchain..."
        sudo apt-get update
        sudo apt-get install -y \
            git \
            build-essential \
            python3 \
            python3-venv \
            python3-dev \
            ninja-build \
            meson \
            pkg-config \
            libglib2.0-dev \
            libfdt-dev \
            libpixman-1-dev \
            zlib1g-dev || die "Failed to install core build dependencies"

        info "Installing optional feature dependencies..."
        sudo apt-get install -y \
            libsdl2-dev \
            libsdl2-image-dev \
            libgtk-3-dev \
            libncurses-dev \
            libusb-1.0-0-dev \
            libusbredirhost-dev \
            libusbredirparser-dev \
            libpulse-dev \
            libasound2-dev \
            libpipewire-0.3-dev \
            libslirp-dev \
            libvdeplug-dev \
            libgnutls28-dev \
            nettle-dev \
            libssh-dev \
            libjpeg-dev \
            libpng-dev || true
    fi

    success "Build dependencies installed"
}

# ============================================================================
# Source build
# ============================================================================

# Resolve the newest stable release tag without cloning. Matches vX.Y.Z only,
# so release candidates (vX.Y.0-rc1) and bugfix releases are handled correctly
# - the previous 'vX.Y.0' pattern silently skipped every bugfix release.
resolve_latest_stable_tag() {
    git ls-remote --tags --refs "$QEMU_GIT_URL" 2>/dev/null \
        | sed 's#.*refs/tags/##' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | sort -V \
        | tail -n1
}

clone_qemu_source() {
    header "Downloading QEMU Source"

    local stable_tag
    stable_tag=$(resolve_latest_stable_tag || true)

    if [[ -z "$stable_tag" ]]; then
        die "Could not determine the latest stable QEMU release from ${QEMU_GIT_URL}"
    fi
    info "Latest stable release: ${stable_tag}"

    if dir_exists "$QEMU_SOURCE_DIR"; then
        info "Removing existing QEMU source directory..."
        rm -rf "$QEMU_SOURCE_DIR"
    fi

    # Shallow clone of the tag only - a full QEMU history is over 1GB
    info "Cloning QEMU ${stable_tag}..."
    git clone --depth 1 --branch "$stable_tag" "$QEMU_GIT_URL" "$QEMU_SOURCE_DIR" \
        || die "Failed to clone QEMU repository"

    success "QEMU ${stable_tag} downloaded"
}

# Append a configure flag to CONFIGURE_ARGS only when one of the named
# pkg-config packages is present, so a missing optional library degrades the
# build instead of failing it. Uses a global rather than a nameref to stay
# compatible with bash 3.2 (the version macOS ships).
add_if_available() {
    local flag="$1"; shift
    local pkg
    for pkg in "$@"; do
        if pkg-config --exists "$pkg" 2>/dev/null; then
            CONFIGURE_ARGS+=("$flag")
            return 0
        fi
    done
    return 0
}

build_and_install_qemu() {
    local install_type="$1"
    local os_type="$2"

    header "Building QEMU"

    local install_prefix
    if [[ "$install_type" == "local" ]]; then
        ensure_directory "$LOCAL_INSTALL_DIR" "Creating local installation directory"
        install_prefix="$(cd "$LOCAL_INSTALL_DIR" && pwd)"
    else
        install_prefix="/usr/local"
    fi
    info "Installation prefix: $install_prefix"

    cd "$QEMU_SOURCE_DIR" || die "Could not enter ${QEMU_SOURCE_DIR}"

    CONFIGURE_ARGS=(
        "--prefix=$install_prefix"
        "--target-list=m68k-softmmu,ppc-softmmu"
        "--disable-docs"
        "--disable-guest-agent"
    )

    # Display backends. Cocoa needs no external library; SDL is the Linux
    # default and the fallback everywhere else.
    if [[ "$os_type" == "macos" ]]; then
        CONFIGURE_ARGS+=("--enable-cocoa")
    fi
    add_if_available "--enable-sdl" sdl2
    add_if_available "--enable-sdl-image" SDL2_image
    add_if_available "--enable-gtk" gtk+-3.0
    add_if_available "--enable-curses" ncursesw ncurses

    # Audio. Required for Quadra 800 sound via the emulated Apple Sound Chip.
    if [[ "$os_type" == "macos" ]]; then
        CONFIGURE_ARGS+=("--audio-drv-list=coreaudio")
    else
        local audio_drivers="alsa"
        pkg-config --exists libpulse 2>/dev/null && audio_drivers+=",pa"
        pkg-config --exists libpipewire-0.3 2>/dev/null && audio_drivers+=",pipewire"
        CONFIGURE_ARGS+=("--audio-drv-list=${audio_drivers}")
    fi

    # Networking, crypto, image formats
    CONFIGURE_ARGS+=("--enable-slirp")
    add_if_available "--enable-gnutls" gnutls
    add_if_available "--enable-nettle" nettle
    add_if_available "--enable-png" libpng libpng16
    add_if_available "--enable-libusb" libusb-1.0
    add_if_available "--enable-usb-redir" libusbredirparser-0.5
    add_if_available "--enable-vde" vdeplug
    add_if_available "--enable-libssh" libssh

    info "Configuring QEMU build..."
    ./configure "${CONFIGURE_ARGS[@]}" || {
        error "QEMU configuration failed - check the messages above for missing dependencies"
        die "QEMU configuration failed"
    }

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

# ============================================================================
# Verification
# ============================================================================

# Compare dotted versions: returns 0 if $1 >= $2
version_at_least() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# Run a QEMU probe and echo its combined output. Probes are expected to exit
# non-zero (they deliberately fail after argument parsing), so the status is
# discarded - callers must inspect the text, not the exit code.
qemu_probe() {
    "$@" 2>&1 || true
}

check_qemu_features() {
    local qemu_m68k="$1"

    header "Feature Check"

    local version
    version=$("$qemu_m68k" --version | head -n1 | sed -E 's/.*version ([0-9.]+).*/\1/')
    info "QEMU version: ${version}"

    if version_at_least "$version" "$QEMU_MIN_VERSION"; then
        success "✓ Version supports all QemuMac features"
    else
        error "✗ QEMU ${version} is older than ${QEMU_MIN_VERSION}"
        error "  VMs will still run, but some display and audio options may be unavailable"
    fi

    # 24-bit colour on the Quadra framebuffer
    if qemu_probe "$qemu_m68k" -M q800 -g 800x600x24 -display none \
            | grep -q "unknown display mode"; then
        error "✗ 24-bit colour at 800x600 unavailable (DISPLAY_RES limited to 8-bit)"
    else
        success "✓ 24-bit colour available at 640x480 and 800x600"
    fi

    # Quadra 800 Apple Sound Chip
    if qemu_probe "$qemu_m68k" -M q800,help | grep -q "audiodev"; then
        success "✓ Quadra 800 audio (Apple Sound Chip) supported"
    else
        error "✗ Quadra 800 audio unsupported by this build"
    fi

    # Resizable, scaling window. Cocoa-only, so only meaningful on macOS.
    # An unloadable -bios makes QEMU exit right after it parses -display.
    if [[ "$(detect_os)" == "macos" ]]; then
        if qemu_probe "$qemu_m68k" -M q800 -display cocoa,zoom-to-fit=on -bios /nonexistent \
                | grep -q "is unexpected"; then
            error "✗ DISPLAY_ZOOM unsupported - set DISPLAY_ZOOM=false in your VM configs"
        else
            success "✓ Resizable scaling window (DISPLAY_ZOOM) supported"
        fi
    fi
}

verify_installation() {
    local install_type="$1"

    header "Verifying Installation"

    local prefix=""
    [[ "$install_type" == "local" ]] && prefix="${LOCAL_INSTALL_DIR}/bin/"

    local ok=true arch
    for arch in m68k ppc; do
        local bin="${prefix}qemu-system-${arch}"
        if command_exists "$bin"; then
            success "✓ $("$bin" --version | head -n1)"
        else
            error "✗ qemu-system-${arch} not found"
            ok=false
        fi
    done

    local tool
    for tool in qemu-img jq curl; do
        if command_exists "$tool"; then
            success "✓ ${tool}"
        else
            error "✗ ${tool} not found"
            ok=false
        fi
    done

    if compute_md5 /dev/null >/dev/null 2>&1; then
        success "✓ md5 checksum tool"
    else
        error "✗ no md5sum or md5 - download checksums cannot be verified"
    fi

    [[ "$ok" == true ]] || return 1
    check_qemu_features "${prefix}qemu-system-m68k"
}

# ============================================================================
# Main
# ============================================================================

usage() {
    echo "Usage: $0 [-h]"
    echo ""
    echo "Installs QEMU and the tools QemuMac needs, on macOS or Ubuntu/Debian."
    echo "Runs interactively; you choose between a package-manager install and"
    echo "a source build of the latest stable QEMU release."
}

main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    header "QemuMac Dependency Installer"

    local os_type
    os_type=$(detect_os)
    if [[ "$os_type" == "unsupported" ]]; then
        error "This script supports macOS and Ubuntu/Debian Linux only"
        die "Unsupported OS"
    fi
    info "Detected OS: $os_type"

    local method
    method=$(menu "How should QEMU be installed?" \
        "Package manager - fast, uses the version your OS ships" \
        "Build from source - latest stable release, all features enabled")
    [[ "$method" == "QUIT" ]] && exit 0

    install_runtime_dependencies "$os_type"

    local install_type="global"
    if [[ "$method" == "Package manager"* ]]; then
        install_qemu_from_packages "$os_type"
    else
        local location
        location=$(menu "Where should QEMU be installed?" \
            "Local - in ./${LOCAL_INSTALL_DIR}/ (run-mac.sh finds it automatically)" \
            "Global - system-wide in /usr/local")
        [[ "$location" == "QUIT" ]] && exit 0
        [[ "$location" == "Local"* ]] && install_type="local"

        install_build_dependencies "$os_type"
        clone_qemu_source
        build_and_install_qemu "$install_type" "$os_type"
    fi

    verify_installation "$install_type" || die "Installation is incomplete - see the errors above"

    header "Installation Complete"
    if [[ "$install_type" == "local" ]]; then
        info "run-mac.sh will automatically prefer ./${LOCAL_INSTALL_DIR}/"
    fi
    echo
    info "Next steps:"
    echo "  1. Launch a VM:    ./run-mac.sh"
    echo "  2. Download media: ./iso-downloader.sh"
    echo "  3. Create a VM:    ./run-mac.sh --create-config my-vm"
}

main "$@"
