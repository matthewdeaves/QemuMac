# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QemuMac is a comprehensive dual-architecture emulation system for classic Macintosh computers using QEMU. It supports both Motorola 68k and PowerPC Mac systems with an integrated software library management system.

## Core Commands

### Primary Emulation Commands
```bash
# Run Mac emulation with configuration
./runmac.sh -C <config_file> [options]

# Install system dependencies
./install-dependencies.sh

# Launch software library manager (interactive)
./mac-library.sh

# Launch software library manager (command line)
./mac-library.sh list                    # List available software
./mac-library.sh download <software_key> # Download specific software
./mac-library.sh launch <key> <config>   # Launch software with config
```

### Common Development Workflows
```bash
# Check dependencies before development
./install-dependencies.sh --check

# Test 68k Mac OS 7.5.3 emulation
./runmac.sh -C m68k/configs/m68k-macos753.conf

# Test PowerPC Mac OS 9.1 emulation  
./runmac.sh -C ppc/configs/ppc-macos91.conf

# Boot from CD for OS installation
./runmac.sh -C <config> -c <cd_image> -b

# Launch with additional storage
./runmac.sh -C <config> -a <additional_hdd>
```

## Architecture Overview

### Dual-Architecture Design
The system auto-detects architecture from configuration files using the `ARCH` variable:
- `ARCH="m68k"` - Motorola 68000 family emulation (Mac OS 7.x)
- `ARCH="ppc"` - PowerPC emulation (Mac OS 9.x/X)

### Directory Structure
```
QemuMac/
├── runmac.sh                    # Unified emulation runner (main entry point)
├── install-dependencies.sh     # Dependency installer
├── mac-library.sh              # Software library manager
├── library/                    # Software database and downloads
│   ├── CLAUDE.md              # Library system documentation
│   ├── software-database.json # Curated software metadata
│   └── downloads/             # Downloaded software storage
├── m68k/                      # 68k-specific files
│   ├── configs/               # 68k configuration files
│   └── images/                # 68k disk images and ROMs
├── ppc/                      # PowerPC-specific files
│   ├── configs/              # PowerPC configuration files
│   └── images/               # PowerPC disk images
└── scripts/                  # Shared utility modules
    ├── qemu-utils.sh         # Core utilities and validation
    ├── qemu-common.sh        # Shared emulation functions
    ├── qemu-menu.sh          # Interactive menu system
    └── mac_disc_mounter.sh   # Disk mounting utilities
```

### Configuration System
Configuration files (.conf) contain all emulation parameters:
- **Required**: `ARCH`, `QEMU_MACHINE`, `QEMU_HDD`, `QEMU_SHARED_HDD`, `QEMU_RAM`, `QEMU_GRAPHICS`
- **68k Additional**: `QEMU_ROM`, `QEMU_PRAM` (ROM and PRAM files)
- **Performance Tuning**: Cache modes, AIO settings, TCG threading
- **Hardware Options**: Audio, network, display configurations

Example config structure:
```bash
ARCH="m68k"                                    # Architecture detection
QEMU_MACHINE="q800"                           # Hardware platform
QEMU_HDD="m68k/images/753/hdd_sys753.img"     # Main system disk
QEMU_SCSI_CACHE_MODE="writeback"              # Performance optimization
```

### Software Library System
The library system (`library/` directory) provides curated classic Mac software:
- **JSON Database**: `software-database.json` with download URLs and metadata
- **Auto-Download**: Automatic software retrieval with progress tracking  
- **Architecture Detection**: Matches software to compatible emulation configs
- **Integration**: Seamless launch with appropriate QEMU configurations

## Key Components

### runmac.sh - Unified Emulation Runner
- Auto-detects architecture from config files
- Builds appropriate QEMU command lines for 68k vs PowerPC
- Handles user-mode networking, storage, and performance optimization
- Supports CD-ROM mounting and boot order management

### Configuration Validation
All configs are validated for:
- Required variables per architecture
- File existence (ROMs, disk images)
- Performance setting compatibility
- Hardware option validation

