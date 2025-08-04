# m68k CLAUDE.md

This subdirectory contains all components for 68k (Motorola 68000) Macintosh emulation using QEMU's m68k system emulation.

## Architecture Overview

The 68k emulation targets classic Mac OS 7.0-8.1 running on emulated Quadra 800 hardware (q800 machine type). This provides authentic classic Macintosh experience with period-appropriate software compatibility.

## Major Entry Points

### Primary Script
- **`run68k.sh`**: Main emulation runner for 68k architecture
  - Handles SCSI storage with complex ID management
  - Uses PRAM manipulation for boot order control
  - Requires external ROM file (800.ROM)
  - Supports TAP, User, and Passt networking modes
  - Manages Apple Sound Chip (ASC) audio configuration

## Directory Structure

```
m68k/
├── run68k.sh                    # Main 68k emulation script
├── 800.ROM                      # Quadra 800 ROM file (user-provided)
├── configs/                     # Configuration files
│   ├── sys753-*.conf            # Mac OS 7.5.3 variants
│   └── sys761-*.conf            # Mac OS 7.6.1 variants
├── images/                      # Disk images and system data
│   ├── 753/                     # Mac OS 7.5.3 images
│   │   ├── hdd_sys753.img       # OS hard disk
│   │   ├── shared_753.img       # Shared disk for file transfer
│   │   └── pram_753_q800.img    # PRAM settings storage
│   └── 761/                     # Mac OS 7.6.1 images
│       ├── hdd_sys761.img       # OS hard disk
│       ├── shared_761.img       # Shared disk for file transfer
│       └── pram_761_q800.img    # PRAM settings storage
├── ppc/                         # Legacy PowerPC components (should be moved)
└── scripts/                     # 68k-specific utilities (empty currently)
```

## Key Features

### SCSI Storage Management
- **Complex SCSI ID Assignment**: Static ID mapping for consistent device recognition
  - SCSI ID 6: OS hard disk (highest priority for proper boot)
  - SCSI ID 5: Shared disk for file transfer
  - SCSI ID 4: Additional user disk (via -a flag)
  - SCSI ID 3: CD-ROM drive (swapped to ID 6 during installation)
- **Boot Installation Mode**: Swaps SCSI IDs to boot from CD for OS installation
- **Cache Modes**: Supports writethrough, writeback, none, directsync
- **AIO Modes**: threads/native with proper cache.direct configuration

### PRAM Boot Control
- **Boot Order Management**: Modifies PRAM bytes to control boot device selection
  - Offset 122 (0x7A): Boot device SCSI ID
  - PRAM files maintain settings between sessions
- **Debug Support**: Optional PRAM inspection before QEMU launch

### Audio Configuration
- **Apple Sound Chip (ASC)**: Authentic Mac audio hardware emulation
  - `easc` mode: Enhanced ASC (default)
  - `asc` mode: Classic ASC compatibility
- **Backend Support**: PulseAudio, ALSA, CoreAudio
- **Latency Control**: Configurable audio buffer latency

### ROM Requirements
- **800.ROM File**: Required Quadra 800 ROM (user must provide)
  - Contains Mac OS boot code and hardware drivers
  - Not included due to copyright restrictions
  - Essential for authentic hardware emulation

## Configuration System

### Performance Variants
Each OS version has multiple performance tuning options:

#### Mac OS 7.5.3 Configurations
- `sys753-standard.conf`: Balanced default settings
- `sys753-fast.conf`: Performance-optimized (writeback cache)
- `sys753-ultimate.conf`: Maximum performance (MTTCG + native AIO)
- `sys753-safest.conf`: Maximum data safety (no cache)
- `sys753-authentic.conf`: Historical accuracy (NuBus graphics)

#### Mac OS 7.6.1 Configurations  
- `sys761-standard.conf`: Balanced default settings
- `sys761-fast.conf`: Performance-optimized (writeback cache)
- `sys761-ultimate.conf`: Maximum performance (MTTCG + native AIO)
- `sys761-safest.conf`: Maximum data safety (no cache)
- `sys761-authentic.conf`: Historical accuracy (NuBus graphics)

