# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This project provides a modular set of shell scripts to simplify the setup and management of classic Macintosh (m68k architecture) emulation using QEMU. It enables running multiple Mac OS configurations with different networking modes and file sharing capabilities. The codebase has been refactored for maintainability, security, and modularity.

## Key Scripts and Their Purpose

### Core Scripts
- **`run68k.sh`**: Main orchestration script for QEMU Mac emulation
- **`qemu-utils.sh`**: Shared utility functions and error handling
- **`mac_disc_mounter.sh`**: Utility to mount/unmount shared disk images on Linux host
- **`install-dependencies.sh`**: Cross-platform dependency installer

### Modular Components  
- **`qemu-config.sh`**: Configuration loading and validation
- **`qemu-storage.sh`**: Disk image and PRAM management
- **`qemu-networking.sh`**: Network setup for different modes
- **`qemu-display.sh`**: Display type detection and validation
- **`qemu-tap-functions.sh`**: TAP networking implementation

### Configuration Files
- **`*.conf`**: Configuration files defining specific Mac OS setups (e.g., `sys755-q800.conf`)

### Additional Files
- **`debug-pram.sh`**: PRAM analysis and debugging utility
- **`QEMU_OPTIMIZATION_IMPLEMENTATION.md`**: Performance optimization implementation tracking

## Common Commands

### Running Mac OS Emulation
```bash
# Run existing Mac OS installation (auto-detects networking: TAP on Linux, User on macOS)
./run68k.sh -C sys755-q800.conf

# Run with specific networking mode
./run68k.sh -C sys755-q800.conf -N user    # User Mode (internet access, macOS default)
./run68k.sh -C sys755-q800.conf -N tap     # TAP Mode (VM-to-VM, Linux default)

# Boot from CD/ISO for OS installation
./run68k.sh -C sys761-q800.conf -c /path/to/Mac_OS.iso -b

# Add additional hard drive image
./run68k.sh -C sys755-q800.conf -a /path/to/additional.img

# Enable debug mode with detailed logging
./run68k.sh -C sys755-q800.conf -D

# Use modern Passt networking (requires passt package)
./run68k.sh -C sys755-q800.conf -N passt
```

### Platform-Specific Notes
```bash
# macOS (Apple Silicon/Intel) - requires modern bash and uses User Mode by default
brew install qemu bash  # Install dependencies first
./run68k.sh -C sys755-q800.conf  # Auto-uses User Mode networking

# Linux - uses TAP networking by default
# Use automatic installer (recommended)
./install-dependencies.sh
./run68k.sh -C sys755-q800.conf  # Auto-uses TAP networking

# Or install manually
sudo apt install qemu-system-m68k bridge-utils iproute2 passt hfsprogs
./run68k.sh -C sys755-q800.conf
```

### File Sharing via Shared Disk
```bash
# Mount shared disk image to Linux host (requires sudo)
sudo ./mac_disc_mounter.sh -C sys755-q800.conf

# Unmount shared disk
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -u

# Check filesystem type
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -c

# Repair filesystem
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -r
```

## Architecture

### Modular Design
The codebase follows a modular architecture with clear separation of concerns:

- **Shared Utilities (`qemu-utils.sh`)**: Common functions for error handling, validation, configuration management, security, and logging
- **Configuration Management (`qemu-config.sh`)**: Schema-based config validation and loading
- **Storage Management (`qemu-storage.sh`)**: PRAM, HDD, and disk image preparation
- **Network Management (`qemu-networking.sh`)**: TAP, user, and passt networking modes
- **Display Management (`qemu-display.sh`)**: Auto-detection and validation of display types

### Configuration System
Each `.conf` file defines a complete Mac OS emulation setup with schema validation:

**Required Variables:**
- `QEMU_MACHINE`, `QEMU_ROM`, `QEMU_HDD`, `QEMU_SHARED_HDD`
- `QEMU_RAM`, `QEMU_GRAPHICS`, `QEMU_PRAM`

