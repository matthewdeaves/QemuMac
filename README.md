# QemuMac - Classic Macintosh Emulation

A collection of scripts for running classic Macintosh VMs using QEMU, supporting both 68k (Quadra 800) and PowerPC (PowerMac G4) architectures.

## Requirements

- QEMU 10.x (tested with 10.0.92/v10.1.0-rc2)
- Dependencies: `jq`, `curl`, `unzip`
- ROM file: `roms/800.ROM` (for 68k VMs, auto-downloaded on first run)

### Installing Dependencies

For macOS and Ubuntu/Debian Linux, you can run the dependency installer:

```bash
./install-deps.sh
```

This script will:
- Install required system dependencies (via Homebrew on macOS, apt on Ubuntu)
- Build the latest QEMU from source with m68k and ppc support
- Install QEMU either locally (in `qemu-install/`) or globally
- Verify the installation works correctly

The script supports both local installation (recommended) and global system-wide installation.

## Quick Start

### 1. Launch a VM

For the most user-friendly experience, run the script without any arguments to open an interactive menu:

```bash
./run-mac.sh
```

This will show all available VMs with descriptions (e.g., "68k_quadra_800 - Mac OS 7.6.1") and guide you through selecting a VM, attaching an ISO, and choosing boot options.

**Note**: Multiple VMs can run simultaneously. The first VM to start gets access to the shared disk; additional VMs run without it.

### 2. Download Software
```bash
./iso-downloader.sh
```
Downloads Mac OS installers and software from curated database. Software marked with `"delivery": "shared"` downloads directly to the shared disk for immediate access in VMs. You need to have formatted the shared drive in an emulated machine before using this option!

**Custom Software**: Create `iso/custom-software.json` to add your own download sources. The script will automatically merge it with the default database. Use the same structure as `iso/software-database.json`.

### 3. Shared Disk for File Transfer
```bash
./mount-shared.sh        # Mount shared disk on host
./mount-shared.sh -u     # Unmount shared disk
```
A 512MB shared disk (HFS format) accessible by all VMs for easy file transfer between host and guests. Only one VM can access the shared disk at a time (first-come, first-served). Additional VMs can run without the shared disk.

### 4. Create New VM
```bash
./run-mac.sh --create-config my_mac
```
During VM creation, you can:
- Choose architecture (m68k Quadra 800 or PPC PowerMac G4)
- Optionally select a default installer that will be automatically downloaded and configured on first run
- Add a DESCRIPTION field to your config for easy identification in the VM menu

## Usage Examples

### Installing Mac OS (typical workflow)

**Option 1: With Default Installer (Recommended)**
```bash
# 1. Create VM and select a default installer during setup (Quadra Requires Apple Legacy Software Recovery CD)
./run-mac.sh --create-config quadra_fresh

# 2. First boot automatically downloads installer and boots from CD
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf

# 3. After installation, subsequent boots use hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf
```

**Option 2: Manual Installer Setup**
```bash
# 1. Create VM (skip default installer)
./run-mac.sh --create-config quadra_fresh

# 2. Boot from Apple Legacy Recovery disc, format hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf --iso "iso/Apple Legacy Recovery.iso" --boot-from-cd

# 3. After installation, boot normally from hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf
```

### File Transfer Between Host and VM
```bash
# 1. Start VM and format shared disk as Mac OS Standard (HFS) if needed
./run-mac.sh --config vms/68k_quadra_800/68k_quadra_800.conf

# 2. Shutdown the VM after formatting shared disk

# 3. Mount shared disk on host (requires hfsprogs)
./mount-shared.sh

# 4. Copy files to shared mount point on host (default: /tmp/qemu-shared)
cp ~/myfiles/* /tmp/qemu-shared/

# 5. Unmount when done
./mount-shared.sh -u
```

### Running with Software
```bash
# Boot normally with game disc mounted
./run-mac.sh --config vms/68k_quadra_800/68k_quadra_800.conf --iso iso/Marathon.iso
```

## Default VMs

The project includes 5 pre-configured VMs ready to use:

- **68k_quadra_800** - Mac OS 7.6.1 (Quadra 800, 128M RAM, 2G disk)
- **68k_quadra_800_os753** - Mac OS 7.5.3 (Quadra 800, 128M RAM, 2G disk)
- **power_mac_g4_os9** - Mac OS 9.2.2 (PowerMac G4, 512M RAM, 10G disk)
- **power_mac_g4_tiger** - Mac OS X Tiger 10.4 (PowerMac G4, 512M RAM, 10G disk)
- **power_mac_g4_leopard** - Mac OS X Leopard 10.5.6 (PowerMac G4, 512M RAM, 10G disk)

All default VMs include automatic installer setup on first boot.

## Directory Structure

- `vms/` - VM configurations and disk images
- `iso/` - ISO files and software database
- `roms/` - ROM files (800.ROM auto-downloaded for 68k VMs)
- `shared/` - Shared disk accessible by all VMs (auto-created)

## Features

- **Concurrent VM Support**: Run multiple VMs simultaneously (first-come, first-served for shared disk)
- **Automatic Installers**: First-run VMs auto-download and boot from installer media
- **Cross-Platform**: Works on macOS and Linux (Ubuntu/Debian)
- **File Transfer**: Shared 512MB HFS disk accessible by all VMs
- **Performance Optimized**: Writeback caching, authentic CPU models (m68040, G4-7400)
- **User-Friendly**: Interactive menus with VM descriptions for easy selection

## Controls

- **Linux**: Right-Ctrl+G to release mouse
- **macOS**: Native Cocoa interface

## Technical Details

- **QEMU 10.x** with m68k and ppc support
- **Storage optimization**: Writeback caching (50-80% faster), AIO threading, zero detection
- **CPU models**: m68040 (Quadra 800), G4-7400 (PowerMac G4)
- **ROM**: 800.ROM auto-downloaded for 68k VMs on first run