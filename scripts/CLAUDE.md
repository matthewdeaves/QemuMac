# CLAUDE.md - scripts Directory

This directory contains the core utility modules and shared functionality for the QemuMac emulation system. These scripts provide the foundation for configuration management, system validation, user interfaces, and file system operations.

## Directory Structure

```
scripts/
├── qemu-utils.sh              # Core utilities and validation functions
├── qemu-common.sh             # Shared emulation functions (68k + PowerPC)  
├── qemu-menu.sh               # Interactive menu system and library management
└── mac_disc_mounter.sh        # Mac disk image mounting utilities
```

## Core Modules

### qemu-utils.sh - Foundation Utilities
**Purpose**: Provides the fundamental building blocks used across all other scripts
**Entry Points**: Sourced by other scripts (not executed directly)
**Key Functions**:

#### Error Handling & Validation
- `check_exit_status()` - Standard error checking with cleanup support
- `error_exit()` - Enhanced error handler for strict mode
- `check_command()` - Command existence validation with package suggestions
- `validate_file_exists()` - File existence and readability validation

#### Configuration Management
- `load_qemu_config()` - Load and validate QEMU configuration files
- `validate_config_schema()` - Schema validation against required variables
- `validate_config_filename()` - Configuration filename format validation

#### System Utilities
- `ensure_directory()` - Directory creation with error handling
- `sanitize_string()` - Input sanitization for system commands
- `generate_mac_address()` - Random MAC address generation (QEMU prefix)
- `generate_tap_name()` - TAP interface name generation

#### Package Management
- `install_qemu_dependencies()` - Multi-platform dependency installer
- `check_package_installed()` - Package installation status check
- `install_packages()` - Package installation with error checking

#### Logging & Debug
- `debug_log()` - Timestamped debug output
- `info_log()` - Information message formatting  
- `warning_log()` - Warning message formatting

#### Version Management
- `version_compare()` - Version string comparison
- `check_qemu_version()` - QEMU version compatibility validation

**Integration**: Sourced by all other scripts as the foundation layer

### qemu-common.sh - Shared Emulation Functions
**Purpose**: Common functionality shared between 68k and PowerPC emulation
**Entry Points**: Sourced by runmac.sh and other emulation scripts
**Key Functions**:

#### Storage Management
- `build_drive_cache_params()` - Cache parameter construction for SCSI/IDE
- `build_tcg_acceleration()` - TCG acceleration options (shared architectures)
- `build_memory_backend()` - Memory backend configuration

#### Dependency Checking
- `check_common_dependencies()` - Architecture-specific dependency validation
- `validate_common_files()` - CD-ROM and additional file validation

#### Audio Management  
- `setup_common_audio()` - Audio backend validation and configuration

**Integration**: Bridges the gap between architecture-specific implementations

### qemu-menu.sh - Interactive Menu System
**Purpose**: Provides colorized interactive menus for software library management
**Entry Points**: Sourced by mac-library.sh for interactive mode
**Key Functions**:

#### User Interface
- `print_header()` - ASCII art header with colors
- `show_main_menu()` - Primary interactive menu
- `show_software_menu()` - Software browsing interface
- `show_download_menu()` - Download management interface

#### Library Management
- `init_library()` - Library system initialization
- `get_cd_list()` - Available software enumeration
- `get_cd_info()` - Software metadata retrieval
- `download_file()` - Software download with progress
- `is_downloaded()` - Download status checking

#### Configuration Management
- `get_config_list()` - Available configuration enumeration
- `suggest_config()` - Configuration suggestion based on software

#### Integration Functions
- `launch_with_config()` - Software launch with configuration selection
- `browse_by_category()` - Software browsing by category

**Integration**: Provides the user-facing interface for the library system

### mac_disc_mounter.sh - Disk Image Management
**Purpose**: Handles mounting and management of Mac-formatted disk images on Linux hosts
**Entry Points**: Can be executed directly as a standalone utility
**Key Functions**:

#### Mount Operations
- `mount_disk_image()` - Mount HFS/HFS+ disk images
- `unmount_disk_image()` - Safely unmount disk images
- `check_mount_status()` - Mount status verification

#### Filesystem Operations
- `check_filesystem_type()` - Disk image filesystem detection
- `repair_filesystem()` - HFS/HFS+ filesystem repair
- `install_filesystem_tools()` - Auto-install hfsprogs/hfsplus tools

