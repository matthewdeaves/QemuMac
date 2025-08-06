# CLAUDE.md - ppc/images Directory

This directory contains disk images for PowerPC Macintosh emulation, supporting the transition from classic Mac OS to Mac OS X. Each subdirectory maintains a complete operating system environment with enhanced storage capabilities for modern Mac OS requirements.

## Purpose and Architecture

PowerPC images implement IDE-based storage architecture supporting both classic Mac OS 9.x and Mac OS X systems. The simplified storage model compared to 68k SCSI enables easier management while supporting the higher capacity requirements of Mac OS X.

## Entry Points

**Automatic Creation**: Images are created automatically by `runmac.sh` when referenced in configurations but missing.

**Host Integration**: Images can be mounted using HFS+ tools for file transfer and system maintenance.

**OpenFirmware Integration**: Boot management handled by OpenFirmware without requiring PRAM files.

## Directory Structure

### Operating System Environments

Each supported OS maintains its own image environment:

```
images/
├── 9/                             # Mac OS 9.1 environment
│   ├── MacOS9.img                # System disk (8GB default)
│   └── shared_9.img              # Shared transfer disk (500MB)
├── tiger104/                     # Mac OS X 10.4 Tiger environment  
│   ├── MacOSX10.4.img           # System disk (20GB default)
│   └── shared_tiger104.img      # Shared transfer disk (1GB)
└── leopard105/                   # Mac OS X 10.5 Leopard environment
    ├── MacOSX10.5.img           # System disk (25GB default)
    └── shared_leopard105.img    # Shared transfer disk (1GB)
```

## Image Types and Specifications

### Mac OS 9.1 System (`MacOS9.img`)

**Purpose**: Classic Mac OS 9.1 complete system environment
**Size**: 8GB default (configurable)
**Format**: Raw disk image with HFS filesystem
**IDE Position**: Primary Master

**Characteristics**:
- Fast boot times and excellent responsiveness
- Excellent classic Mac software compatibility
- Moderate disk space requirements
- Single-user classic Mac OS environment

**Typical Contents**:
- Mac OS 9.1 system software
- Classic Mac applications (Photoshop, Office, games)
- System extensions and control panels
- Desktop database and user preferences

### Mac OS X Tiger System (`MacOSX10.4.img`)

**Purpose**: Mac OS X 10.4 Tiger complete system environment
**Size**: 20GB default (recommended minimum)
**Format**: Raw disk image with HFS+ filesystem  
**IDE Position**: Primary Master

**Characteristics**:
- Multi-user Unix-based operating system
- Aqua graphical interface
- Modern application framework support
- Spotlight search and system services

**Typical Contents**:
- Mac OS X 10.4 Tiger system installation
- Bundled applications (Safari, Mail, iChat, etc.)
- Developer tools (optional Xcode installation)
- User accounts and system preferences
- Unix tools and command-line environment

### Mac OS X Leopard System (`MacOSX10.5.img`)

**Purpose**: Mac OS X 10.5 Leopard final PowerPC Mac OS X
**Size**: 25GB default (minimum recommended)
**Format**: Raw disk image with HFS+ filesystem
**IDE Position**: Primary Master

**Characteristics**:
- Final PowerPC Mac OS X release
- Advanced features: Time Machine, Stacks, enhanced Spotlight
- Higher resource requirements than Tiger
- Full 64-bit application support

**Typical Contents**:
- Mac OS X 10.5 Leopard system installation
- Enhanced bundled applications
- Improved developer tools
- Advanced system services and frameworks
- Backwards compatibility for PowerPC applications

### Shared Transfer Disks

**Purpose**: Bidirectional file transfer between host and emulated system
**Sizes**: 500MB (Mac OS 9), 1GB (Mac OS X)
**Format**: Raw disk image with HFS+ filesystem
**IDE Position**: Primary Slave

**Usage Characteristics**:
- Automatic mounting on Mac desktop
- Cross-platform file compatibility
- Host system access via HFS+ mounting
- Persistent storage across emulation sessions

