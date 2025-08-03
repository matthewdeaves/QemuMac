# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This project provides a modular set of shell scripts to simplify the setup and management of classic Macintosh emulation using QEMU. It supports both **68k (m68k)** and **PowerPC (ppc)** architectures with different networking modes and file sharing capabilities. The codebase has been organized with clean architecture separation for maintainability, security, and modularity.

## Architecture Overview

The project now supports dual architectures with a unified interface:

- **Unified Interface**: `runmac.sh` - Auto-detects architecture from config and dispatches to appropriate script
- **68k Emulation**: `m68k/run68k.sh` - Classic Mac OS 7.0-8.1 on Quadra 800 (q800 machine)
- **PowerPC Emulation**: `ppc/runppc.sh` - Mac OS 9.1 and Mac OS X 10.4 Tiger (mac99 machine)

## Directory Structure

```
QemuMac/
├── runmac.sh (unified dispatcher)
├── m68k/ (68k architecture)
│   ├── run68k.sh
│   ├── configs/ (sys753-*, sys761-*)
│   ├── 753/, 761/ (system data)
│   ├── 800.ROM
│   └── scripts/ (68k-specific utilities)
├── ppc/ (PowerPC architecture)
│   ├── runppc.sh
│   ├── configs/ (macos91-*, osxtiger104-*)
│   ├── data/91/, data/tiger104/
│   └── scripts/ (ppc-specific utilities)
├── scripts/ (shared utilities)
│   ├── qemu-utils.sh
│   ├── qemu-networking.sh
│   ├── qemu-display.sh
│   ├── qemu-config.sh
│   └── mac_disc_mounter.sh
├── library/ (software database)
└── install-dependencies.sh
```

## Common Commands

### Unified Interface (Recommended)
```bash
# 68k Mac OS emulation
./runmac.sh -C m68k/configs/sys753-standard.conf      # Mac OS 7.5.3 balanced
./runmac.sh -C m68k/configs/sys761-ultimate.conf     # Mac OS 7.6.1 maximum performance

# PowerPC Mac OS emulation  
./runmac.sh -C ppc/configs/macos91-standard.conf     # Mac OS 9.1 balanced
./runmac.sh -C ppc/configs/osxtiger104-fast.conf     # Mac OS X Tiger performance

# Installation workflow
./runmac.sh -C ppc/configs/macos91-standard.conf -c /path/to/MacOS91.iso -b  # Install
./runmac.sh -C ppc/configs/macos91-standard.conf                             # Run

# Network mode override
./runmac.sh -C ppc/configs/osxtiger104-standard.conf -N user    # User mode networking
./runmac.sh -C m68k/configs/sys753-standard.conf -N tap        # TAP networking

# Additional options
./runmac.sh -C ppc/configs/macos91-standard.conf -a /path/to/software.img -D  # Additional HDD + debug
```

### Direct Access (Debugging/Advanced Use)
```bash
# Direct 68k access
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf

# Direct PowerPC access  
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf
./ppc/runppc.sh -C ppc/configs/osxtiger104-standard.conf
```

## Architecture-Specific Features

### 68k (m68k) Emulation
- **Machine Type**: Quadra 800 (q800)
- **ROM Requirement**: 800.ROM file (user-provided)
- **Storage**: Complex SCSI setup with ID management
- **Boot Control**: PRAM manipulation for boot order
- **OS Support**: Mac OS 7.0-8.1
- **Audio**: Apple Sound Chip (ASC) with easc/asc modes
- **Memory**: Typically 128MB RAM

### PowerPC (ppc) Emulation  
- **Machine Type**: Power Mac G3/G4 (mac99,via=pmu)
- **BIOS**: Built-in via `-L pc-bios` (no ROM file needed)
- **Storage**: Simple IDE channels (Primary/Secondary Master/Slave)
- **Boot Control**: Simple `-boot c/d` flags
- **OS Support**: Mac OS 9.1, Mac OS X 10.4 Tiger
- **Audio**: ES1370 sound device
- **Memory**: 512MB for OS 9, 1024MB for OS X
- **USB**: Optional USB support for Mac OS X

## Configuration System

### Architecture Detection
All config files must define an `ARCH` variable:
```bash
ARCH="m68k"  # For 68k configs
ARCH="ppc"   # For PowerPC configs
```

### 68k Configuration Examples
```bash
# m68k/configs/sys753-standard.conf
ARCH="m68k"
CONFIG_NAME="System 7.5.3 (Standard)"
QEMU_MACHINE="q800"
QEMU_RAM="128"
QEMU_ROM="m68k/800.ROM"
QEMU_HDD="753/hdd_sys753.img"
QEMU_PRAM="753/pram_753_q800.img"
QEMU_SCSI_CACHE_MODE="writethrough"
QEMU_ASC_MODE="easc"
```

### PowerPC Configuration Examples
```bash
# ppc/configs/macos91-standard.conf
ARCH="ppc"
CONFIG_NAME="Mac OS 9.1 (Standard)"
QEMU_MACHINE="mac99,via=pmu"
QEMU_RAM="512"
QEMU_HDD="91/MacOS9.1.img"
QEMU_SHARED_HDD="91/shared_91.img"
QEMU_IDE_CACHE_MODE="writethrough"
QEMU_SOUND_DEVICE="es1370"

# ppc/configs/osxtiger104-standard.conf
ARCH="ppc"
CONFIG_NAME="Mac OS X 10.4 Tiger (Standard)"
QEMU_MACHINE="mac99,via=pmu"
QEMU_RAM="1024"
QEMU_HDD="tiger104/MacOSX10.4.img"
QEMU_USB_ENABLED="true"
```

