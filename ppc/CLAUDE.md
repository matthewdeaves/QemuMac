# CLAUDE.md - ppc Directory

This directory contains all resources for PowerPC Macintosh emulation using QEMU. The PowerPC architecture represents the transition era of Mac systems from 1994-2006, including Power Mac G3, G4, and G5 models running Mac OS 8.5-9.x and Mac OS X.

## Directory Structure

```
ppc/
├── configs/                        # PowerPC emulation configurations
│   ├── ppc-macos91.conf           # Mac OS 9.1 configuration
│   ├── ppc-osxtiger104.conf       # Mac OS X 10.4 Tiger configuration
│   └── ppc-osxleopard105.conf     # Mac OS X 10.5 Leopard configuration
└── images/                         # Disk images for each OS version
    ├── 9/                         # Mac OS 9.1 images
    │   ├── MacOS9.img            # System disk
    │   └── shared_9.img          # Shared transfer disk
    ├── tiger104/                  # Mac OS X 10.4 Tiger images
    │   ├── MacOSX10.4.img        # System disk
    │   └── shared_tiger104.img   # Shared transfer disk
    └── leopard105/                # Mac OS X 10.5 Leopard images
        ├── MacOSX10.5.img        # System disk
        └── shared_leopard105.img # Shared transfer disk
```

## ROM Requirements

**Advantage**: PowerPC emulation does **not** require external ROM files. QEMU includes the necessary OpenFirmware implementation for PowerPC Mac emulation, making setup simpler than 68k systems.

## Configuration Files

### ppc-macos91.conf
- **Purpose**: Mac OS 9.1 emulation (final major Mac OS 9 release)
- **Target System**: Power Mac G3/G4 (mac99 machine)
- **CPU**: PowerPC G4 (optimal for Mac OS 9)
- **RAM**: 512MB (optimal for Mac OS 9.1)
- **Use Case**: Classic Mac OS experience, legacy software compatibility

### ppc-osxtiger104.conf
- **Purpose**: Mac OS X 10.4 Tiger emulation
- **Target System**: Power Mac G3/G4 (mac99 machine)
- **CPU**: PowerPC G4 (required for Tiger)
- **RAM**: 2GB (optimal for Mac OS X Tiger performance)
- **Use Case**: Early Mac OS X development, Tiger-specific software

### ppc-osxleopard105.conf
- **Purpose**: Mac OS X 10.5 Leopard emulation (final PowerPC Mac OS X)
- **Target System**: Power Mac G3/G4 (mac99 machine)
- **CPU**: PowerPC G4 (minimum requirement for Leopard)
- **RAM**: 2GB (minimum for acceptable Leopard performance)
- **Use Case**: Latest PowerPC Mac OS X features, final PowerPC compatibility

## Architecture-Specific Features

### IDE Storage System
PowerPC Macs use IDE for storage with simple boot order management:
- **Primary Master**: Main system hard disk
- **Primary Slave**: Shared disk for file transfer
- **Secondary Master**: CD-ROM drive (when present)
- **Additional Drives**: Added sequentially as available

### Hardware Emulation
- **Machine Type**: mac99 (Power Mac G3/G4 with PMU support)
- **CPU**: PowerPC G3/G4 (G4 recommended for Mac OS X)
- **RAM**: Up to 2GB (1GB+ recommended for Mac OS X)
- **Graphics**: ATI VGA with EDID support for resolution detection
- **Audio**: ES1370 sound card (excellent Mac OS compatibility)
- **Network**: Sun GEM Ethernet controller (authentic PowerPC Mac networking)

### Boot Management
PowerPC systems use OpenFirmware boot management:
- **Normal Boot**: `-boot c` (boot from hard disk)
- **CD Boot**: `-boot d` (boot from CD-ROM for installation)
- **Boot Order**: Automatically handled by OpenFirmware
- **No PRAM**: OpenFirmware manages settings internally

### Performance Optimizations
PowerPC configurations support extensive performance tuning:

**CPU Optimizations**:
- G4 vs G3 processor selection (G4 required for Mac OS X 10.4+)
- Single-core limitation (mac99 machine constraint)
- TCG threading: single-threaded recommended (PowerPC MTTCG instability)

**Storage Optimizations**:
- IDE cache modes: writeback (fastest) to none (safest)
- AIO modes: native (Linux) vs threads (cross-platform)
- Drive performance tuning for Mac OS X

**Memory Optimizations**:
- High RAM requirements for Mac OS X (1GB minimum, 2GB optimal)
- Memory backend selection for debugging
- RAM sizing per OS version requirements

