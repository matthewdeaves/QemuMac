# QemuMac - Classic Macintosh Emulation

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
- Install QEMU either locally (in `qemu-install/`) or globally
- Verify the installation works correctly

The script supports both local installation (recommended) and global system-wide installation.

## Quick Start

### 1. Launch a VM

For the most user-friendly experience, run the script without any arguments to open an interactive menu:

```bash
./run-mac.sh
```

This will guide you through selecting a VM, attaching an ISO, and choosing boot options.

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
A 512MB shared disk (HFS format) accessible by all VMs for easy file transfer between host and guests.

### 4. Create New VM
```bash
./run-mac.sh --create-config my_mac
```
During VM creation, you can optionally select a default installer that will be automatically downloaded and configured on first run.

## Usage Examples

### Installing Mac OS (typical workflow)

**Option 1: With Default Installer (Recommended)**
```bash
# 1. Create VM and select a default installer during setup
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

# 2. Boot from install disc, format hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf --iso iso/MacOS922.iso --boot-from-cd

# 3. After installation, boot normally from hard drive
./run-mac.sh --config vms/quadra_fresh/quadra_fresh.conf
```

### File Transfer Between Host and VM
```bash
# 1. Start VM and format shared disk as Mac OS Standard (HFS) if needed
./run-mac.sh --config vms/quadra800/quadra800.conf

# 2. Mount shared disk on host (requires hfsprogs)
./mount-shared.sh

# 3. Copy files to shared mount point on host (default: /tmp/qemu-shared)
cp ~/myfiles/* /tmp/qemu-shared/

# 4. Unmount when done
./mount-shared.sh -u
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
- `shared/` - Shared disk accessible by all VMs (auto-created)

## Architectures

- **68k (Quadra 800)**: 128M RAM, 2G disk, requires ROM file
- **PPC (PowerMac G4)**: 512M RAM, 10G disk, no ROM needed

## Performance Optimizations

QemuMac includes built-in performance optimizations for the best possible emulation experience:

### Storage I/O Optimization
- **Writeback caching**: 50-80% faster disk operations
- **Compatible AIO backend**: Universal threading support
- **Zero detection**: Space-efficient storage

### CPU Accuracy
- **Authentic CPU models**: m68040 for Quadra 800, PowerMac G4-7400 for PPC
- **Proper instruction timing**: Improved compatibility and performance
- **Architecture-specific optimizations**: Tailored for each Mac model

### Automatic Detection
- Performance optimizations are applied automatically
- Compatible with all QEMU versions and host platforms
- No configuration required - works out of the box

## Controls

- **Linux**: Right-Ctrl+G to release mouse
- **macOS**: Native Cocoa interface