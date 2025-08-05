# QemuMac - Classic Macintosh Emulation

A comprehensive dual-architecture emulation system for classic Macintosh computers using QEMU. Supports both Motorola 68k (Mac OS 7.x-8.x) and PowerPC (Mac OS 9.x and Mac OS X) systems with an integrated software library for easy access to classic Mac software.

**Tested Platform**: Ubuntu Linux (primary development and testing platform)

## Quick Start

### 1. Install Dependencies
```bash
# Install all required packages automatically
./install-dependencies.sh

# Or just check what's needed
./install-dependencies.sh --check
```

### 2. Get ROM File (68k Only)
For 68k emulation, you need a Quadra 800 ROM file:
```bash
# Option 1: Use the mac-library to download it automatically
./mac-library.sh
# Navigate to "ROMs" section and download Quadra 800 ROM

# Option 2: Place your legally obtained ROM file manually:
cp your_800.ROM m68k/800.ROM
```
**Note**: PowerPC emulation doesn't require ROM files.

### 3. Quick Test
```bash
# Test 68k Mac OS 7.5.3 (if you have ROM file)
./runmac.sh -C m68k/configs/m68k-macos753.conf

# Test PowerPC Mac OS 9.1 (no ROM needed)
./runmac.sh -C ppc/configs/ppc-macos91.conf
```

## Complete Setup Guide

### Installing an Operating System

For brand new VMs, you need to install an OS first. The mac-library system provides several OS installation images that can be downloaded automatically:

#### Using the Mac Library for OS Installation
```bash
# Browse available operating systems
./mac-library.sh
# Navigate to "Operating Systems" to see available OS installers

# Or list OS installers from command line
./mac-library.sh list | grep "Operating Systems"
```

**Available OS Installers in Library:**
- Mac OS X Tiger 10.4 (PowerPC)
- Mac OS X Leopard 10.5.6 (PowerPC) 
- Mac OS 9.2 for G4 Power Mac (PowerPC)
- Apple Legacy Recovery CD (68k/PowerPC)

#### Mac OS X Tiger Installation Example
```bash
# 1. Download Tiger installer using mac-library
./mac-library.sh download macos_x_tiger

# 2. Boot from Tiger installation CD
./runmac.sh -C ppc/configs/ppc-osxtiger104.conf -c library/downloads/MacOSX.4.iso -b

# 3. Installation process:
#    - Boot from CD
#    - Use Disk Utility to format the drive as Mac OS Extended (HFS+)
#    - Install Mac OS X
#    - Complete setup assistant
#    - Shutdown when complete

# 4. Boot normally from installed system
./runmac.sh -C ppc/configs/ppc-osxtiger104.conf
```

#### Mac OS X Leopard Installation Example
```bash
# 1. Download Leopard installer using mac-library
./mac-library.sh download macos_x_leopard

# 2. Boot from Leopard installation DVD
./runmac.sh -C ppc/configs/ppc-osxleopard105.conf -c "library/downloads/MacOSXLeopard10.5.iso" -b

# 3. Installation process:
#    - Boot from DVD
#    - Use Disk Utility to format drive as Mac OS Extended (HFS+)
#    - Install Mac OS X 
#    - Complete setup assistant

# 4. Boot normally from installed system
./runmac.sh -C ppc/configs/ppc-osxleopard105.conf
```

#### Mac OS 9.2 Installation Example
```bash
# 1. Download Mac OS 9.2 installer using mac-library
./mac-library.sh download macos922

# 2. Boot from Mac OS 9.2 installation CD
./runmac.sh -C ppc/configs/ppc-macos91.conf -c "library/downloads/Power Mac G4 Install 9.2.toast" -b

# 3. In the Mac OS installer:
#    - Initialize drives with Drive Setup
#    - Install Mac OS to the main drive
#    - Restart when installation completes

# 4. Boot from installed system
./runmac.sh -C ppc/configs/ppc-macos91.conf
```

#### 68k Mac OS Installation (User-Provided Media)
```bash
# For 68k systems, provide your own Mac OS 7.x installation media
# 1. Place your Mac OS 7.5.3 install CD at: /path/to/macos753_install.iso

# 2. Boot from installation CD
./runmac.sh -C m68k/configs/m68k-macos753.conf -c /path/to/macos753_install.iso -b

# 3. In the Mac OS installer:
#    - Initialize the hard disk with Disk First Aid
#    - Format as HFS (Mac OS Standard)
#    - Install Mac OS to the hard disk
#    - Shut down the VM when installation completes

# 4. Boot normally from installed system
./runmac.sh -C m68k/configs/m68k-macos753.conf
```

## Using the Software Library

The integrated software library provides easy access to classic Mac software:

### Interactive Mode
```bash
# Launch the colorful interactive menu
./mac-library.sh
```

The interactive menu provides:
- Browse software by category (Games, Operating Systems, etc.)
- Automatic downloads with progress bars
- One-click launch with appropriate configurations
- Download management and cleanup

### Command Line Mode
```bash
# List all available software
./mac-library.sh list

# Download specific software
./mac-library.sh download marathon

# Launch software with specific configuration
./mac-library.sh launch marathon m68k/configs/m68k-macos753.conf
```