## Operating System Support

### Mac OS 9.1
- **Architecture**: PowerPC G3/G4
- **RAM Requirements**: 256MB minimum, 512MB optimal
- **Features**: Final classic Mac OS, excellent software compatibility
- **Performance**: Fast emulation, mature Mac OS 9 support
- **Use Cases**: Legacy software, classic Mac experience

### Mac OS X 10.4 Tiger
- **Architecture**: PowerPC G4 required
- **RAM Requirements**: 1GB minimum, 2GB optimal
- **Features**: Spotlight, Dashboard, Automator
- **Performance**: Good emulation performance
- **Use Cases**: Early Mac OS X development, Tiger-specific features

### Mac OS X 10.5 Leopard  
- **Architecture**: PowerPC G4+ required
- **RAM Requirements**: 1GB absolute minimum, 2GB+ strongly recommended
- **Features**: Time Machine, Stacks, final PowerPC Mac OS X
- **Performance**: Slower emulation (resource intensive)
- **Use Cases**: Final PowerPC compatibility testing, Leopard-specific features

## Usage Patterns

### Basic Emulation
```bash
# Launch Mac OS 9.1
./runmac.sh -C ppc/configs/ppc-macos91.conf

# Launch Mac OS X Tiger
./runmac.sh -C ppc/configs/ppc-osxtiger104.conf

# Launch with CD-ROM for installation
./runmac.sh -C ppc/configs/ppc-osxtiger104.conf -c tiger_install.iso -b
```

### File Transfer
PowerPC shared disks provide file transfer capabilities:
```bash
# Mount shared disk on Linux host (requires hfsprogs)
sudo mount -t hfsplus -o loop ppc/images/9/shared_9.img /mnt

# Copy files to shared disk
cp files/* /mnt/

# Unmount
sudo umount /mnt
```

### Performance Tuning
Configuration files support extensive customization:
- Adjust RAM based on OS requirements (512MB for OS 9, 2GB for OS X)
- Select appropriate CPU models (G4 required for Mac OS X 10.4+)
- Tune storage cache modes for performance vs safety
- Configure audio backend for multimedia applications

## Common Issues and Solutions

### Mac OS X Performance
Mac OS X emulation is resource intensive:
- **Solution**: Allocate maximum RAM (2GB+)
- **Solution**: Use SSD storage on host system
- **Solution**: Enable writeback cache for storage performance
- **Solution**: Close unnecessary host applications

### Boot Problems
If system won't boot properly:
- Verify sufficient RAM allocation for OS version
- Check CPU model compatibility (G4 for Mac OS X 10.4+)
- Use installation mode (`-b`) when booting from CD
- Verify disk image integrity

### Audio Issues
For audio problems in Mac OS X:
- Ensure ES1370 sound device is configured
- Check audio backend compatibility (pa/coreaudio/alsa)
- Adjust audio latency settings
- Verify host audio system functionality

### Network Connectivity
For networking issues:
- Sun GEM network device provides best compatibility
- User-mode networking enabled by default
- No additional host network configuration required
- Check guest OS network settings

## Development Notes

### Adding New Configurations
1. Copy existing `.conf` file as template
2. Modify `CONFIG_NAME` and image paths
3. Adjust RAM and CPU for target OS requirements
4. Create corresponding image directory structure
5. Test boot sequence and functionality

### OS Version Compatibility
- **Mac OS 9.x**: G3/G4 compatible, 512MB RAM optimal
- **Mac OS X 10.0-10.3**: G3/G4 compatible, 1GB RAM recommended
- **Mac OS X 10.4**: G4 minimum, 2GB RAM optimal
- **Mac OS X 10.5**: G4+ minimum, 2GB RAM essential

### Image Management
- System images auto-created if missing (empty)
- No PRAM files needed (OpenFirmware manages settings)
- Shared disks created at specified sizes
- HFS+ format recommended for cross-compatibility

### Integration Points
PowerPC configurations integrate with:
- Main `runmac.sh` runner (architecture auto-detection via ARCH="ppc")
- Software library system (PowerPC software auto-launches)
- Dependency installer (PowerPC QEMU binary validation)
- Performance monitoring (resource usage optimization)

### Resource Requirements
PowerPC emulation is more demanding than 68k:
- **CPU**: Modern multi-core recommended for Mac OS X
- **RAM**: Host system needs 4GB+ for comfortable Mac OS X emulation
- **Storage**: SSD strongly recommended for Mac OS X performance
- **Network**: User-mode networking sufficient for most applications