#### Configuration Integration
- `load_config_for_disk()` - Extract disk paths from QEMU configurations
- `check_disk_image()` - Disk image accessibility validation

**Usage Pattern**:
```bash
# Mount shared disk from configuration
./mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf

# Unmount disk
./mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf -u

# Check filesystem type
./mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf -c
```

## Architecture Overview

### Dependency Chain
```
runmac.sh
├── sources qemu-utils.sh (foundation)
├── sources qemu-common.sh (shared functions)
└── executes with validated configurations

mac-library.sh  
├── sources qemu-menu.sh (UI layer)
└── qemu-menu.sh sources qemu-utils.sh (foundation)

install-dependencies.sh
└── sources qemu-utils.sh (foundation)

mac_disc_mounter.sh
└── sources qemu-utils.sh (foundation)
```

### Error Handling Strategy
All scripts implement consistent error handling:
- **Strict Mode**: `set -euo pipefail` for immediate error detection
- **Error Trapping**: Automatic line number reporting on failures
- **Validation**: Input validation before system operations
- **Cleanup**: Optional cleanup functions on error exits
- **Logging**: Structured error reporting with context

### Configuration Validation
Comprehensive validation system:
- **Schema Validation**: Required vs optional variables per architecture
- **File Validation**: Existence and readability checks
- **Format Validation**: Configuration filename format checking
- **Architecture Detection**: Automatic architecture detection from ARCH variable
- **Dependency Validation**: Tool and package availability checking

### Performance Optimization Framework
Scripts provide extensive performance tuning options:
- **Cache Modes**: writethrough, writeback, directsync, none
- **AIO Modes**: native (Linux), threads (cross-platform)
- **TCG Options**: single vs multi-threaded translation
- **Memory Backends**: RAM, file-backed, memfd
- **Network Devices**: Architecture-appropriate network controllers

## Development Patterns

### Adding New Utilities
1. Source `qemu-utils.sh` for foundation functions
2. Implement consistent error handling (`set -euo pipefail`)
3. Use existing validation functions (`validate_file_exists`, `check_command`)
4. Follow established logging patterns (`debug_log`, `info_log`, `warning_log`)
5. Document function signatures in script header comments

### Configuration Management
- All configs must define `ARCH` variable for auto-detection
- Use `load_qemu_config()` for consistent config loading
- Implement architecture-specific validation as needed
- Follow established variable naming conventions

### Error Handling Standards
- Always check exit codes with `check_exit_status()`
- Provide meaningful error messages with context
- Implement cleanup functions for partial operations
- Use appropriate exit codes (0=success, 1=error, 2=usage)

### User Interface Guidelines
- Use established color constants for consistency
- Implement clear help messages with examples
- Provide progress indicators for long operations
- Handle user input validation gracefully

## Integration Points

### With Main Scripts
- `runmac.sh` uses `qemu-utils.sh` and `qemu-common.sh` for core operations
- `mac-library.sh` uses `qemu-menu.sh` for interactive interface
- `install-dependencies.sh` uses `qemu-utils.sh` for package management

### With Configuration System
- All scripts can load and validate QEMU configuration files
- Architecture detection works consistently across all utilities
- Configuration schema validation prevents invalid setups

### With File System
- Disk image management through `mac_disc_mounter.sh`
- Automatic directory and file creation as needed
- HFS/HFS+ filesystem support for Mac compatibility

### With Package Managers
- Multi-platform package installation (apt, Homebrew, dnf)
- Automatic dependency detection and installation
- Graceful handling of missing dependencies

## Common Usage Patterns

### Development Workflow
```bash
# Validate system dependencies
./install-dependencies.sh --check

# Test configuration loading
./runmac.sh -C path/to/config.conf -?

# Mount shared disk for file transfer  
./scripts/mac_disc_mounter.sh -C path/to/config.conf

# Interactive software management
./mac-library.sh
```

### Debugging and Troubleshooting
- All scripts support debug mode via `DEBUG_MODE=true`
- Use `-D` flag where available for verbose output
- Check log files and error messages for context
- Validate configurations before execution

### Performance Tuning
- Modify configuration files for performance vs safety trade-offs
- Use provided cache and AIO mode options
- Monitor resource usage during emulation
- Adjust RAM and CPU allocations based on guest OS requirements

This scripts directory forms the foundation of the QemuMac system, providing robust, reusable components that ensure consistent behavior across all emulation scenarios.