### Storage Management
- **68k Systems**: SCSI-based storage with fixed device IDs
- **PowerPC Systems**: IDE-based storage with boot order control
- **Shared Disks**: Cross-platform file transfer via HFS+ images
- **Auto-Creation**: Missing disk images created automatically

### Network Architecture
Uses QEMU user-mode networking by default:
- No host configuration required
- Out-of-the-box internet connectivity
- Architecture-specific network device selection

## Development Guidelines

### Adding New Configurations
1. Create `.conf` file in appropriate `m68k/configs/` or `ppc/configs/` directory
2. Set `ARCH` variable first (enables auto-detection)
3. Define all required variables for the architecture
4. Test with `./runmac.sh -C path/to/config.conf`
5. Validate with dependency checker

### Modifying Core Scripts
- All scripts use `set -euo pipefail` for strict error handling
- Shared functions are in `scripts/qemu-utils.sh` and `scripts/qemu-common.sh`
- Use existing validation functions for file/command checking
- Follow established logging patterns (`debug_log`, `info_log`, `warning_log`)

### Software Library Management
- Edit `library/software-database.json` to add new software
- Required fields: `name`, `filename`, `url`, `architecture`
- Optional fields: `md5`, `description`, `category`, `nice_filename`
- Test downloads and launches before committing

### Performance Optimization
Configuration files support extensive performance tuning:
- **Cache Modes**: `writeback` (fastest) to `none` (safest)
- **AIO Modes**: `native` (Linux) vs `threads` (cross-platform)
- **TCG Threading**: `multi` (faster) vs `single` (stable)
- **Memory Backends**: Standard RAM vs file-backed debugging

## Claude Code Development Instructions

### Changelog Management
**IMPORTANT**: Maintain a `CHANGELOG.md` file in the project root to log important changes and decisions. Keep entries brief but informative:
- Log significant feature additions, architectural changes, and important bug fixes
- Include the reasoning behind major decisions
- Format: `YYYY-MM-DD - Brief description of change and why it was made`
- Focus on changes that affect users or developers, not minor code cleanup

### Documentation Maintenance  
**IMPORTANT**: Keep all `CLAUDE.md` files across the project up to date as changes are made:
- Update relevant CLAUDE.md files when modifying functionality in that directory
- Reflect architectural changes in the main CLAUDE.md file
- Update configuration documentation when adding new parameters or options
- Keep the "Improvements That Could Be Made" sections current and actionable

### Development Philosophy
**IMPORTANT**: Do not worry about backwards compatibility for existing installations or old file structures:
- Feel free to refactor configurations, file layouts, and directory structures for improvement
- Breaking changes to enhance the codebase are acceptable and encouraged
- Focus on creating the best possible system rather than maintaining legacy support
- Users can recreate installations if needed for major improvements

## Common Issues and Solutions

### Missing Dependencies
Run `./install-dependencies.sh --check` to identify missing components. The script supports apt (Debian/Ubuntu), Homebrew (macOS), and dnf (Fedora/RHEL).

### ROM File Requirements
68k emulation requires Quadra 800 ROM file at `m68k/800.ROM`. This is not included and must be provided by the user.

### Performance vs Stability
- Maximum performance: `writeback` cache + `native` AIO + `multi` TCG
- Maximum stability: `writethrough` cache + `threads` AIO + `single` TCG
- Default configs balance performance and reliability

### Boot Order Issues
- **68k**: Uses SCSI device ID assignment (6=OS, 3=CD for install mode)
- **PowerPC**: Uses simple boot flags (`-boot c` for HDD, `-boot d` for CD)
- Installation mode (`-b` flag) automatically handles boot priority

## Testing and Validation

### Basic Functionality Tests
```bash
# Test dependency installation
./install-dependencies.sh --check

# Test configuration loading
./runmac.sh -C m68k/configs/m68k-macos753.conf -?

# Test software library
./mac-library.sh list
```

### Configuration Validation
The system validates all configuration files for:
- Architecture compatibility
- Required variable presence  
- File path existence
- Hardware option validity

Use the dry-run help mode to test configs without launching emulation:
```bash
./runmac.sh -C <config> -?
```