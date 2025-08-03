#!/usr/bin/env bash

#######################################
# Unified Mac Emulation Dispatcher
# Auto-detects architecture from config file and dispatches to appropriate runner
# Supports both 68k (m68k) and PowerPC (ppc) Mac emulation
#######################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "Unified Mac Emulation Dispatcher"
    echo ""
    echo "Usage: $0 -C <config_file.conf> [options]"
    echo ""
    echo "This script automatically detects the architecture from the config file"
    echo "and dispatches to the appropriate emulation script:"
    echo ""
    echo "  ARCH=\"m68k\" -> calls m68k/run68k.sh"
    echo "  ARCH=\"ppc\"  -> calls ppc/runppc.sh"
    echo ""
    echo "Required:"
    echo "  -C FILE  Specify configuration file"
    echo ""
    echo "All other options are passed through to the architecture-specific script."
    echo ""
    echo "Examples:"
    echo "  $0 -C m68k/configs/sys753-standard.conf"
    echo "  $0 -C ppc/configs/macos91-standard.conf -c install.iso -b"
    echo "  $0 -C ppc/configs/osxtiger104-standard.conf -N user"
    echo ""
    echo "Direct access (for debugging/advanced use):"
    echo "  ./m68k/run68k.sh -C m68k/configs/sys753-standard.conf"
    echo "  ./ppc/runppc.sh -C ppc/configs/macos91-standard.conf"
    echo ""
    exit 1
}

#######################################
# Extract architecture from config file
# Arguments:
#   config_file: Path to configuration file
# Returns:
#   Prints architecture (m68k or ppc) to stdout
# Exits:
#   1 if config file not found or ARCH not defined
#######################################
get_architecture_from_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file '$config_file' not found." >&2
        exit 1
    fi
    
    # Extract ARCH variable from config file
    local arch
    arch=$(grep "^ARCH=" "$config_file" 2>/dev/null | cut -d'"' -f2)
    
    if [ -z "$arch" ]; then
        echo "Error: ARCH variable not found in config file '$config_file'." >&2
        echo "Config files must define ARCH=\"m68k\" or ARCH=\"ppc\"." >&2
        exit 1
    fi
    
    echo "$arch"
}

#######################################
# Main dispatcher function
# Arguments:
#   All command line arguments
# Returns:
#   None
# Exits:
#   With the exit code of the dispatched script
#######################################
main() {
    # Parse arguments to find config file
    local config_file=""
    local temp_args=("$@")
    
    # Look for -C argument
    for (( i=0; i<${#temp_args[@]}; i++ )); do
        if [ "${temp_args[i]}" = "-C" ] && [ $((i+1)) -lt ${#temp_args[@]} ]; then
            config_file="${temp_args[$((i+1))]}"
            break
        fi
    done
    
    # Check if help was requested or no config provided
    if [ "$#" -eq 0 ] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-?" ]]; then
        show_help
    fi
    
    if [ -z "$config_file" ]; then
        echo "Error: No configuration file specified. Use -C <config_file.conf>" >&2
        echo "Use '$0 --help' for usage information." >&2
        exit 1
    fi
    
    # Get architecture from config file
    local arch
    arch=$(get_architecture_from_config "$config_file")
    
    # Dispatch to appropriate script
    case "$arch" in
        "m68k")
            echo "Detected m68k architecture, dispatching to m68k/run68k.sh"
            exec "$SCRIPT_DIR/m68k/run68k.sh" "$@"
            ;;
        "ppc")
            echo "Detected ppc architecture, dispatching to ppc/runppc.sh"
            exec "$SCRIPT_DIR/ppc/runppc.sh" "$@"
            ;;
        *)
            echo "Error: Unknown architecture '$arch' in config file '$config_file'." >&2
            echo "Supported architectures: m68k, ppc" >&2
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"