# CLAUDE.md - m68k/images Directory

This directory contains disk images and system files for 68k Macintosh emulation. Each subdirectory represents a complete Mac OS environment with system disks, PRAM settings, and shared transfer volumes.

## Purpose and Architecture

The images directory provides persistent storage for 68k Mac systems, implementing a SCSI-based storage architecture that mirrors authentic Macintosh hardware. Each Mac OS version maintains separate disk images to prevent cross-contamination and enable parallel system maintenance.

## Entry Points

**Automatic Creation**: Images are automatically created by `runmac.sh` when referenced in configuration files but missing from the filesystem.

**Direct Access**: Images can be mounted on the host system for file transfer and maintenance using HFS/HFS+ tools.

**Configuration Integration**: Image paths are defined in configuration files and loaded automatically during emulation.

## Directory Structure

### Version-Specific Subdirectories

Each Mac OS version maintains its own image directory:

```
images/
├── 753/                           # Mac OS 7.5.3 images
│   ├── hdd_sys753.img            # System hard disk (2GB)
│   ├── pram_753_q800.img         # PRAM settings (512 bytes)
│   └── shared_753.img            # Shared transfer disk (200MB)
├── 761/                          # Mac OS 7.6.1 images
│   ├── hdd_sys761.img            # System hard disk (2GB)
│   ├── pram_761_q800.img         # PRAM settings (512 bytes)
│   └── shared_761.img            # Shared transfer disk (200MB)
└── 81/                           # Mac OS 8.1 images
    ├── hdd_sys761.img            # System hard disk (2GB)
    ├── pram_761_q800.img         # PRAM settings (512 bytes)
    └── shared_761.img            # Shared transfer disk (200MB)
```

## Image Types and Functions

### System Hard Disk Images (`hdd_sys*.img`)

**Purpose**: Primary bootable Mac OS storage containing system files, applications, and user data.

**Size**: 2GB (configurable in individual configurations)
**Format**: Raw disk image with HFS/HFS+ filesystem
**SCSI ID**: 6 (highest priority for boot)

**Contents**:
- Mac OS system software
- System folder with required extensions
- Control panels and system preferences
- User applications and documents
- Desktop folder and system databases

**Creation Process**:
1. Empty 2GB raw image created automatically if missing
2. User must install Mac OS from installation media
3. System setup and configuration performed within emulated Mac
4. Ongoing updates and software installation as needed

### PRAM Settings Images (`pram_*.img`)

**Purpose**: Parameter RAM storage containing system hardware settings and preferences.

**Size**: 512 bytes (fixed hardware requirement)
**Format**: Raw binary data
**Function**: Non-volatile settings storage

**Stored Settings**:
- Display resolution and color depth
- Startup disk selection
- Date/time settings
- System sound volume
- AppleTalk configuration
- Mouse and keyboard settings
- Memory and cache settings

**Management**:
- Automatically created with default values if missing
- Can be deleted to reset all system settings to defaults
- Settings persist between emulation sessions
- Critical for maintaining consistent system behavior

### Shared Transfer Disks (`shared_*.img`)

**Purpose**: File transfer medium between host system and emulated Mac.

**Size**: 200MB default (configurable)
**Format**: Raw disk image with HFS+ filesystem
**SCSI ID**: 5 (secondary priority)

**Usage Workflow**:
1. Mount on host system using HFS+ tools
2. Copy files to/from mounted filesystem
3. Unmount on host system
4. Files appear on Mac desktop when emulation starts
5. Transfer files in both directions as needed

**Host Mounting Example**:
```bash
# Mount shared disk on Linux
sudo mount -t hfsplus -o loop m68k/images/753/shared_753.img /mnt

# Copy files to Mac
cp files_for_mac/* /mnt/

# Unmount when finished
sudo umount /mnt
```

## How It Works

### SCSI Storage Architecture

68k Mac images implement authentic SCSI storage architecture:

**Device ID Priority**:
- **SCSI ID 7**: Host adapter (reserved)
- **SCSI ID 6**: Primary hard disk (OS boot disk)
- **SCSI ID 5**: Secondary hard disk (shared transfer)
- **SCSI ID 4**: Additional hard disk (if configured)
- **SCSI ID 3**: CD-ROM drive (installation/software)
- **SCSI ID 0-2**: Available for expansion

**Boot Process**:
1. QEMU presents SCSI devices to emulated Quadra 800
2. System ROM scans SCSI bus for bootable devices
3. Highest SCSI ID with valid system folder boots first
4. Mac OS loads and mounts all available SCSI volumes
5. Shared disk appears on desktop for file access

### Image File Management

**Automatic Creation Process**:
1. Configuration file specifies image paths
2. `runmac.sh` checks for image existence
3. Missing images are created as empty raw files
4. QEMU formats and initializes images during first boot
5. User completes OS installation and setup

**File Format Details**:
- **Raw Format**: Direct byte-for-byte disk representation
- **No Compression**: Fastest access, largest file size
- **Sparse Allocation**: Only used blocks consume host storage
- **HFS/HFS+ Compatible**: Native Mac filesystem support