**Optional Variables:**
- `QEMU_CPU`, `QEMU_HDD_SIZE`, `QEMU_SHARED_HDD_SIZE`
- `QEMU_CPU_MODEL`, `QEMU_TCG_THREAD_MODE`, `QEMU_TB_SIZE`, `QEMU_MEMORY_BACKEND` (Performance)
- `QEMU_AUDIO_BACKEND`, `QEMU_AUDIO_LATENCY`, `QEMU_ASC_MODE` (Audio)
- `BRIDGE_NAME`, `QEMU_TAP_IFACE`, `QEMU_MAC_ADDR`, `QEMU_USER_SMB_DIR` (Networking)

### Networking Modes
- **TAP Mode (`-N tap`, Linux default)**: Bridged networking for VM-to-VM communication, requires sudo and Linux-specific tools
- **User Mode (`-N user`, macOS default)**: NAT networking for internet access, no sudo required, works on all platforms
- **Passt Mode (`-N passt`)**: Modern user-space networking (requires passt command)

**Platform Defaults:**
- **Linux**: TAP Mode (supports all networking tools)
- **macOS**: User Mode (TAP requires Linux-specific iproute2/bridge-utils)

### Dependency Management
The project includes comprehensive dependency management:

**Automatic Installation:**
```bash
./install-dependencies.sh          # Install all dependencies
./install-dependencies.sh --check  # Check what's needed
./install-dependencies.sh --force  # Force reinstall
```

**Supported Dependencies:**
- **Core**: `qemu-system-m68k`, `qemu-utils`, `coreutils`, `bsdmainutils`
- **Networking**: `bridge-utils`, `iproute2`, `passt` (modern userspace networking)
- **Filesystem**: `hfsprogs`, `hfsplus` (HFS+ support for shared disks)

**Platform Support:**
- **Linux**: apt (Debian/Ubuntu), dnf (Fedora/RHEL)
- **macOS**: Homebrew
- **Manual**: Fallback instructions for unsupported systems

**Integration**: The main script (`run68k.sh`) automatically detects missing dependencies and suggests using the installer.

### File Structure Convention
Config files create subdirectories containing:
- `hdd_sys{version}.img`: Main OS disk image
- `shared_{version}.img`: Shared disk for file transfer  
- `pram_{version}_{machine}.img`: PRAM storage

## Development Standards

### Error Handling
- All scripts use strict bash mode (`set -euo pipefail`)
- Consistent error checking with `check_exit_status()` function
- Enhanced error reporting with line numbers and context
- Proper cleanup on script termination

### Security Best Practices
- All variables properly quoted to prevent word splitting
- Input validation for config filenames and user inputs
- Secure command construction using arrays
- Sanitization of user-provided strings

### Code Quality
- Comprehensive function documentation with standardized headers
- Consistent variable naming conventions (UPPER_CASE for globals, lower_case for locals)
- Modular design with clear separation of concerns
- Debug logging throughout with `debug_log()` function

### Configuration Validation
- Schema-based validation with descriptive error messages
- Required vs optional variable checking
- File existence validation for ROM files and disk images
- Network-specific configuration validation

## Important Development Notes

### Script Dependencies
- All modules depend on `qemu-utils.sh` for shared functionality
- TAP networking requires `qemu-tap-functions.sh`
- Version compatibility checking for QEMU (minimum 4.0)
- Package installation helpers for required dependencies

### Security and Permissions
- TAP mode requires sudo for network bridge/interface management
- Shared disk mounting requires sudo on Linux host
- ROM files must be legally obtained (not included in repository)
- Input validation prevents injection attacks

### File System Considerations
- Shared disks must be formatted as HFS/HFS+ within Mac OS first
- Always shut down VM before mounting shared disk on host
- Multiple VMs should not access same disk images concurrently
- Automatic directory creation with proper error handling

### Testing and Debugging
- Enhanced debug mode with `-D` flag for detailed logging
- QEMU version compatibility warnings
- Comprehensive error messages with troubleshooting hints
- Debug logging available throughout all modules

### Extending the System
- Add new networking modes in `qemu-networking.sh`
- Extend configuration schema in `qemu-utils.sh`
- Add new display types in `qemu-display.sh`
- Use shared utilities for consistent error handling and validation