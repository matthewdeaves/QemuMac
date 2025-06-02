# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This project provides a modular set of shell scripts to simplify the setup and management of classic Macintosh (m68k architecture) emulation using QEMU. It enables running multiple Mac OS configurations with different networking modes and file sharing capabilities. The codebase has been refactored for maintainability, security, and modularity.

## Key Scripts and Their Purpose

### Core Scripts (Project Root)
- **`run68k.sh`**: Main orchestration script for QEMU Mac emulation
- **`install-dependencies.sh`**: Cross-platform dependency installer
- **`sys755-safe.conf`**: Legacy root config for Mac OS 7.5.5 (comprehensive standard)
- **`sys761-safe.conf`**: Legacy root config for Mac OS 7.6.1 (comprehensive standard)

### Modular Components (`scripts/` directory)
- **`scripts/qemu-utils.sh`**: Shared utility functions and error handling (core dependency)
- **`scripts/mac_disc_mounter.sh`**: File sharing via HFS/HFS+ disk mounting on Linux
- **`scripts/qemu-config.sh`**: Configuration loading, validation, and schema checking
- **`scripts/qemu-storage.sh`**: Disk image creation, PRAM management, boot order
- **`scripts/qemu-networking.sh`**: Network setup (TAP, User, Passt modes)
- **`scripts/qemu-display.sh`**: Display type detection and validation
- **`scripts/qemu-tap-functions.sh`**: TAP networking bridge/interface management
- **`scripts/debug-pram.sh`**: PRAM analysis and debugging utility

### Configuration Files (`configs/` directory)
**Performance-Optimized Variants**: Multiple configurations for different use cases

**Mac OS 7.5.5 Configurations:**
- `sys755-standard.conf`: Balanced default (writethrough cache, built-in display)
- `sys755-fast.conf`: Speed-focused (writeback cache, built-in display) 
- `sys755-ultimate.conf`: Maximum performance (writeback + native AIO, QUANTUM drives)
- `sys755-safest.conf`: Maximum safety (no cache, built-in display)
- `sys755-native.conf`: Linux-optimized (writethrough + native AIO)
- `sys755-directsync.conf`: Direct I/O testing (directsync cache)
- `sys755-authentic.conf`: Historical accuracy (NuBus framebuffer emulation)

**Mac OS 7.6.1 Configurations:**
- `sys761-standard.conf`: Balanced default (writethrough cache, built-in display)
- `sys761-fast.conf`: Speed-focused (writeback cache, built-in display)
- `sys761-ultimate.conf`: Maximum performance (writeback + native AIO, QUANTUM drives)
- `sys761-safest.conf`: Maximum safety (no cache, built-in display)
- `sys761-native.conf`: Linux-optimized (writethrough + native AIO)
- `sys761-directsync.conf`: Direct I/O testing (directsync cache)
- `sys761-authentic.conf`: Historical accuracy (NuBus framebuffer emulation)

### Data Files and Directories
- **ROM Files**: `800.ROM` (user-provided, legally obtained)
- **Version Directories**: `710/`, `755/`, `761/` containing:
  - `hdd_sys{version}.img`: Main OS disk images
  - `shared_{version}.img`: Shared disk for file transfer
  - `pram_{version}_q800.img`: PRAM storage files

## Common Commands