**Host Access Example**:
```bash
# Mount Mac OS X shared disk
sudo mount -t hfsplus -o loop ppc/images/tiger104/shared_tiger104.img /mnt

# Transfer files to Mac
cp documents/* /mnt/

# Unmount cleanly
sudo umount /mnt
```

## How It Works

### IDE Storage Architecture

PowerPC images implement simplified IDE storage compared to 68k SCSI:

**Device Assignment**:
- **Primary Master**: System hard disk (main OS)
- **Primary Slave**: Shared transfer disk
- **Secondary Master**: CD-ROM drive (installation/software)
- **Secondary Slave**: Available for expansion

**Boot Process**:
1. OpenFirmware initializes IDE controllers
2. Scans for bootable devices on IDE buses
3. Boots from device specified by boot parameter
4. Mac OS mounts all available IDE volumes
5. Shared disk appears automatically on desktop

### OpenFirmware Integration

**No PRAM Files Required**: OpenFirmware manages system settings internally
**Boot Management**: Simple `-boot c` (HDD) or `-boot d` (CD) parameters
**Hardware Detection**: Automatic IDE device enumeration
**Settings Persistence**: OpenFirmware NVRAM maintains configuration

### File System Evolution

**Mac OS 9**: Traditional HFS filesystem with classic Mac file attributes
**Mac OS X**: HFS+ filesystem with Unix permissions and extended attributes
**Cross-Compatibility**: HFS+ readable by both Mac OS 9 and Mac OS X

## Performance and Sizing

### Storage Requirements by OS

**Mac OS 9.1**:
- **Base Installation**: ~400MB
- **With Applications**: 1-2GB typical
- **Full Environment**: 4-8GB recommended
- **Performance**: Excellent on any modern storage

**Mac OS X 10.4 Tiger**:
- **Base Installation**: ~3GB
- **With Applications**: 6-10GB typical
- **Development Environment**: 15-20GB recommended
- **Performance**: Good with SSD storage

**Mac OS X 10.5 Leopard**:
- **Base Installation**: ~4GB
- **With Applications**: 8-15GB typical  
- **Full Environment**: 20-25GB recommended
- **Performance**: Requires SSD for acceptable performance

### Host System Requirements

**For Mac OS 9**: 
- Any modern storage acceptable
- 1GB+ host RAM recommended
- Standard HDD sufficient

**For Mac OS X**:
- SSD strongly recommended
- 4GB+ host RAM essential  
- Fast CPU for acceptable performance

## Image Management

### Creation and Initialization

**Automatic Creation Process**:
1. Configuration specifies image path and size
2. `runmac.sh` detects missing image files
3. Creates empty raw image files at specified sizes
4. QEMU initializes images during first boot
5. User installs operating system from installation media

**Manual Creation**:
```bash
# Create 20GB Tiger system disk
dd if=/dev/zero of=ppc/images/tiger104/MacOSX10.4.img bs=1M count=20480

# Create 1GB shared disk
dd if=/dev/zero of=ppc/images/tiger104/shared_tiger104.img bs=1M count=1024
```

### Backup and Recovery

**System Backup Strategy**:
```bash
# Backup Mac OS X system before major changes
cp ppc/images/tiger104/MacOSX10.4.img ~/backups/MacOSX10.4_$(date +%Y%m%d).img

# Create compressed backup
gzip -c ppc/images/tiger104/MacOSX10.4.img > ~/backups/MacOSX10.4_$(date +%Y%m%d).img.gz
```

**Recovery Procedures**:
```bash
# Restore from backup
cp ~/backups/MacOSX10.4_20240101.img ppc/images/tiger104/MacOSX10.4.img

# Restore from compressed backup
gunzip -c ~/backups/MacOSX10.4_20240101.img.gz > ppc/images/tiger104/MacOSX10.4.img
```

### Filesystem Maintenance

**HFS+ Filesystem Checking**:
```bash
# Check Tiger system disk
fsck.hfsplus ppc/images/tiger104/MacOSX10.4.img

# Check and repair if needed
fsck.hfsplus -f ppc/images/tiger104/MacOSX10.4.img
```

**Defragmentation** (rarely needed with modern filesystems):
- HFS+ handles fragmentation well internally
- Regular backup/restore cycle provides defragmentation
- Focus on host storage optimization instead

