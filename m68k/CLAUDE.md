# CLAUDE.md - m68k Directory

This directory contains all resources for Motorola 68000 family Macintosh emulation using QEMU. The 68k architecture represents classic Mac systems from the 1984-1996 era, including Mac Plus, SE, Classic, LC, and Quadra models.

## Directory Structure

```
m68k/
├── 800.ROM                     # Quadra 800 ROM file (required, user-provided)
├── configs/                    # 68k emulation configurations
│   ├── m68k-macos753.conf     # Mac OS 7.5.3 configuration
│   ├── m68k-macos761.conf     # Mac OS 7.6.1 configuration  
│   └── m68k-macos81.conf      # Mac OS 8.1 configuration
└── images/                     # Disk images and PRAM files
    ├── 753/                   # Mac OS 7.5.3 images
    ├── 761/                   # Mac OS 7.6.1 images
    └── 81/                    # Mac OS 8.1 images
```

## ROM Requirements

**Critical**: 68k emulation requires a Quadra 800 ROM file (`800.ROM`) which must be obtained legally by the user. This file is **not included** in the repository and must be placed at `m68k/800.ROM`.

The ROM file provides the low-level firmware necessary for 68k Mac emulation, containing:
- System startup routines
- Hardware drivers
- Toolbox APIs
- Memory management

## Configuration Files

### m68k-macos753.conf
- **Purpose**: Mac OS 7.5.3 emulation with maximum performance
- **Target System**: Quadra 800 (68040 @ 33MHz)
- **RAM**: 128MB (optimal for Mac OS 7.5.3)
- **Performance**: Writeback cache, native AIO, multi-threading TCG
- **Use Case**: General purpose, gaming, development

### m68k-macos761.conf  
- **Purpose**: Mac OS 7.6.1 emulation with enhanced stability
- **Target System**: Quadra 800 (68040 @ 33MHz)
- **RAM**: 128MB
- **Improvements**: More stable than 7.5.3, better software compatibility
- **Use Case**: Production work requiring stability

### m68k-macos81.conf
- **Purpose**: Mac OS 8.1 emulation (final 68k Mac OS)
- **Target System**: Quadra 800 (68040 @ 33MHz) 
- **RAM**: 128MB
- **Features**: Modern Mac OS features with 68k compatibility
- **Use Case**: Latest 68k software, enhanced UI features

## Image Directory Structure

Each Mac OS version has its own subdirectory under `images/` containing:

### System Images (per version)
- `hdd_sys<version>.img` - Main system hard disk
- `pram_<version>_q800.img` - PRAM (Parameter RAM) settings storage
- `shared_<version>.img` - Shared disk for file transfer with host

### PRAM Files
PRAM files store system settings including:
- Display resolution and color depth
- Startup disk selection
- System sound settings
- Date/time configuration
- AppleTalk settings

## Architecture-Specific Features

### SCSI Storage System
68k Macs use SCSI for storage with fixed device ID assignments:
- **SCSI ID 6**: OS hard disk (highest priority for boot)
- **SCSI ID 5**: Shared disk for file transfer
- **SCSI ID 4**: Additional hard disk (if specified)
- **SCSI ID 3**: CD-ROM drive (or ID 6 for installation boot)

### Hardware Emulation
- **Machine Type**: q800 (Quadra 800 - only QEMU-supported 68k Mac)
- **CPU**: Motorola 68040 @ 33MHz (configurable to 68030/68020)
- **RAM**: Up to 256MB (128MB recommended)
- **Graphics**: NuBus-based video with Mac-standard resolutions
- **Audio**: Apple Sound Chip (ASC) with enhanced mode support
- **Network**: DP83932 Ethernet controller

### Performance Optimizations
68k configurations support extensive performance tuning:

**CPU Optimizations**:
- Multi-threaded TCG translation (faster but generates warnings)
- Translation block cache sizing (32MB to 512MB)
- CPU model selection (68020/68030/68040)

**Storage Optimizations**:
- Cache modes: writeback (fastest) to none (safest)
- AIO modes: native (Linux) vs threads (cross-platform)
- SCSI vendor/serial customization

**Memory Optimizations**:
- RAM backend selection (standard vs file-backed)
- Memory size optimization per Mac OS version

## Usage Patterns

### Basic Emulation
```bash
# Launch Mac OS 7.5.3
./runmac.sh -C m68k/configs/m68k-macos753.conf

# Launch with CD-ROM
./runmac.sh -C m68k/configs/m68k-macos753.conf -c /path/to/cd.iso

# Installation mode (boot from CD)
./runmac.sh -C m68k/configs/m68k-macos753.conf -c install.iso -b
```

### File Transfer
The shared disk images provide file transfer between host and emulated Mac:
```bash
# Mount shared disk on Linux host (requires hfsprogs)
sudo mount -t hfsplus -o loop m68k/images/753/shared_753.img /mnt

# Copy files to shared disk
cp files/* /mnt/

# Unmount
sudo umount /mnt
```

### Performance Tuning
Configuration files support extensive customization:
- Change cache modes for performance vs safety trade-offs
- Adjust RAM sizes based on software requirements
- Select CPU models for compatibility vs performance
- Tune audio latency for multimedia applications

## Common Issues and Solutions

### ROM File Missing
Error: "ROM file not found"
- Obtain legal Quadra 800 ROM file
- Place at `m68k/800.ROM`
- Verify file permissions are readable

### PRAM Corruption
If system settings are lost between boots:
- Delete PRAM file to reset to defaults
- System will recreate PRAM on next boot
- Reconfigure display and system settings

### Performance Issues
For slow emulation:
- Verify SSD storage for host system
- Enable writeback cache mode (with regular saves)
- Use native AIO on Linux systems
- Increase translation block cache size

### Boot Order Problems
If system won't boot from correct disk:
- Check SCSI ID assignments in configuration
- Use `-b` flag for CD installation mode
- Verify disk image integrity

## Development Notes

### Adding New Configurations
1. Copy existing `.conf` file as template
2. Modify `CONFIG_NAME` and image paths
3. Adjust performance settings as needed
4. Create corresponding image directory
5. Test boot and functionality

### Image Management
- System images auto-created if missing (empty)
- PRAM files auto-created with defaults
- Shared disks created at specified size
- Use raw format for maximum compatibility

### Integration Points
68k configurations integrate with:
- Main `runmac.sh` runner (architecture auto-detection)
- Software library system (automatic software launches)
- Dependency installer (ROM and tool validation)
- Network system (user-mode networking setup)