### Running Mac OS Emulation
```bash
# Quick start with balanced defaults
./run68k.sh -C configs/sys755-standard.conf    # Mac OS 7.5.5 balanced default
./run68k.sh -C configs/sys761-standard.conf    # Mac OS 7.6.1 balanced default

# Performance-focused configurations
./run68k.sh -C configs/sys755-fast.conf        # Speed-focused 7.5.5
./run68k.sh -C configs/sys761-ultimate.conf    # Maximum performance 7.6.1

# Safety-focused configurations
./run68k.sh -C configs/sys755-safest.conf      # Maximum data safety 7.5.5
./run68k.sh -C configs/sys761-safest.conf      # Maximum data safety 7.6.1

# Historical accuracy
./run68k.sh -C configs/sys755-authentic.conf   # NuBus graphics 7.5.5
./run68k.sh -C configs/sys761-authentic.conf   # NuBus graphics 7.6.1

# Network mode override (auto-detects by platform)
./run68k.sh -C configs/sys755-standard.conf -N user    # Internet access
./run68k.sh -C configs/sys755-standard.conf -N tap     # VM-to-VM (Linux)
./run68k.sh -C configs/sys755-standard.conf -N passt   # Modern networking

# OS installation workflow
./run68k.sh -C configs/sys761-standard.conf -c /path/to/Mac_OS.iso -b  # Install
./run68k.sh -C configs/sys761-standard.conf                            # Run

# Advanced options
./run68k.sh -C configs/sys755-standard.conf -a /path/to/software.img -D
```

### Platform-Specific Notes
```bash
# macOS (Apple Silicon/Intel) - requires modern bash and uses User Mode by default
brew install qemu bash  # Install dependencies first
./run68k.sh -C configs/sys755-standard.conf  # Auto-uses User Mode networking

# Linux - uses TAP networking by default
# Use automatic installer (recommended)
./install-dependencies.sh
./run68k.sh -C configs/sys755-standard.conf  # Auto-uses TAP networking

# Or install manually
sudo apt install qemu-system-m68k bridge-utils iproute2 passt hfsprogs
./run68k.sh -C configs/sys755-standard.conf
```

### File Sharing via Shared Disk
```bash
# Mount shared disk image to Linux host (requires sudo)
sudo ./scripts/mac_disc_mounter.sh -C configs/sys755-standard.conf

# Unmount shared disk
sudo ./scripts/mac_disc_mounter.sh -C configs/sys755-standard.conf -u

# Check filesystem type
sudo ./scripts/mac_disc_mounter.sh -C configs/sys755-standard.conf -c

# Repair filesystem
sudo ./scripts/mac_disc_mounter.sh -C configs/sys755-standard.conf -r

# Advanced mounting options
sudo ./scripts/mac_disc_mounter.sh -C configs/sys761-standard.conf -m /custom/mount/point
```

## Architecture

### Modular Design
The codebase follows a modular architecture with clear separation of concerns:

- **Shared Utilities (`scripts/qemu-utils.sh`)**: Common functions for error handling, validation, configuration management, security, and logging
- **Configuration Management (`scripts/qemu-config.sh`)**: Schema-based config validation and loading
- **Storage Management (`scripts/qemu-storage.sh`)**: PRAM, HDD, and disk image preparation
- **Network Management (`scripts/qemu-networking.sh`)**: TAP, user, and passt networking modes
- **Display Management (`scripts/qemu-display.sh`)**: Auto-detection and validation of display types

### Configuration System
Each `.conf` file defines a complete Mac OS emulation setup with comprehensive schema validation:

**Required Variables (always present):**
- `QEMU_MACHINE`: Machine type (q800 for Quadra 800)
- `QEMU_ROM`: ROM file path (e.g., "800.ROM")
- `QEMU_HDD`: Main OS disk image path
- `QEMU_SHARED_HDD`: Shared disk image path for file transfer
- `QEMU_RAM`: RAM allocation in MB (128 for 7.5.5, 256 for 7.6.1)
- `QEMU_GRAPHICS`: Display resolution and color depth
- `QEMU_PRAM`: PRAM file path for boot order and settings

**Performance Variables (tuning variants):**
- `QEMU_CPU_MODEL`: Explicit CPU model (m68040)
- `QEMU_TCG_THREAD_MODE`: Threading mode (single/multi)
- `QEMU_TB_SIZE`: Translation block cache size
- `QEMU_MEMORY_BACKEND`: Memory backend type (ram/file/memfd)
- `QEMU_SCSI_CACHE_MODE`: Storage caching (writethrough/writeback/none/directsync)
- `QEMU_SCSI_AIO_MODE`: I/O mode (threads/native)
- `QEMU_SCSI_VENDOR`: SCSI device vendor string
- `QEMU_SCSI_SERIAL_PREFIX`: Serial number prefix for SCSI devices

