# ppc CLAUDE.md

This subdirectory contains all components for PowerPC Macintosh emulation using QEMU's PowerPC system emulation. It targets both Mac OS 9.1 and Mac OS X 10.4 Tiger running on emulated Power Mac G3/G4 hardware.

## Architecture Overview

The PowerPC emulation uses the mac99 machine type with PMU (Power Management Unit) support, providing a modern Mac experience suitable for both classic Mac OS 9 and early Mac OS X systems.

## Major Entry Points

### Primary Script
- **`runppc.sh`**: Main emulation runner for PowerPC architecture  
  - Uses simple IDE storage configuration
  - Simple boot control via -boot flags (c=HDD, d=CD)
  - Uses QEMU built-in BIOS (no external ROM required)
  - User mode networking only (optimized for reliability)
  - ES1370 sound device emulation

## Directory Structure

```
ppc/
├── runppc.sh                    # Main PowerPC emulation script
├── configs/                     # Configuration files
│   ├── macos91-*.conf          # Mac OS 9.1 configurations
│   ├── osxtiger104-*.conf      # Mac OS X 10.4 Tiger configurations
│   └── osxleopard105-*.conf    # Mac OS X 10.5 Leopard configurations
└── images/                      # Disk images organized by OS
    ├── 91/                      # Mac OS 9.1 images
    ├── tiger104/                # Mac OS X 10.4 Tiger images
    │   ├── MacOSX10.4.img      # OS hard disk
    │   └── shared_tiger104.img # Shared disk for file transfer
    └── tiger105/                # Mac OS X 10.5 Leopard images
        ├── MacOSX10.5.img      # OS hard disk
        └── shared_tiger105.img # Shared disk for file transfer
```

## Key Features

### Simplified Storage Architecture
- **IDE Channels**: Simple Primary/Secondary Master/Slave configuration
- **Boot Control**: Uses QEMU's -boot flag (c=HDD, d=CD-ROM)
- **No SCSI Complexity**: Straightforward drive assignment and management
- **Performance Options**: Cache modes (writethrough/writeback) and AIO (threads/native)

### Built-in BIOS Support
- **No ROM Files Required**: Uses QEMU's built-in PowerPC BIOS via `-L pc-bios`
- **Automatic Hardware Detection**: BIOS handles device initialization
- **Simplified Configuration**: No ROM path management needed

### Audio System
- **ES1370 Sound Device**: Modern sound card emulation
- **Audio Backend Support**: PulseAudio, ALSA, CoreAudio integration
- **Low Latency**: Optimized for multimedia and gaming

### User Mode Networking
- **Reliability Focus**: User mode networking only for maximum compatibility
- **Universal Support**: Works on Linux, macOS, and Windows hosts
- **No Setup Required**: No special privileges or configuration needed
- **SMB File Sharing**: Built-in SMB server for file transfer

## Configuration System

### Supported Operating Systems

#### Mac OS 9.1 Configurations
- `macos91-standard.conf`: Balanced default (512MB RAM, writethrough cache)
- `macos91-fast.conf`: Performance-optimized (writeback cache, native AIO)

#### Mac OS X 10.4 Tiger Configurations  
- `osxtiger104-standard.conf`: Balanced default (1024MB RAM, USB support)
- `osxtiger104-fast.conf`: Performance-optimized (writeback cache, native AIO)

#### Mac OS X 10.5 Leopard Configurations
- `osxleopard105-fast.conf`: Performance-optimized for Leopard

### Required Configuration Variables
All PowerPC configs must include:
```bash
ARCH="ppc"                               # Architecture identifier
CONFIG_NAME="Display Name"               # Human-readable config name
QEMU_MACHINE="mac99,via=pmu"            # Power Mac G3/G4 with PMU
QEMU_RAM="512"                           # RAM in MB (512MB+ recommended)
QEMU_HDD="path/to/os_disk.img"          # Main OS disk image
QEMU_SHARED_HDD="path/to/shared.img"    # Shared disk for file transfer
QEMU_GRAPHICS="1024x768x32"             # Display resolution and color depth
```

### Optional Performance Variables
```bash
QEMU_CPU="g4"                           # CPU type (g3, g4, g4e)
QEMU_SMP_CORES="1"                      # SMP cores (mac99 supports 1 only)
QEMU_IDE_CACHE_MODE="writethrough"      # IDE cache mode
QEMU_IDE_AIO_MODE="threads"             # AIO mode (threads/native)
QEMU_TCG_THREAD_MODE="multi"            # TCG threading
QEMU_TB_SIZE="64"                       # Translation block cache size
QEMU_SOUND_DEVICE="es1370"              # Sound device type
QEMU_USB_ENABLED="true"                 # USB support (Mac OS X only)
QEMU_AUDIO_BACKEND="pa"                 # Audio backend
```