## Performance Variants

Both architectures support performance tuning variants:

### 68k Variants
- `sys753-standard.conf`: Balanced default (writethrough cache)
- `sys753-fast.conf`: Speed-focused (writeback cache)
- `sys753-ultimate.conf`: Maximum performance (writeback + native AIO + MTTCG)
- `sys753-safest.conf`: Maximum safety (no cache)
- `sys753-authentic.conf`: Historical accuracy (NuBus graphics)

### PowerPC Variants
- `macos91-standard.conf`: Balanced default (writethrough cache, 512MB)
- `macos91-fast.conf`: Performance-focused (writeback cache, native AIO)
- `osxtiger104-standard.conf`: Balanced Tiger (writethrough cache, 1024MB, USB)
- `osxtiger104-fast.conf`: Performance Tiger (writeback cache, native AIO)

## Cross-Platform Compatibility

### Linux (Full Support)
- **Networking**: TAP networking by default with bridge support
- **File Sharing**: HFS/HFS+ mount support for shared disks
- **Display**: SDL/GTK displays
- **Dependencies**: Complete QEMU + bridge-utils + hfsprogs support

### macOS (User Mode Focus)
- **Networking**: User mode networking by default (TAP requires Linux tools)
- **Display**: Cocoa display support
- **Dependencies**: Homebrew QEMU installation
- **Limitations**: No TAP networking, no HFS mounting

## Networking Modes

- **TAP Mode (`-N tap`, Linux default)**: Bridged networking for VM-to-VM communication
- **User Mode (`-N user`, macOS default)**: NAT networking for internet access  
- **Passt Mode (`-N passt`)**: Modern user-space networking

## Development Architecture

### Shared Components (Architecture Agnostic)
- `scripts/qemu-networking.sh`: TAP/User/Passt networking setup
- `scripts/qemu-display.sh`: Display detection and validation
- `scripts/qemu-config.sh`: Configuration loading and validation
- `scripts/qemu-utils.sh`: Common utilities and error handling
- `scripts/mac_disc_mounter.sh`: HFS file sharing utility

### Architecture-Specific Components
- **68k**: Complex SCSI management, PRAM boot control, ROM handling
- **PowerPC**: Simple IDE storage, boot flags, BIOS handling

### Installation and Dependencies
```bash
# Install all dependencies (both architectures)
./install-dependencies.sh

# Check dependencies
./install-dependencies.sh --check

# Architecture-specific requirements:
# - qemu-system-m68k (for 68k)
# - qemu-system-ppc (for PowerPC)
# - bridge-utils, iproute2 (Linux TAP networking)
# - hfsprogs (Linux HFS+ file sharing)
```

## Key Technical Differences

### Boot Process
- **68k**: Complex PRAM manipulation to control boot order
- **PowerPC**: Simple `-boot c` (HDD) or `-boot d` (CD) flags

### Storage
- **68k**: SCSI with complex ID management (ID 6=OS, 5=Shared, 4=Additional, 3=CD)
- **PowerPC**: IDE channels (Primary/Secondary Master/Slave)

### BIOS/ROM  
- **68k**: Requires user-provided 800.ROM file
- **PowerPC**: Uses QEMU built-in BIOS via `-L pc-bios`

### Performance Tuning
Both architectures support identical TCG threading and caching options:
- `QEMU_TCG_THREAD_MODE`: single/multi threading
- `QEMU_TB_SIZE`: Translation block cache size
- Cache modes: writethrough/writeback/none/directsync
- AIO modes: threads/native

## Common Workflows

### Installing a New OS
```bash
# PowerPC Mac OS 9.1 installation
./runmac.sh -C ppc/configs/macos91-standard.conf -c MacOS91.iso -b

# 68k Mac OS 7.5.3 installation  
./runmac.sh -C m68k/configs/sys753-standard.conf -c System753.iso -b
```

### File Sharing
```bash
# Linux: Mount shared disk (after formatting in Mac OS)
sudo ./scripts/mac_disc_mounter.sh -C m68k/configs/sys753-standard.conf
sudo ./scripts/mac_disc_mounter.sh -C ppc/configs/macos91-standard.conf
```

### Performance Testing
```bash
# Compare performance variants
./runmac.sh -C ppc/configs/macos91-standard.conf    # Balanced
./runmac.sh -C ppc/configs/macos91-fast.conf        # Performance
```

## Library Integration

The Mac Library Manager supports both architectures:
```bash
./mac-library.sh  # Auto-detects architecture from selected software
```

Software database includes:
- **68k**: Classic Mac OS 7.x software and games
- **PowerPC**: Mac OS 9 and Mac OS X Tiger software

## Important Development Notes

### Adding New Configurations
1. Copy existing config as template
2. Ensure `ARCH` variable is set correctly  
3. Adjust architecture-specific variables only
4. Test with both installation and runtime scenarios

### Code Organization
- Keep shared utilities in `scripts/` for both architectures
- Put architecture-specific code in `m68k/scripts/` or `ppc/scripts/`
- All configs must have valid `ARCH` variable for dispatcher
- Use unified `runmac.sh` interface for consistent user experience

### Testing Requirements
- Test both Ubuntu (TAP networking) and macOS (User networking) 
- Verify both installation (`-b` flag) and normal operation
- Test additional drive support (`-a` flag) for both architectures
- Validate performance variants work correctly

This dual-architecture design provides clean separation while maintaining a unified user interface and shared infrastructure for common functionality.