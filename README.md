# QEMU m68k Mac Emulation Helper Scripts

A comprehensive, modular set of shell scripts designed to simplify the setup and management of classic Macintosh (m68k architecture) emulation using QEMU. This project enables you to run multiple Mac OS configurations with flexible networking modes and seamless file sharing capabilities.

**🎥 See it in action:** [YouTube Demo](https://www.youtube.com/watch?v=YA2fHUXZhas)

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Architecture & Scripts](#architecture--scripts)
- [Configuration System](#configuration-system)
- [Usage Guide](#usage-guide)
- [Networking Modes](#networking-modes)
- [File Sharing](#file-sharing)
- [Getting Started Tutorial](#getting-started-tutorial)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
- [Development & Contributing](#development--contributing)

## Overview

This project provides a robust framework for classic Mac emulation with modern conveniences:

- **Multiple Mac OS Versions**: Run System 6.x through Mac OS 8.x on emulated 68k Macs
- **Flexible Networking**: Choose between TAP (VM-to-VM), User Mode (internet), or Passt networking
- **File Sharing**: Seamless file transfer between host and guest via shared disk images
- **Configuration Management**: Simple `.conf` files define complete emulation environments
- **Modular Architecture**: Well-organized, maintainable codebase with comprehensive error handling

### Project Goals

- Provide a consistent and repeatable way to launch QEMU for specific Mac models and OS versions
- Manage separate disk images (OS, shared data, PRAM) for different configurations
- Enable flexible networking for both internet access and VM-to-VM communication
- Simplify OS installation and file transfer workflows
- Maintain a secure, well-documented, and extensible codebase

## Key Features

✅ **Modular Design**: Clean separation of concerns across multiple specialized scripts  
✅ **Schema Validation**: Robust configuration validation with helpful error messages  
✅ **Security First**: Proper input validation, secure command construction, strict error handling  
✅ **Debug Support**: Comprehensive logging and debug mode for troubleshooting  
✅ **Auto-Detection**: Smart defaults for display types and network interfaces  
✅ **Version Checking**: QEMU compatibility validation and warnings  
✅ **Package Management**: Automatic installation of required dependencies  
✅ **Cross-Platform**: Designed for Linux, tested on Ubuntu, works on macOS (including Apple Silicon)  

## Quick Start

### Automatic Installation (Recommended)
```bash
# 1. Check what dependencies you need
./install-dependencies.sh --check

# 2. Install all dependencies automatically
./install-dependencies.sh

# 3. Place your ROM file (e.g., 800.ROM) in the project directory

# 4. Run a Mac OS installation
./run68k.sh -C sys755-q800.conf -c /path/to/Mac_OS.iso -b

# 5. After installation, run normally
./run68k.sh -C sys755-q800.conf
```

### Manual Installation

#### Linux (Ubuntu/Debian)
```bash
# 1. Install dependencies
sudo apt update && sudo apt install qemu-system-m68k qemu-utils bridge-utils iproute2 passt hfsprogs

# 2. Place your ROM file (e.g., 800.ROM) in the project directory

# 3. Run a Mac OS installation (uses TAP networking by default)
./run68k.sh -C sys755-q800.conf -c /path/to/Mac_OS.iso -b

# 4. After installation, run normally
./run68k.sh -C sys755-q800.conf

# 5. Share files (when VM is shut down)
sudo ./mac_disc_mounter.sh -C sys755-q800.conf
```

#### macOS (Intel/Apple Silicon)
```bash
# 1. Install QEMU and modern bash
brew install qemu bash

# 2. Place your ROM file (e.g., 800.ROM) in the project directory  

# 3. Run a Mac OS installation (uses User Mode networking by default)
./run68k.sh -C sys755-q800.conf -c /path/to/Mac_OS.iso -b

# 4. After installation, run normally (auto-detects User Mode on macOS)
./run68k.sh -C sys755-q800.conf

# 5. Share files via shared disk (format as HFS/HFS+ in Mac OS first)
# Files can be accessed directly from host at: ./761/shared_761.img
```

## Prerequisites

### Automatic Dependency Management

The easiest way to get started is using the included dependency installer:

```bash
# Check what's needed on your system
./install-dependencies.sh --check

# Install everything automatically
./install-dependencies.sh

# Force reinstall if needed
./install-dependencies.sh --force
```

### Supported Package Managers

- **Linux**: apt (Debian/Ubuntu), dnf (Fedora/RHEL)
- **macOS**: Homebrew
- **Manual**: Instructions provided for unsupported systems

### Required Software

1. **QEMU (minimum version 4.0)**
   ```bash
   # Linux (Debian/Ubuntu) - included in automatic installer
   sudo apt update && sudo apt install qemu-system-m68k qemu-utils
   
   # Linux (Fedora/RHEL) - included in automatic installer  
   sudo dnf install qemu-system-m68k qemu-img
   
   # macOS (Homebrew)
   brew install qemu
   ```

2. **Modern Bash (macOS only)**
   ```bash
   # macOS ships with bash 3.2, but scripts require bash 4.0+ for associative arrays
   brew install bash
   ```

3. **Networking Utilities (Linux TAP mode only)**
   ```bash
   # Linux (Debian/Ubuntu)
   sudo apt install bridge-utils iproute2
   
   # Note: TAP networking not available on macOS - uses User Mode automatically
   ```

4. **HFS/HFS+ Tools (Linux file sharing only)**
   ```bash
   # Linux: Automatically installed by mac_disc_mounter.sh when needed
   sudo apt install hfsprogs hfsplus
   
   # macOS: Not needed - shared disk can be accessed directly as raw image
   ```

### Required Files (Not Included)

4. **Macintosh ROM Files** ⚠️ **Legally Required**
   - You MUST obtain ROM files legally (e.g., from your own hardware)
   - Common sources: [Macintosh Repository](https://www.macintoshrepository.org/7038-all-macintosh-roms-68k-ppc-)
   - Place ROM files where your `.conf` files reference them
   - Example: `800.ROM` for Quadra 800 emulation

5. **Mac OS Installation Media**
   - CD-ROM images (.iso, .img, .toast) or floppy disk images
   - Recommended: [Apple Legacy Software Recovery CD](https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd)
   - Contains essential utilities like Drive Setup for disk formatting

### System Requirements

- **Linux Host**: Primary target (Ubuntu tested, other distributions supported)
- **Sudo Access**: Required for TAP networking and disk mounting
- **Disk Space**: ~500MB per Mac OS installation (configurable)
- **Memory**: 128MB+ RAM allocation per VM (configurable)

## Architecture & Scripts

The project uses a modular architecture for maintainability and extensibility:

### Core Scripts

| Script | Purpose | Dependencies |
|--------|---------|--------------|
| **`run68k.sh`** | Main orchestration script | All modules |
| **`qemu-utils.sh`** | Shared utilities and error handling | None |
| **`mac_disc_mounter.sh`** | File sharing via disk mounting | `qemu-utils.sh` |

### Modular Components

| Module | Responsibility | Key Functions |
|--------|----------------|---------------|
| **`qemu-config.sh`** | Configuration loading & validation | Schema validation, defaults |
| **`qemu-storage.sh`** | Disk image & PRAM management | Image creation, boot order |
| **`qemu-networking.sh`** | Network setup for all modes | TAP, User, Passt setup |
| **`qemu-display.sh`** | Display type detection | Auto-detection, validation |
| **`qemu-tap-functions.sh`** | TAP networking implementation | Bridge/TAP management |

### Configuration Files

- **`sys710-q800.conf`**: System 7.1.0 on Quadra 800
- **`sys755-q800.conf`**: System 7.5.5 on Quadra 800  
- **`sys761-q800.conf`**: System 7.6.1 on Quadra 800
- **Custom configs**: Create your own for different setups

## Configuration System

Configuration files use shell variable assignments to define complete emulation environments. The system provides schema validation with helpful error messages.

### Required Variables

```bash
CONFIG_NAME="System 7.5.5 (Quadra 800)"     # Descriptive name
QEMU_MACHINE="q800"                          # QEMU machine type
QEMU_RAM="128"                               # RAM in MB
QEMU_ROM="800.ROM"                           # ROM file path
QEMU_HDD="755/hdd_sys755.img"               # OS disk image
QEMU_SHARED_HDD="755/shared_755.img"        # Shared disk image
QEMU_PRAM="755/pram_755_q800.img"           # PRAM file
QEMU_GRAPHICS="1152x870x8"                  # Resolution & color depth
```

### Optional Variables

```bash
QEMU_CPU=""                                  # CPU override (default: auto)
QEMU_HDD_SIZE="1G"                          # OS disk size (default: 1G)
QEMU_SHARED_HDD_SIZE="200M"                 # Shared disk size (default: 200M)

# Networking (TAP mode)
BRIDGE_NAME="br0"                           # Bridge name (default: br0)
QEMU_TAP_IFACE="tap_sys755"                 # TAP interface name (auto-generated)
QEMU_MAC_ADDR="52:54:00:AA:BB:CC"          # MAC address (auto-generated)

# User mode networking
QEMU_USER_SMB_DIR="/path/to/share"          # SMB share directory
```

### Validation Features

- ✅ **Required Variable Checking**: Ensures all mandatory settings are present
- ✅ **File Existence Validation**: Verifies ROM files and paths exist
- ✅ **Network-Specific Validation**: Checks TAP-specific settings when needed
- ✅ **Schema Documentation**: Clear error messages explain what's missing
- ✅ **Default Value Assignment**: Automatic defaults for optional settings

### Creating Custom Configurations

```bash
# Copy an existing config
cp sys755-q800.conf my-custom-config.conf

# Edit the variables
nano my-custom-config.conf

# Use your custom config
./run68k.sh -C my-custom-config.conf
```

## Usage Guide

### Main Script: `run68k.sh`

The primary script for launching Mac emulation with comprehensive options:

```bash
./run68k.sh -C <config_file.conf> [options]
```

#### Required Arguments

- **`-C FILE`**: Configuration file (e.g., `sys755-q800.conf`)

#### Optional Arguments

| Option | Description | Example |
|--------|-------------|---------|
| **`-c FILE`** | CD-ROM image file | `-c Mac_OS_7.5.iso` |
| **`-a FILE`** | Additional hard drive | `-a extra-software.img` |
| **`-b`** | Boot from CD-ROM (requires `-c`) | `-b` |
| **`-d TYPE`** | Force display type | `-d gtk` |
| **`-N TYPE`** | Network mode | `-N user` |
| **`-D`** | Enable debug mode | `-D` |
| **`-?`** | Show help message | `-?` |

#### Display Types

- **`sdl`**: Simple DirectMedia Layer (Linux default)
- **`gtk`**: GTK-based display
- **`cocoa`**: macOS native (auto-detected on macOS)
- **`vnc`**: VNC server for remote access
- **`none`**: Headless mode

#### Network Types

- **`tap`** (default): Bridged networking for VM-to-VM communication
- **`user`**: NAT networking for internet access
- **`passt`**: Modern user-space networking (requires passt package)

### Examples

#### Basic Usage
```bash
# Run existing installation with TAP networking
./run68k.sh -C sys755-q800.conf

# Run with internet access (User mode)
./run68k.sh -C sys755-q800.conf -N user

# Run with debug logging
./run68k.sh -C sys755-q800.conf -D
```

#### OS Installation
```bash
# Install from CD with boot flag
./run68k.sh -C sys761-q800.conf -c /path/to/Mac_OS_7.6.1.iso -b

# First boot after installation (without CD)
./run68k.sh -C sys761-q800.conf
```

#### Advanced Usage
```bash
# Custom display and additional storage
./run68k.sh -C sys755-q800.conf -d gtk -a /path/to/software.img

# Headless operation with VNC
./run68k.sh -C sys755-q800.conf -d vnc

# Force specific display on auto-detection failure
./run68k.sh -C sys755-q800.conf -d sdl
```

## Networking Modes

The networking system supports three distinct modes, each optimized for different use cases:

### TAP Mode (Linux Default) - VM-to-VM Communication

**Best for**: Multiple VMs that need to communicate directly (AppleTalk, network games, file sharing)  
**Note**: Linux only - requires Linux-specific networking tools

```bash
./run68k.sh -C sys755-q800.conf -N tap
```

**Requirements:**
- `sudo` privileges
- `bridge-utils` package
- `iproute2` package
- `qemu-tap-functions.sh` script

**How it works:**
1. Creates a network bridge (default: `br0`)
2. Creates a TAP interface for each VM
3. Connects TAP interfaces to the bridge
4. VMs can communicate directly via the bridge
5. Automatic cleanup on VM shutdown

**Configuration in Mac OS:**
- **Control Panels**: Use MacTCP or TCP/IP
- **Connection**: Select "Ethernet"
- **IP Addressing**: Use static IPs or set up DHCP
- **AppleTalk**: Enable via AppleTalk control panel

**Benefits:**
- ✅ Direct VM-to-VM communication
- ✅ AppleTalk networking support
- ✅ Network game compatibility
- ✅ Simulates real network environment

**Limitations:**
- ❌ No automatic internet access
- ❌ Requires sudo privileges
- ❌ More complex setup

### User Mode - Internet Access (macOS Default)

**Best for**: Single VM that needs internet access, simple setups, no admin privileges  
**Note**: Default on macOS where TAP mode requires Linux-specific tools

```bash
./run68k.sh -C sys755-q800.conf -N user
```

**Requirements:**
- None beyond QEMU itself
- Optional: SMB directory for file sharing

**How it works:**
- QEMU provides built-in NAT and DHCP
- VM gets internet access via host connection
- Optional SMB file sharing
- No host network configuration needed

**Configuration in Mac OS:**
- **Control Panels**: Use MacTCP or TCP/IP
- **Connection**: Select "Ethernet"
- **IP Addressing**: Use "DHCP Server"
- **Typical IP Range**: 10.0.2.x

**Benefits:**
- ✅ Simple internet access
- ✅ No sudo required
- ✅ No host network setup
- ✅ Built-in DHCP

**Limitations:**
- ❌ No VM-to-VM communication
- ❌ Limited host-to-VM access
- ❌ No AppleTalk support

### Passt Mode - Modern Networking

**Best for**: Advanced users wanting modern networking performance

```bash
./run68k.sh -C sys755-q800.conf -N passt
```

**Requirements:**
- `passt` package installed
- See: https://passt.top/

**Benefits:**
- ✅ Better performance than user mode
- ✅ Modern networking stack
- ✅ No sudo required

## File Sharing

The `mac_disc_mounter.sh` script provides seamless file transfer between your Linux host and Mac VMs via shared disk images.

### Basic Usage

```bash
# Mount shared disk (VM must be shut down)
sudo ./mac_disc_mounter.sh -C sys755-q800.conf

# Copy files to/from /mnt/mac_shared

# Unmount when done
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -u
```

### Advanced Options

```bash
# Custom mount point
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -m /home/user/macfiles

# Check filesystem type
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -c

# Repair corrupted filesystem
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -r
```

### Important Notes

⚠️ **VM Must Be Shut Down**: Always ensure the VM is completely shut down before mounting

⚠️ **Format in Mac OS First**: Use Drive Setup in Mac OS to format the shared disk as HFS or HFS+

⚠️ **Backup Important Data**: Always backup important files before filesystem operations

### Troubleshooting File Sharing

```bash
# If mount fails, check filesystem
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -c

# Attempt repair if corrupted
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -r

# Check what's using the mount point
sudo lsof +f -- /mnt/mac_shared
```

## Getting Started Tutorial

This step-by-step guide will help you set up your first Mac OS emulation environment.

### Step 1: Install Prerequisites

```bash
# Update package lists
sudo apt update

# Install QEMU and networking tools
sudo apt install qemu-system-m68k qemu-utils bridge-utils

# Verify installation
qemu-system-m68k --version
```

### Step 2: Obtain Required Files

1. **Get ROM Files** (legally required)
   - Download from [Macintosh Repository](https://www.macintoshrepository.org/7038-all-macintosh-roms-68k-ppc-)
   - Or dump from your own hardware
   - Place `800.ROM` in the project directory

2. **Get Mac OS Installation Media**
   - Download [Apple Legacy Software Recovery CD](https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd)
   - Or use your own Mac OS installation CDs

### Step 3: Choose a Configuration

```bash
# List available configurations
ls *.conf

# Use System 7.5.5 for this tutorial
CONFIG_FILE="sys755-q800.conf"
```

### Step 4: Install Mac OS

```bash
# Boot from installation CD
./run68k.sh -C sys755-q800.conf -c /path/to/Mac_OS_CD.iso -b
```

**In the Mac OS installer:**
1. Wait for the system to boot from CD
2. Open "Drive Setup" from the CD
3. Initialize both hard disks:
   - Format the larger disk for Mac OS installation
   - Format the smaller disk (shared) for file transfer
4. Run the Mac OS installer
5. Install Mac OS to the larger disk
6. Shut down when installation completes

### Step 5: First Boot

```bash
# Boot from hard disk (remove -c and -b flags)
./run68k.sh -C sys755-q800.conf
```

### Step 6: Configure Networking (Optional)

**For Internet Access:**
```bash
# Shut down the VM and restart with user networking
./run68k.sh -C sys755-q800.conf -N user
```

In Mac OS:
1. Open TCP/IP control panel
2. Select "Ethernet" connection
3. Configure using "DHCP Server"
4. Test internet connectivity

**For VM-to-VM Communication:**
```bash
# Use default TAP networking (already configured)
./run68k.sh -C sys755-q800.conf
```

### Step 7: Test File Sharing

```bash
# Shut down the VM completely

# Mount the shared disk
sudo ./mac_disc_mounter.sh -C sys755-q800.conf

# Copy files to the shared disk
cp /path/to/files/* /mnt/mac_shared/

# Unmount the shared disk
sudo ./mac_disc_mounter.sh -C sys755-q800.conf -u

# Start the VM and access files from the shared disk
./run68k.sh -C sys755-q800.conf
```

### Next Steps

- **Multiple VMs**: Create additional configurations for different Mac OS versions
- **Networking**: Set up multiple VMs for AppleTalk networking
- **Software**: Install period-appropriate software and games
- **Backups**: Use `qemu-img` to create snapshots of your disk images

## Advanced Usage

### Creating VM Snapshots

```bash
# Create a snapshot before making changes
qemu-img snapshot -c "clean_install" 755/hdd_sys755.img

# List snapshots
qemu-img snapshot -l 755/hdd_sys755.img

# Restore from snapshot
qemu-img snapshot -a "clean_install" 755/hdd_sys755.img
```

### Multiple VM Setup

```bash
# Create configurations for different systems
cp sys755-q800.conf sys71-q800.conf
cp sys755-q800.conf sys8-q800.conf

# Edit each config for different directories and names
# Start multiple VMs (they can communicate via TAP)
./run68k.sh -C sys755-q800.conf &
./run68k.sh -C sys71-q800.conf &
```

### Custom ROM and Machine Types

```bash
# Create config for different Mac models
# Edit QEMU_MACHINE for different emulated hardware:
# - q800: Quadra 800 (default)
# - plus: Macintosh Plus
# - se30: Macintosh SE/30
```

### Debug Mode

```bash
# Enable comprehensive debugging
./run68k.sh -C sys755-q800.conf -D

# This enables:
# - Command tracing (set -x)
# - Detailed logging
# - PRAM inspection
# - Network setup details
```

### Performance Tuning

```bash
# Increase RAM allocation (edit .conf file)
QEMU_RAM="256"  # Increase from default 128MB

# Use faster disk image format (one-time conversion)
qemu-img convert -f raw -O qcow2 755/hdd_sys755.img 755/hdd_sys755.qcow2

# Edit config to use qcow2 format
QEMU_HDD="755/hdd_sys755.qcow2"
```

## Troubleshooting

### Common Issues and Solutions

#### ROM File Issues
```
Error: ROM file '800.ROM' not found.
```
**Solution**: 
- Verify the ROM file exists and is named correctly
- Check the path in your `.conf` file
- Ensure you have the correct ROM for your machine type

#### Permission Issues
```
Error: Failed to create directory/image
```
**Solution**:
```bash
# Check and fix permissions
sudo chown -R $USER:$USER /path/to/project
chmod +x *.sh
```

#### Network Issues (TAP Mode)
```
Error: Failed to create bridge/TAP
```
**Solutions**:
```bash
# Ensure bridge-utils is installed
sudo apt install bridge-utils

# Check if bridge already exists
ip link show br0

# Manual bridge cleanup if needed
sudo ip link delete br0
```

#### VMs Cannot See Each Other
**Check**:
- Both VMs use TAP networking (`-N tap`)
- Both VMs are on the same bridge
- Configure static IPs or DHCP in Mac OS
- AppleTalk is enabled in both VMs

#### No Internet Access
**TAP Mode**: This is expected behavior
```bash
# Switch to user mode for internet
./run68k.sh -C config.conf -N user
```

**User Mode**: Check Mac OS TCP/IP settings
- Use "DHCP Server" configuration
- Verify host has internet connectivity

#### Display Issues
```bash
# Try different display types
./run68k.sh -C config.conf -d gtk
./run68k.sh -C config.conf -d sdl

# Install display libraries
sudo apt install libsdl2-dev libgtk-3-dev
```

#### Shared Disk Mounting Issues
```bash
# Check if VM is properly shut down
ps aux | grep qemu

# Check filesystem type
sudo ./mac_disc_mounter.sh -C config.conf -c

# Attempt repair
sudo ./mac_disc_mounter.sh -C config.conf -r

# Check system logs
sudo dmesg | tail
```

### Debug Mode

Enable comprehensive debugging for complex issues:

```bash
./run68k.sh -C sys755-q800.conf -D
```

Debug mode provides:
- Command tracing with `set -x`
- Detailed error messages with line numbers
- Network setup diagnostics
- PRAM inspection before boot
- Comprehensive logging throughout

### Getting Help

1. **Check the logs**: Most errors provide detailed context
2. **Use debug mode**: Enable with `-D` flag for maximum detail
3. **Verify prerequisites**: Ensure all required packages are installed
4. **Check file permissions**: Ensure scripts are executable and directories writable
5. **Review configuration**: Validate your `.conf` file settings

### Known Issues

- **Boot Flag Limitation**: The `-b` flag behavior may not be respected when supplying an ISO as CD - the Mac may always attempt to boot from CD when present
- **TAP Network Persistence**: TAP interfaces are automatically cleaned up, but manual cleanup may be needed if scripts are forcefully terminated
- **HFS+ Compatibility**: Some newer HFS+ features may not be fully supported by Linux mounting tools

## Development & Contributing

### Architecture Overview

The codebase follows modern shell scripting best practices:

- **Modular Design**: Clear separation of concerns across specialized modules
- **Error Handling**: Strict bash mode with comprehensive error checking
- **Security**: Input validation, secure command construction, proper quoting
- **Documentation**: Standardized function headers and inline documentation
- **Testing**: Manual testing procedures with debug support

### Code Standards

- **Strict Mode**: All scripts use `set -euo pipefail`
- **Function Documentation**: Standardized headers with parameters and return values
- **Variable Naming**: `UPPER_CASE` for globals, `lower_case` for locals
- **Error Handling**: Consistent error checking with `check_exit_status()`
- **Security**: Proper quoting, input validation, array-based command construction

### Adding New Features

#### New Networking Mode
1. Add implementation to `qemu-networking.sh`
2. Update help text in `run68k.sh`
3. Add validation in argument parsing
4. Test with existing configurations

#### New Machine Type
1. Create new `.conf` file with appropriate settings
2. Ensure ROM file compatibility
3. Test boot and operation
4. Document any special requirements

#### New Display Type
1. Add validation to `qemu-display.sh`
2. Test display functionality
3. Update help documentation

### Contributing Guidelines

1. **Follow Code Standards**: Maintain consistent style and error handling
2. **Test Thoroughly**: Verify functionality across different configurations
3. **Document Changes**: Update README.md and inline documentation
4. **Security Review**: Ensure proper input validation and secure practices
5. **Maintain Compatibility**: Preserve existing configuration file compatibility

### File Organization

```
QemuMac/
├── run68k.sh                 # Main orchestration script
├── qemu-utils.sh             # Shared utilities
├── qemu-config.sh            # Configuration management
├── qemu-storage.sh           # Storage and PRAM handling
├── qemu-networking.sh        # Network mode management
├── qemu-display.sh           # Display type handling
├── qemu-tap-functions.sh     # TAP networking implementation
├── mac_disc_mounter.sh       # File sharing utility
├── sys*.conf                 # Configuration files
├── README.md                 # This file
├── CLAUDE.md                 # Development guidance
└── *.ROM                     # ROM files (user-provided)
```

---

## License & Legal

This project provides scripts for managing QEMU emulation. Users are responsible for:

- **ROM Files**: Legally obtaining Macintosh ROM files
- **Software**: Ensuring proper licensing for emulated software
- **Compliance**: Following all applicable copyright and licensing laws

The scripts themselves are provided as-is for educational and personal use.

---

**Happy Emulating!** 🖥️✨

For questions, issues, or contributions, please review the troubleshooting section and consider contributing improvements back to the project.