## Hardware Emulation Details

### Machine Type: Power Mac G3/G4 (mac99)
- **CPU**: PowerPC G3/G4 processor emulation
- **Memory**: Up to 2GB RAM support  
- **Graphics**: Built-in ATI graphics emulation
- **Audio**: ES1370 sound card
- **Storage**: IDE controllers (Primary/Secondary)
- **USB**: USB 1.1 support for Mac OS X
- **PMU**: Power Management Unit for proper Mac OS X support

### Memory Recommendations
- **Mac OS 9.1**: 512MB RAM (minimum 256MB)
- **Mac OS X 10.4**: 1024MB RAM (minimum 512MB)  
- **Mac OS X 10.5**: 1024MB+ RAM for optimal performance

## Storage Management

### IDE Configuration
Unlike 68k SCSI complexity, PowerPC uses simple IDE:
- **Primary Master**: Main OS disk
- **Primary Slave**: CD-ROM (when attached)
- **Secondary Master**: Shared disk
- **Secondary Slave**: Additional disk (via -a flag)

### Disk Image Creation
```bash
# OS disk (15GB default)
qemu-img create -f raw MacOS91.img 15G

# Shared disk (1GB default)  
qemu-img create -f raw shared_91.img 1G
```

### File Sharing Methods
1. **Shared Disk**: Format as HFS+ in Mac OS, mount on Linux host
2. **SMB Sharing**: Configure QEMU_USER_SMB_DIR for network sharing
3. **CD-ROM Images**: Create ISO images for software installation

## Networking Architecture

### User Mode Networking Only
PowerPC emulation uses user mode networking exclusively for:
- **Reliability**: Works on all host platforms without configuration
- **Simplicity**: No TAP/bridge setup required
- **Internet Access**: Provides NAT-based internet connectivity
- **File Sharing**: Built-in SMB server via QEMU_USER_SMB_DIR

### Network Configuration
```bash
# Automatic DHCP configuration (10.0.2.x network)
# Gateway: 10.0.2.2
# DNS: 10.0.2.3
# SMB: 10.0.2.4 (if QEMU_USER_SMB_DIR configured)
```

## Common Workflows

### Mac OS 9.1 Installation
```bash
# Install from CD
./runppc.sh -C ppc/configs/macos91-standard.conf -c MacOS91.iso -b

# Boot after installation
./runppc.sh -C ppc/configs/macos91-standard.conf
```

### Mac OS X Tiger Installation  
```bash
# Install from DVD
./runppc.sh -C ppc/configs/osxtiger104-standard.conf -c MacOSX104.iso -b

# Boot after installation
./runppc.sh -C ppc/configs/osxtiger104-standard.conf
```

### Performance Comparison
```bash
# Standard performance
./runppc.sh -C ppc/configs/macos91-standard.conf

# Optimized performance
./runppc.sh -C ppc/configs/macos91-fast.conf
```

## Architecture-Specific Features

### Advantages over 68k
- **No ROM Files**: Uses built-in BIOS, no copyright concerns
- **Simple Storage**: IDE vs complex SCSI management
- **Modern OS Support**: Mac OS X compatibility
- **Better Performance**: PowerPC instruction translation more efficient
- **USB Support**: Hardware USB for Mac OS X peripherals

### Mac OS X Specific Features
- **USB Support**: Essential for Mac OS X hardware compatibility
- **Higher RAM**: 1GB+ RAM for proper Mac OS X performance
- **Modern Networking**: Better TCP/IP stack and internet compatibility
- **Multimedia**: Enhanced graphics and audio capabilities

## Software Compatibility

### Mac OS 9.1 Software
- Classic Mac applications and games
- Carbon applications
- Adobe Creative Suite (older versions)
- Microsoft Office for Mac
- Classic Mac development tools

### Mac OS X 10.4 Tiger Software  
- Early Mac OS X applications
- Universal Binary applications
- Xcode development tools
- Safari web browser
- iTunes and multimedia applications

## Performance Optimization

### Cache Modes
- **writethrough**: Balanced safety/performance (default)
- **writeback**: Maximum performance (risk of data loss)
- **none**: Maximum safety (slowest performance)

### AIO Modes
- **threads**: Standard threading (default)
- **native**: Linux native AIO (best performance with cache.direct=on)

### TCG Threading
- **single**: Single-threaded TCG (compatibility)
- **multi**: Multi-threaded TCG (better performance on multi-core hosts)

This PowerPC emulation provides excellent compatibility with both classic Mac OS 9 and early Mac OS X systems, offering a bridge between the classic Mac era and modern macOS development.