## Cross-Platform Compatibility

### Host Platform Support

**Linux**:
- Native HFS+ support with hfsprogs
- Excellent mount/unmount capabilities
- Full read/write access to shared disks

**macOS**:
- Native HFS+ support built-in
- Seamless mounting and access
- Best compatibility for Mac-created files

**Windows**:
- Third-party HFS+ tools required (MacDrive, Paragon)
- Limited native support
- Alternative: Use network transfer methods

### File Transfer Alternatives

**Network-Based Transfer**:
- Built-in FTP/SSH servers in Mac OS X
- Web-based file transfer utilities
- Shared folders via SMB/AFP

**Archive-Based Transfer**:
- Create ZIP/StuffIt archives within Mac
- Transfer archives via CD-ROM images
- Extract on target system

## Performance Optimization

### Host Storage Optimization

**SSD Recommendations**:
- Place Mac OS X images on fastest available storage
- Mac OS 9 less sensitive to storage performance
- Consider NVMe SSD for best Mac OS X experience

**Cache Configuration Impact**:
- **Writeback**: Maximum performance, requires clean shutdown
- **Writethrough**: Balanced performance and safety
- **None**: Safest but slowest, use for critical data

### Memory and CPU Considerations

**Memory Mapping**:
- Large images benefit from sufficient host RAM
- Avoid host swapping during Mac OS X emulation
- Monitor host memory usage during intensive operations

**CPU Optimization**:
- Single-threaded emulation requires fast CPU cores
- CPU frequency scaling can impact performance
- Background host processes reduce available CPU

## Improvements That Could Be Made

### 1. Advanced Image Formats
**Current State**: Raw disk images with fixed allocation
**Improvement**: Implement advanced image formats:
```bash
# Proposed image format enhancements
QEMU_IMAGE_FORMAT="qcow2"           # Copy-on-write with compression
QEMU_IMAGE_COMPRESSION="zstd"       # Fast compression algorithm
QEMU_SNAPSHOT_SUPPORT="true"        # Built-in snapshot management
QEMU_RESIZE_SUPPORT="true"          # Dynamic image resizing
```

### 2. Integrated File Transfer System  
**Current State**: Manual mounting of shared disks
**Improvement**: Seamless file transfer integration:
```bash
# Proposed transfer system
QEMU_HOST_SHARE="/home/user/mac_files"  # Automatic host folder sharing
QEMU_TRANSFER_METHOD="9p"               # 9P filesystem sharing
QEMU_AUTO_MOUNT="true"                  # Automatic mounting in guest
QEMU_BIDIRECTIONAL_SYNC="true"         # Two-way sync capability
```

### 3. Performance-Aware Storage Management
**Current State**: Fixed image sizes and performance settings
**Improvement**: Adaptive storage optimization:
```bash
# Proposed performance optimization  
QEMU_STORAGE_TIER="ssd"             # Storage type detection
QEMU_AUTO_CACHE="true"              # Automatic cache mode selection
QEMU_PREFETCH="true"                # Predictive data loading
QEMU_COMPRESSION_LEVEL="balanced"   # Performance vs space trade-off
```

## Integration Points

### With Configuration System
- Image paths and sizes defined in configuration files
- Automatic image creation based on configuration requirements
- Performance parameters directly affect image access patterns

### With Boot Management
- OpenFirmware boot parameter integration
- Installation mode support for OS deployment
- Boot device priority management

### With Performance System
- Cache mode settings impact image performance
- Memory allocation affects disk caching
- Host storage type detection for optimization

## Development Patterns

### Adding New Mac OS Versions
1. Research disk space and performance requirements
2. Create appropriate image size defaults
3. Test installation and boot processes
4. Document performance characteristics
5. Update configuration templates accordingly

### Storage Optimization Strategies
- Profile actual disk usage vs allocated space
- Implement compression for long-term storage
- Consider thin provisioning for development environments
- Balance performance vs storage efficiency

### Cross-System Migration
- Develop tools for migrating between Mac OS versions
- Create upgrade paths from Mac OS 9 to Mac OS X
- Maintain backward compatibility for classic applications
- Document migration procedures and limitations