**Display and Audio Variables:**
- `QEMU_DISPLAY_DEVICE`: Display type (built-in/nubus-macfb)
- `QEMU_RESOLUTION_PRESET`: Resolution preset selection
- `QEMU_AUDIO_BACKEND`: Audio backend (pa/alsa/sdl/none)
- `QEMU_AUDIO_LATENCY`: Audio latency in microseconds
- `QEMU_ASC_MODE`: Apple Sound Chip mode (easc/asc)
- `QEMU_FLOPPY_*`: Floppy disk configuration options

**Networking Variables:**
- `BRIDGE_NAME`: Network bridge name (default: br0)
- `QEMU_TAP_IFACE`: TAP interface name (auto-generated)
- `QEMU_MAC_ADDR`: MAC address (auto-generated)
- `QEMU_USER_SMB_DIR`: SMB share directory for user mode

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
The project follows a clean, organized directory structure:

**Root Directory:**
- `run68k.sh`: Main script
- `install-dependencies.sh`: Dependency installer
- `sys755-safe.conf`, `sys761-safe.conf`: Legacy comprehensive configs
- `800.ROM`: User-provided ROM file

**`scripts/` Directory (all utilities):**
- Core utilities and modular components
- All scripts source `qemu-utils.sh` for shared functionality
- TAP networking requires Linux-specific tools

**`configs/` Directory (performance variants):**
- Performance-optimized configurations for different use cases
- All configs have identical base features, differ only in performance tuning
- Built-in display (fast) vs NuBus display (authentic) variants

**Version Directories** (auto-created by configs):
- `710/`, `755/`, `761/`: Contains system-specific disk images:
  - `hdd_sys{version}.img`: Main OS disk image
  - `shared_{version}.img`: Shared disk for file transfer  
  - `pram_{version}_q800.img`: PRAM storage with boot order settings

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

### Script Dependencies and Architecture
**Dependency Hierarchy:**
- `run68k.sh` → Main orchestrator, sources all required modules
- `scripts/qemu-utils.sh` → Core dependency for all other scripts
- `scripts/qemu-config.sh` → Configuration validation and loading
- `scripts/qemu-storage.sh` → Disk and PRAM management
- `scripts/qemu-networking.sh` → Network mode setup
- `scripts/qemu-display.sh` → Display detection
- `scripts/qemu-tap-functions.sh` → TAP implementation (Linux only)
- `scripts/mac_disc_mounter.sh` → File sharing utility

**Key Requirements:**
- QEMU 4.0+ minimum, 7.0+ for Passt networking, 8.0+ recommended
- Linux: Full feature support (TAP, Passt, file mounting)
- macOS: User mode networking only (TAP requires Linux tools)
- Bash 4.0+ required (macOS needs `brew install bash`)

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
**Adding New Performance Configurations:**
1. Copy existing config: `cp configs/sys755-standard.conf configs/sys755-custom.conf`
2. Modify only SCSI performance variables (cache mode, AIO mode, vendor)
3. Update CONFIG_NAME and comments to describe the variant
4. Test thoroughly with both installation and runtime scenarios

**Adding New Networking Modes:**
1. Implement in `scripts/qemu-networking.sh` with validation
2. Add to help text in `run68k.sh`
3. Update argument parsing and validation
4. Follow existing pattern for cleanup and error handling

**Adding New Machine Types:**
1. Create new config with appropriate QEMU_MACHINE setting
2. Ensure ROM file compatibility
3. Test boot sequence and hardware detection
4. Document any special requirements or limitations

**Development Best Practices:**
- Always use `scripts/qemu-utils.sh` functions for consistency
- Follow strict bash mode (`set -euo pipefail`)
- Implement proper error handling with `check_exit_status()`
- Add comprehensive validation for new parameters
- Maintain backward compatibility with existing configs
- Use debug mode (`-D` flag) for testing and troubleshooting