### Cross-Version Isolation

Each Mac OS version maintains separate images:

**Benefits**:
- No interference between different OS versions
- Ability to run multiple configurations simultaneously
- Safe testing environment for system modifications
- Independent backup and restoration

**Considerations**:
- Storage space usage (multiple 2GB+ images)
- Manual file synchronization between versions
- Configuration-specific customizations required

## Image Maintenance

### Backup Procedures

**System Images**:
```bash
# Backup system disk
cp m68k/images/753/hdd_sys753.img ~/backups/hdd_sys753_$(date +%Y%m%d).img

# Backup PRAM settings
cp m68k/images/753/pram_753_q800.img ~/backups/pram_753_$(date +%Y%m%d).img
```

**Restoration**:
```bash
# Restore from backup
cp ~/backups/hdd_sys753_20240101.img m68k/images/753/hdd_sys753.img
```

### Disk Space Management

**Size Optimization**:
- Raw images only consume space for used blocks (sparse files)
- Compress rarely-used system images for storage savings
- Regular cleanup of temporary files within emulated systems

**Space Requirements**:
- System disk: ~500MB to 2GB (depending on installed software)
- PRAM file: 512 bytes (negligible)
- Shared disk: Variable based on file transfers

### Corruption Recovery

**PRAM Corruption**:
```bash
# Reset PRAM to defaults
rm m68k/images/753/pram_753_q800.img
# New PRAM created automatically on next boot
```

**Disk Image Corruption**:
```bash
# Check HFS filesystem (requires hfsprogs)
fsck.hfsplus m68k/images/753/hdd_sys753.img

# Mount and repair if possible
sudo mount -t hfsplus -o loop,rw m68k/images/753/hdd_sys753.img /mnt
# Perform repairs within mounted filesystem
sudo umount /mnt
```

## Performance Considerations

### Host System Requirements

**Storage Type**:
- **SSD**: Optimal performance for system images
- **HDD**: Acceptable but slower boot and application loading
- **Network Storage**: Not recommended for system images

**File System**:
- **ext4/APFS/NTFS**: Good performance with sparse file support
- **FAT32**: Not recommended (4GB file size limit)

### Cache Configuration Impact

Image performance directly relates to cache configuration:

**Writeback Cache**: 
- Fastest image access
- Requires clean shutdown to prevent corruption
- Risk of data loss on host crash

**Writethrough Cache**:
- Balanced performance and safety
- Slower than writeback but safer
- Good default for most users

**No Cache**:
- Slowest performance
- Maximum safety
- Recommended for critical data only

## Improvements That Could Be Made

### 1. Automated Backup System
**Current State**: Manual backup procedures
**Improvement**: Implement automatic snapshot system:
```bash
# Proposed backup automation
QEMU_AUTO_BACKUP="true"
QEMU_BACKUP_INTERVAL="daily"    # daily, weekly, monthly
QEMU_BACKUP_RETENTION="7"       # Keep 7 snapshots
QEMU_BACKUP_LOCATION="~/mac_backups"
```

### 2. Image Compression and Deduplication
**Current State**: Raw images consume full allocated space
**Improvement**: Implement smart compression:
```bash
# Proposed image optimization
- Automatic qcow2 conversion with compression
- Copy-on-write snapshots for version management  
- Deduplication across similar Mac OS versions
- On-demand expansion of image sizes
```

### 3. Cross-Platform File Transfer Enhancement
**Current State**: Manual mounting of shared disks with HFS+ tools
**Improvement**: Integrated file transfer system:
```bash
# Proposed transfer improvements
- Built-in HTTP file server for web-based transfers
- Automatic bidirectional sync with host directories
- Network folder mounting within emulated Mac
- Drag-and-drop file transfer interface
```

## Integration Points

### With Configuration System
- Image paths defined in configuration files
- Automatic image creation based on configuration requirements
- Size and performance parameters configurable per system

### With Performance System  
- Cache mode settings directly affect image performance
- AIO configuration optimizes image access patterns
- Memory allocation affects disk caching behavior

### With Backup and Recovery
- Image files can be backed up using standard host tools
- Snapshot functionality for testing and development
- Recovery procedures for various corruption scenarios

## Development Patterns

### Adding New Mac OS Versions
1. Create new subdirectory under `images/`
2. Update configuration file with new image paths
3. Create corresponding system disk and PRAM images
4. Install and configure Mac OS in new environment
5. Test functionality and document any special requirements

### Image Size Optimization
- Monitor actual usage vs allocated space
- Adjust default image sizes based on Mac OS requirements
- Implement compression for long-term storage
- Consider qcow2 format for advanced features

### Cross-System Compatibility
- Ensure HFS/HFS+ compatibility across host platforms
- Test mounting and file transfer on Linux, macOS, Windows
- Document platform-specific requirements and limitations
- Provide alternative methods for unsupported platforms