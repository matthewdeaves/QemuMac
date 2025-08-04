#!/usr/bin/env bash

#######################################
# QEMU Mac Emulation Dependency Installer
# Installs all required dependencies for QEMU m68k Mac emulation
# Supports multiple package managers: apt, brew, dnf
#######################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/qemu-utils.sh
source "$SCRIPT_DIR/scripts/qemu-utils.sh"

#######################################
# Display help information
# Arguments:
#   None
# Returns:
#   None
# Exits:
#   1 (help display always exits)
#######################################
show_help() {
    echo "QEMU Mac Emulation Dependency Installer"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --check    Check dependencies without installing"
    echo "  -f, --force    Force installation even if dependencies exist"
    echo ""
    echo "This script installs all dependencies required for QEMU m68k Mac emulation:"
    echo ""
    echo "Core Dependencies:"
    echo "  - qemu-system-m68k  (QEMU m68k emulation)"
    echo "  - qemu-utils        (QEMU utilities)"
    echo "  - coreutils         (Core system utilities)"
    echo "  - bsdmainutils      (BSD utilities like hexdump)"
    echo "  - jq                (JSON processor for mac-library tool)"
    echo ""
    echo "Networking Dependencies:"
    echo "  - iproute2          (IP networking tools)"
    echo ""
    echo "Filesystem Dependencies:"
    echo "  - hfsprogs          (HFS+ filesystem support)"
    echo "  - hfsplus           (Additional HFS+ tools)"
    echo ""
    echo "Supported Systems:"
    echo "  - Debian/Ubuntu     (apt package manager)"
    echo "  - macOS             (Homebrew)"
    echo "  - Fedora/RHEL       (dnf package manager)"
    echo ""
    exit 1
}

#######################################
# Check all dependencies and report status
# Arguments:
#   None
# Returns:
#   0 if all dependencies present, 1 if any missing
#######################################
check_dependencies() {
    echo "Checking QEMU Mac emulation dependencies..."
    echo ""
    
    local missing_count=0
    local deps_to_check=(
        "qemu-system-m68k:QEMU m68k emulation"
        "qemu-img:QEMU utilities"
        "dd:Core utilities"
        "printf:Core utilities"
        "hexdump:BSD utilities"
        "jq:JSON processor (mac-library tool)"
    )
    
    # Add Linux-specific networking dependencies
    if [[ "$(uname)" != "Darwin" ]]; then
        # No specific user-mode networking dependencies to check here
        :
    fi
    
    echo "Core Dependencies:"
    for dep_info in "${deps_to_check[@]}"; do
        IFS=':' read -r cmd desc <<< "$dep_info"
        if command -v "$cmd" &> /dev/null; then
            echo "  ✅ $cmd ($desc)"
        else
            echo "  ❌ $cmd ($desc) - MISSING"
            ((missing_count++))
        fi
    done
    
    echo ""
    echo "Filesystem Dependencies:"
    local fs_tools=("fsck.hfs:HFS filesystem check" "fsck.hfsplus:HFS+ filesystem check")
    for dep_info in "${fs_tools[@]}"; do
        IFS=':' read -r cmd desc <<< "$dep_info"
        if command -v "$cmd" &> /dev/null; then
            echo "  ✅ $cmd ($desc)"
        else
            echo "  ⚠️  $cmd ($desc) - missing (optional for shared disk repair)"
        fi
    done
    
    echo ""
    
    # Platform-specific notes
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "📝 macOS Notes:"
        echo "  - User-mode networking is used by default."
        echo ""
    fi
    
    if [ $missing_count -eq 0 ]; then
        echo "✅ All core dependencies are installed!"
        echo "You can run QEMU Mac emulation with user-mode networking."
        return 0
    else
        echo "❌ $missing_count core dependencies are missing."
        echo "Run '$0' without arguments to install them."
        return 1
    fi
}

#######################################
# Main function
# Arguments:
#   All command line arguments
# Returns:
#   None
#######################################
main() {
    local check_only=false
    local force_install=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                echo "Use '$0 --help' for usage information." >&2
                exit 1
                ;;
        esac
    done
    
    # Just check dependencies if requested
    if [ "$check_only" = true ]; then
        check_dependencies
        exit $?
    fi
    
    # Check if installation is needed
    if [ "$force_install" = false ]; then
        if check_dependencies; then
            echo ""
            echo "All dependencies are already installed. Use --force to reinstall."
            exit 0
        fi
        echo ""
    fi
    
    # Install dependencies
    echo "Starting dependency installation..."
    echo ""
    install_qemu_dependencies
    
    echo ""
    echo "Installation completed! Verifying dependencies..."
    echo ""
    
    # Verify installation
    if check_dependencies; then
        echo ""
        echo "🎉 Installation successful!"
        echo ""
        echo "You can now run QEMU Mac emulation:"
        echo "  ./runmac.sh -C m68k/configs/m68k-macos753.conf      # Mac OS 7.5.3 with user-mode networking"
        echo "  ./runmac.sh -C ppc/configs/ppc-macos91.conf        # Mac OS 9.1 with user-mode networking"
        echo "  ./runmac.sh -C m68k/configs/m68k-macos753.conf    # 68k with user-mode networking"
    else
        echo ""
        echo "⚠️  Some dependencies may not have installed correctly."
        echo "Please check the output above and install missing packages manually."
        exit 1
    fi
}

# Entry point
main "$@"
