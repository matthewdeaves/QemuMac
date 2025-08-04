# scripts CLAUDE.md

This directory contains shared utility scripts and modules used by both 68k and PowerPC emulation systems. These scripts provide common functionality to reduce code duplication and improve maintainability across the project.

## Architecture Overview

The scripts follow a modular design where each script handles a specific aspect of emulation (networking, storage, display, etc.). All scripts source `qemu-utils.sh` for common functions and error handling.

## Major Entry Points and Modules

### Core Utilities
- **`qemu-utils.sh`**: Foundation utility library
  - Error handling and validation functions
  - Common constants and defaults
  - File system operations
  - Cross-platform compatibility helpers
  - Logging functions (info_log, warning_log, debug_log)

### Configuration Management
- **`qemu-config.sh`**: Configuration loading and validation
  - Schema validation for both 68k and PowerPC configs
  - Network-specific configuration validation  
  - Default value assignment
  - Configuration file parsing and sourcing
  - Architecture-specific validation (validate_ppc_config_schema, etc.)

### Storage Management
- **`qemu-storage.sh`**: Disk image and storage operations
  - SCSI device management (68k-specific)
  - IDE device management (PowerPC-specific)
  - Disk image creation and validation
  - PRAM manipulation for 68k boot order
  - Storage performance optimization

### Networking Support
- **`qemu-networking.sh`**: Network configuration management
  - TAP networking setup and cleanup
  - User mode networking configuration
  - Passt networking support
  - MAC address generation
  - Network argument building for QEMU

### Display Management  
- **`qemu-display.sh`**: Display and graphics configuration
  - Display type detection (SDL, GTK, Cocoa)
  - Platform-specific display selection
  - Graphics resolution validation
  - Display device configuration

### TAP Networking Infrastructure
- **`qemu-tap-functions.sh`**: Advanced TAP networking functions
  - Bridge creation and management
  - TAP device creation and cleanup
  - NAT and DHCP configuration
  - iptables rule management
  - Network isolation and security

### File Sharing
- **`mac_disc_mounter.sh`**: HFS/HFS+ disk mounting utility
  - Cross-platform disk mounting
  - HFS+ filesystem support
  - Automatic mount point creation
  - Safe unmounting with data verification

### Interactive Tools
- **`qemu-menu.sh`**: Interactive menu system for mac-library
  - Software database management
  - Download progress tracking
  - Configuration selection menus
  - Colorized terminal output

### Debugging Tools
- **`debug-pram.sh`**: PRAM analysis and debugging
  - PRAM file inspection
  - Boot order analysis
  - SCSI device mapping display
  - PRAM corruption detection

## Module Dependencies

```
qemu-utils.sh (base)
├── qemu-config.sh
├── qemu-storage.sh  
├── qemu-networking.sh
│   └── qemu-tap-functions.sh
├── qemu-display.sh
├── qemu-menu.sh
├── mac_disc_mounter.sh
└── debug-pram.sh
```

## Key Features by Module

### qemu-utils.sh Features
- **Error Handling**: Standardized error checking with `check_exit_status()`
- **File Validation**: `validate_file_exists()` with descriptive error messages
- **Command Checking**: `check_command()` with package installation suggestions
- **Logging System**: Structured logging with levels (info, warning, debug, error)
- **Cross-Platform**: macOS and Linux compatibility detection
- **Default Constants**: Centralized default values for all components

### qemu-config.sh Features
- **Schema Validation**: Enforces required variables per architecture
- **Network Validation**: TAP-specific configuration checking
- **Default Assignment**: Automatic default value setting for optional parameters
- **Architecture Detection**: Separate validation paths for 68k vs PowerPC
- **Error Reporting**: Detailed missing variable reporting with descriptions

### qemu-networking.sh Features
- **TAP Mode**: Full bridge networking with DHCP and NAT
  - Bridge creation with IP assignment
  - TAP device management
  - iptables NAT rule configuration
  - dnsmasq DHCP server setup
  - Automatic cleanup on exit
- **User Mode**: Simple NAT networking with SMB support
- **Passt Mode**: Modern userspace networking alternative
- **MAC Generation**: Automatic MAC address generation with proper prefixes

