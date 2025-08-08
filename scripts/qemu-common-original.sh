#!/usr/bin/env bash

#######################################
# QEMU Common Functions Module
# Shared functionality between 68k and PowerPC emulation
#######################################

# Source shared utilities
# shellcheck source=qemu-utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

#######################################
# Build drive cache parameters for both SCSI and IDE
# Arguments:
#   cache_mode: Cache mode (writethrough, writeback, none, directsync)
#   aio_mode: AIO mode (threads, native)
# Returns:
#   Echoes cache parameter string
#######################################
build_drive_cache_params() {
    local cache_mode="$1"
    local aio_mode="$2"
    local cache_params="cache=$cache_mode,aio=$aio_mode"
    
    # Native AIO requires cache.direct=on
    if [ "$aio_mode" = "native" ]; then
        cache_params="$cache_params,cache.direct=on"
    fi
    
    echo "$cache_params"
}

#######################################
# Common dependency checking for both architectures
# Arguments:
#   arch: Architecture (m68k or ppc)
# Returns:
#   0 if all dependencies present, 1 if missing
#######################################
check_common_dependencies() {
    local arch="$1"
    local missing_deps=()
    
    # Architecture-specific QEMU binary
    if [ "$arch" = "m68k" ]; then
        if ! command -v qemu-system-m68k &> /dev/null; then
            missing_deps+=("qemu-system-m68k")
        fi
    elif [ "$arch" = "ppc" ]; then
        if ! command -v qemu-system-ppc &> /dev/null; then
            missing_deps+=("qemu-system-ppc")
        fi
    fi
    
    # Common utilities
    if ! command -v qemu-img &> /dev/null; then
        missing_deps+=("qemu-img")
    fi
    if ! command -v dd &> /dev/null; then
        missing_deps+=("coreutils")
    fi
    
    # 68k-specific dependencies
    if [ "$arch" = "m68k" ]; then
        if ! command -v hexdump &> /dev/null; then
            missing_deps+=("bsdmainutils")
        fi
        if ! command -v printf &> /dev/null; then
            missing_deps+=("coreutils")
        fi
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Missing core dependencies: ${missing_deps[*]}"
        echo ""
        echo "You can install all dependencies by running:"
        echo "  ./install-dependencies.sh"
        echo ""
        echo "Or install them manually. Run './install-dependencies.sh --check' to see what's needed."
        echo ""
        echo "Continue anyway? [y/N]"
        read -r response
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled. Please install dependencies first."
            exit 1
        fi
        
        return 1
    fi
    
    return 0
}

#######################################
# Common argument parsing for file validation
# Arguments:
#   cd_file: CD-ROM file path (can be empty)
#   additional_hdd_file: Additional HDD file path (can be empty)
# Returns:
#   None
# Exits:
#   1 if validation fails
#######################################
validate_common_files() {
    local cd_file="$1"
    local additional_hdd_file="$2"
    
    # Validate CD file if specified
    if [ -n "$cd_file" ]; then
        validate_file_exists "$cd_file" "CD-ROM image file" || exit 1
    fi
    
    # Validate additional HDD file if specified
    if [ -n "$additional_hdd_file" ]; then
        validate_file_exists "$additional_hdd_file" "Additional hard drive image file" || exit 1
    fi
}

#######################################
# Build TCG acceleration options (shared between architectures)
# Arguments:
#   tcg_thread_mode: Threading mode (single, multi)
#   tb_size: Translation block cache size
# Returns:
#   Echoes TCG acceleration options
#######################################
build_tcg_acceleration() {
    local tcg_thread_mode="$1"
    local tb_size="$2"
    local accel_opts="tcg"
    
    if [ -n "$tcg_thread_mode" ] && [ "$tcg_thread_mode" != "single" ]; then
        accel_opts="${accel_opts},thread=${tcg_thread_mode}"
    fi
    
    if [ -n "$tb_size" ]; then
        accel_opts="${accel_opts},tb-size=${tb_size}"
    fi
    
    echo "$accel_opts"
}

#######################################
# Common audio backend validation and setup
# Arguments:
#   audio_backend: Audio backend (pa, alsa, coreaudio, none)
#   audio_latency: Audio latency in microseconds
# Returns:
#   0 if valid, 1 if invalid
#######################################
setup_common_audio() {
    local audio_backend="$1"
    local audio_latency="$2"
    local audio_id="$3"
    
    # Validate audio backend
    case "$audio_backend" in
        pa|alsa|coreaudio|none) ;;
        *) 
            echo "Error: Invalid audio backend '$audio_backend'. Supported: pa, alsa, coreaudio, none" >&2
            return 1
            ;;
    esac
    
    # Build audio arguments if not disabled
    if [ "$audio_backend" != "none" ]; then
        local audio_opts="$audio_backend,id=$audio_id"
        if [ -n "$audio_latency" ]; then
            audio_opts="$audio_opts,in.latency=$audio_latency,out.latency=$audio_latency"
        fi
        echo "-audiodev $audio_opts"
    fi
}

#######################################
# Common memory backend setup
# Arguments:
#   memory_backend: Memory backend type (ram, file, memfd)
#   ram_size: RAM size in MB
# Returns:
#   Echoes memory backend options or empty string
#######################################
build_memory_backend() {
    local memory_backend="$1"
    local ram_size="$2"
    
    if [ -n "$memory_backend" ]; then
        echo "-object memory-backend-$memory_backend,size=${ram_size}M,id=ram0 -machine memory-backend=ram0"
    fi
}