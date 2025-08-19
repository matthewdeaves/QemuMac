# Qemu2 - Classic Macintosh Emulation

A collection of scripts for running classic Macintosh VMs using QEMU, supporting both 68k (Quadra 800) and PowerPC (PowerMac G4) architectures.

## Requirements

- QEMU 10.x (tested with 10.0.92/v10.1.0-rc2)
- Dependencies: `jq`, `curl`, `unzip`
- ROM file: `roms/800.ROM` (for 68k VMs)

### Installing Dependencies

For macOS and Ubuntu/Debian Linux, you can run the dependency installer:

```bash
./install-deps.sh
```

This script will:
- Install required system dependencies (via Homebrew on macOS, apt on Ubuntu)
- Build the latest QEMU from source with m68k and ppc support
- Install QEMU either locally (in `qemu_install/`) or globally
- Verify the installation works correctly

The script supports both local installation (recommended) and global system-wide installation.

## Quick Start

### 1. Interactive Launch (Recommended)
```bash
./launch.sh
```
Select VM and ISO from menus, choose boot options.

### 2. Download Software
```bash
./iso-downloader.sh
```
Downloads Mac OS installers and software from curated database.

**Custom Software**: Create `iso/custom-software.json` to add your own download sources. The script will automatically merge it with the default database. Use the same structure as `iso/software-database.json`.

### 3. Create New VM
```bash
./run-mac.sh --create-config my_mac
```

## Usage Examples

### Installing Mac OS (typical workflow)
```bash
# 1. Create VM
./run-mac.sh --create-config quadra_fresh

# 2. Boot from install disc, format hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf --iso iso/MacOS922.iso --boot-from-cd

# 3. After installation, boot normally from hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf
```

### Running with Software
```bash
# Boot normally with game disc mounted
./run-mac.sh --config vms/quadra800/quadra800.conf --iso iso/Marathon.iso
```

## Directory Structure

- `vms/` - VM configurations and disk images
- `iso/` - ISO files and software database
- `roms/` - ROM files (800.ROM required for 68k)

## Architectures

- **68k (Quadra 800)**: 128M RAM, 2G disk, requires ROM file
- **PPC (PowerMac G4)**: 512M RAM, 10G disk, no ROM needed

## Controls

- **Linux**: Right-Ctrl+G to release mouse
- **macOS**: Native Cocoa interface