### qemu-storage.sh Features  
- **SCSI Management** (68k): Complex SCSI ID assignment and boot order control
- **IDE Management** (PowerPC): Simple IDE channel configuration
- **PRAM Control**: Boot device selection via PRAM manipulation
- **Cache Optimization**: Writethrough/writeback/native AIO configuration
- **Image Creation**: Automatic disk image creation with proper sizing

### qemu-display.sh Features
- **Auto-Detection**: Platform-specific display backend selection
- **Validation**: Display type validation with fallback options
- **Resolution Support**: Graphics resolution parsing and validation
- **Device Support**: NuBus and built-in display device configuration

## Architecture-Specific Behavior

### 68k-Specific Functions
- PRAM manipulation for boot order (qemu-storage.sh)
- SCSI ID management with static assignments
- ASC audio mode configuration
- ROM file validation
- Complex SCSI cache parameter building

### PowerPC-Specific Functions  
- Simple IDE channel configuration
- Boot flag management (-boot c/d)
- ES1370 sound device configuration
- USB device support
- Built-in BIOS handling

### Shared Functions
- Network setup (all modes)
- Display configuration
- Performance optimization
- File validation
- Error handling and logging

## Usage Patterns

### Module Sourcing
```bash
# All scripts source qemu-utils.sh first
source "$(dirname "${BASH_SOURCE[0]}")/qemu-utils.sh"

# Then source specific modules as needed
source "$SCRIPT_DIR/scripts/qemu-config.sh"
source "$SCRIPT_DIR/scripts/qemu-networking.sh"
```

### Error Handling Pattern
```bash
# Standard error checking
some_command
check_exit_status $? "Failed to execute some_command"

# File validation
validate_file_exists "$config_file" "Configuration file" || exit 1

# Command checking
check_command "qemu-system-m68k" "qemu-system-m68k package" || exit 1
```

### Logging Pattern
```bash
info_log "Starting network setup"
warning_log "Using default MAC address"
debug_log "QEMU command: ${qemu_args[*]}"
error_log "Fatal error occurred"
```

## Configuration Integration

### Schema Validation
Each architecture has specific required variables:
```bash
# 68k requirements
QEMU_ROM, QEMU_PRAM, QEMU_MACHINE="q800"

# PowerPC requirements  
QEMU_MACHINE="mac99,via=pmu", no ROM/PRAM needed
```

### Performance Parameters
Shared performance configuration across architectures:
```bash
QEMU_TCG_THREAD_MODE="multi"    # TCG threading
QEMU_TB_SIZE="64"               # Translation block cache
QEMU_*_CACHE_MODE="writethrough" # Storage cache mode
QEMU_*_AIO_MODE="threads"       # AIO threading
```

## Networking Architecture

### TAP Mode (Linux)
- Bridge creation with static IP (192.168.99.1/24)
- DHCP server via dnsmasq (192.168.99.100-200)
- NAT via iptables for internet access
- Automatic cleanup on script exit

### User Mode (Universal)
- Built-in QEMU NAT (10.0.2.x network)
- Optional SMB file sharing
- No host configuration required
- Works on all platforms

### Passt Mode (Modern)
- Userspace networking via passt binary
- Better performance than user mode
- Requires passt package installation

## File System Integration

### HFS+ Mounting (Linux)
```bash
# Mount shared disk for file transfer
sudo mount -t hfsplus -o loop shared.img /mnt/mac_shared

# Requires hfsprogs package
sudo apt install hfsprogs  # Debian/Ubuntu
```

### SMB Sharing (User Mode)
```bash
# Configure in config file
QEMU_USER_SMB_DIR="/path/to/shared/folder"

# Accessible in VM at 10.0.2.4
```

## Development Guidelines

### Adding New Modules
1. Source qemu-utils.sh for common functions
2. Follow existing error handling patterns
3. Use standardized logging functions
4. Support both 68k and PowerPC where applicable
5. Include proper function documentation

### Modifying Existing Modules
1. Maintain backward compatibility
2. Update both architecture-specific scripts if changes affect both
3. Test with multiple configuration variants
4. Update documentation in CLAUDE.md files

This modular architecture ensures clean separation of concerns while providing robust shared functionality for both emulation architectures.