### Required Configuration Variables
All 68k configs must include:
```bash
ARCH="m68k"                           # Architecture identifier
CONFIG_NAME="Display Name"            # Human-readable config name
QEMU_MACHINE="q800"                   # Quadra 800 machine type
QEMU_RAM="128"                        # RAM in MB (typically 128MB)
QEMU_ROM="m68k/800.ROM"              # Path to ROM file
QEMU_HDD="path/to/os_disk.img"       # Main OS disk image
QEMU_SHARED_HDD="path/to/shared.img" # Shared disk for file transfer
QEMU_PRAM="path/to/pram.img"         # PRAM settings file
QEMU_GRAPHICS="1024x768x8"           # Display resolution and color depth
```

### Optional Performance Variables
```bash
QEMU_SCSI_CACHE_MODE="writethrough"     # Cache mode for SCSI drives
QEMU_SCSI_AIO_MODE="threads"            # AIO mode (threads/native)
QEMU_TCG_THREAD_MODE="multi"            # TCG threading (single/multi)
QEMU_TB_SIZE="32"                       # Translation block cache size
QEMU_ASC_MODE="easc"                    # ASC audio mode (easc/asc)
QEMU_DISPLAY_DEVICE="built-in"         # Display device type
```

## Hardware Emulation Details

### Machine Type: Quadra 800 (q800)
- **CPU**: Motorola 68040 at 33MHz
- **Memory**: Up to 128MB RAM (expandable in emulation)
- **Graphics**: Built-in video with NuBus expansion support
- **Audio**: Apple Sound Chip with 8-bit/16-bit playback
- **Storage**: SCSI subsystem with multiple drive support
- **Networking**: Ethernet via emulated NIC

### Supported Mac OS Versions
- **Mac OS 7.0-7.1**: Basic compatibility
- **Mac OS 7.5.3**: Primary target (sys753 configs)
- **Mac OS 7.6.1**: Enhanced target (sys761 configs)  
- **Mac OS 8.0-8.1**: Advanced features supported

## Networking Modes

### TAP Networking (Linux Default)
- Bridged networking for VM-to-VM communication
- Requires bridge-utils and sudo privileges
- Best for development and multi-VM setups

### User Mode Networking (macOS Default)
- NAT networking for internet access
- No special setup required
- Optional SMB file sharing support

### Passt Networking
- Modern userspace networking
- Better performance than user mode
- Requires passt package installation

## File Sharing

### Shared Disk Method
1. Format shared disk as HFS/HFS+ in Mac OS
2. Mount on Linux host: `sudo mount -t hfsplus -o loop shared.img /mnt`
3. Copy files and unmount: `sudo umount /mnt`
4. Requires hfsprogs package on Linux

### SMB Sharing (User Mode Only)
- Configure `QEMU_USER_SMB_DIR` in config file
- Provides network file sharing via QEMU's built-in SMB server

## Common Workflows

### Fresh Installation
```bash
# Boot from Mac OS installation CD
./run68k.sh -C m68k/configs/sys753-standard.conf -c MacOS753.iso -b

# After installation, boot normally
./run68k.sh -C m68k/configs/sys753-standard.conf
```

### Performance Testing
```bash
# Compare different performance levels
./run68k.sh -C m68k/configs/sys753-standard.conf  # Balanced
./run68k.sh -C m68k/configs/sys753-fast.conf      # Performance
./run68k.sh -C m68k/configs/sys753-ultimate.conf  # Maximum
```

### Debug PRAM Issues
```bash
# Enable debug mode to inspect PRAM
./run68k.sh -C m68k/configs/sys753-standard.conf -D
```

## Architecture-Specific Notes

### Differences from PowerPC
- **ROM Requirement**: 68k requires external ROM file, PPC uses built-in BIOS
- **Storage**: Complex SCSI vs simple IDE channels  
- **Boot Control**: PRAM manipulation vs simple -boot flags
- **Audio**: ASC hardware vs ES1370 sound device
- **Performance**: Generally slower due to 68k instruction translation overhead

### Legacy Components
- **ppc/ subdirectory**: Contains misplaced PowerPC components that should be in /ppc/
- **scripts/ subdirectory**: Currently empty, intended for 68k-specific utilities

This 68k emulation provides the most authentic classic Macintosh experience, supporting the golden age of Mac OS 7.x with full hardware compatibility for period software and games.