### Available Software Categories
- **Games**: Marathon Trilogy, Myst, LucasArts Game Pack, SimCity
- **Operating Systems**: Mac OS install CDs, Mac OS X installers
- **System Tools**: Apple Legacy Recovery CD
- **ROMs**: Quadra 800 ROM (required for 68k emulation)

## File Transfer Between Host and Mac

### Using Shared Disks

Each configuration includes a shared disk for file transfer:

```bash
# Mount the shared disk on Ubuntu host
sudo mount -t hfsplus -o loop m68k/images/753/shared_753.img /mnt

# Copy files to shared disk
cp ~/Documents/myfile.txt /mnt/

# Unmount
sudo umount /mnt

# Files will appear on the Mac desktop as "shared_753" drive
```

### Using the Disk Mounter Script
```bash
# Mount shared disk from configuration
./scripts/mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf

# Check filesystem type
./scripts/mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf -c

# Unmount
./scripts/mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf -u

# Repair filesystem if needed
./scripts/mac_disc_mounter.sh -C m68k/configs/m68k-macos753.conf -r
```

## Available Configurations

### 68k Systems (Motorola 68000)
- `m68k/configs/m68k-macos753.conf` - Mac OS 7.5.3 (128MB RAM)
- `m68k/configs/m68k-macos761.conf` - Mac OS 7.6.1 (128MB RAM)  
- `m68k/configs/m68k-macos81.conf` - Mac OS 8.1 (128MB RAM)

**Requirements**: Quadra 800 ROM file at `m68k/800.ROM`

### PowerPC Systems
- `ppc/configs/ppc-macos91.conf` - Mac OS 9.1 (512MB RAM)
- `ppc/configs/ppc-osxtiger104.conf` - Mac OS X 10.4 Tiger (2GB RAM)
- `ppc/configs/ppc-osxleopard105.conf` - Mac OS X 10.5 Leopard (2GB RAM)

**Requirements**: No ROM files needed

## Command Reference

### Main Emulation Runner
```bash
./runmac.sh -C <config_file> [options]

Options:
  -C FILE  Configuration file (required)
  -c FILE  CD-ROM image file
  -a FILE  Additional hard drive image  
  -b       Boot from CD-ROM (for installation)
  -d TYPE  Display type (sdl, gtk, cocoa)
  -D       Debug mode
  -?       Show help
```

### Examples
```bash
# Run Mac OS 7.5.3
./runmac.sh -C m68k/configs/m68k-macos753.conf

# Run with CD-ROM
./runmac.sh -C m68k/configs/m68k-macos753.conf -c game.iso

# Install from CD (boot from CD)
./runmac.sh -C ppc/configs/ppc-macos91.conf -c install.iso -b

# Run with additional storage
./runmac.sh -C m68k/configs/m68k-macos753.conf -a extra_drive.img

# Force SDL display
./runmac.sh -C m68k/configs/m68k-macos753.conf -d sdl
```

## Performance Tips

### For Better Performance
- Use SSD storage on the host system
- Allocate sufficient RAM to the host (4GB+ recommended for Mac OS X)
- Close unnecessary host applications
- Use writeback cache mode (enabled by default in performance configs)

### For Maximum Stability  
- Use writethrough cache mode (edit config files)
- Use single-threaded TCG (edit `QEMU_TCG_THREAD_MODE="single"`)
- Save your work frequently

## Troubleshooting

### Common Issues

**PowerPC Mac OS 9 installation media won't boot (Known Issue)**
```bash
# Currently experiencing issues with booting Mac OS 9 installation media on PowerPC
# This is being actively worked on - Mac OS X (Tiger/Leopard) installation works fine
# Workaround: Use pre-installed Mac OS 9 disk images if available
```

**No sound on PowerPC systems (Known Issue)**
```bash
# Audio is currently not working on PowerPC emulation
# This is being actively worked on - 68k audio works fine
# The configurations include audio settings but they need further tuning
```

**"ROM file not found" (68k only)**
```bash
# Option 1: Use mac-library to download automatically
./mac-library.sh
# Navigate to ROMs section and download Quadra 800 ROM

# Option 2: Place ROM file manually
cp your_quadra_800.rom m68k/800.ROM
```

**"Command not found: qemu-system-m68k"**
```bash
# Install dependencies
./install-dependencies.sh
```

**VM won't boot from hard disk**
```bash
# For new VMs, you need to install an OS first:
./runmac.sh -C config.conf -c install_cd.iso -b
# Then boot normally after installation
```

**Shared disk won't mount**
```bash
# Install HFS+ tools
sudo apt install hfsprogs

# Check filesystem
./scripts/mac_disc_mounter.sh -C config.conf -c
```

**Mac OS X is very slow**
```bash
# Ensure you have enough host RAM (4GB+)
# Use Tiger (10.4) instead of Leopard (10.5) for better performance
# Verify SSD storage on host
```

### Getting Help
- Check the CLAUDE.md files in each directory for detailed documentation
- Use debug mode: `./runmac.sh -C config.conf -D`
- Verify dependencies: `./install-dependencies.sh --check`

## Project Structure

```
QemuMac/
├── runmac.sh                   # Main emulation runner
├── install-dependencies.sh    # Dependency installer  
├── mac-library.sh             # Software library manager
├── library/                   # Software database and downloads
├── m68k/                      # 68k configs and disk images
├── ppc/                       # PowerPC configs and disk images  
└── scripts/                   # Utility scripts
```
