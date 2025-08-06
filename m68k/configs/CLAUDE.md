# CLAUDE.md - m68k/configs Directory

This directory contains configuration files for Motorola 68000 family Macintosh emulation. Each configuration represents a complete system setup optimized for specific Mac OS versions and use cases.

## Purpose and Architecture

The configuration files define comprehensive emulation parameters for 68k Mac systems, enabling automated setup of complex QEMU environments. Each file represents a fully-documented, production-ready configuration that balances performance, compatibility, and safety.

## Entry Points

**Primary Usage**: Configuration files are loaded by `runmac.sh` via the `-C` parameter:
```bash
./runmac.sh -C m68k/configs/m68k-macos753.conf
```

**Library Integration**: Configurations are automatically selected by the mac-library system based on software compatibility requirements.

**Direct Access**: Files can be edited directly for custom performance tuning and feature modifications.

## Configuration Architecture

### File Structure
Each configuration file follows a standardized structure:

1. **Header Documentation**: Purpose, features, use cases, performance characteristics
2. **Architecture Declaration**: `ARCH="m68k"` for automatic detection
3. **Machine Configuration**: Hardware emulation parameters
4. **Performance Tuning**: Cache, AIO, and threading optimizations  
5. **Storage Configuration**: Disk images and SCSI parameters
6. **Display Configuration**: Resolution and graphics settings
7. **Audio Configuration**: Sound backend and latency settings
8. **Network Configuration**: Network device and connectivity
9. **Advanced Options**: Troubleshooting and customization guidance

### Configuration Categories

**Performance Tiers**:
- **Maximum Performance**: Writeback cache, native AIO, multi-threading
- **Balanced Performance**: Writethrough cache, threaded AIO, single TCG
- **Maximum Safety**: Directsync cache, single-threaded operation

**Compatibility Levels**:
- **Optimal**: 68040 CPU, 128MB RAM, modern optimizations
- **Compatible**: 68030 CPU, 64MB RAM, stable settings
- **Historical**: 68020 CPU, 32MB RAM, period-accurate configuration

## Available Configurations

### m68k-macos753.conf
**Mac OS 7.5.3 (Maximum Performance)**

- **Purpose**: Optimized for Mac OS 7.5.3 with fastest possible performance
- **Hardware**: Quadra 800, 68040 CPU, 128MB RAM
- **Performance**: Writeback cache, native AIO, multi-threading TCG
- **Graphics**: 1152x870x8 (authentic Mac resolution)
- **Use Cases**: Gaming, development, general productivity
- **Stability**: Low risk with regular saves

**Key Features**:
- Maximum speed optimizations enabled
- Comprehensive inline documentation
- Troubleshooting guidance included
- Performance vs safety trade-off explanations

### m68k-macos761.conf
**Mac OS 7.6.1 (Enhanced Stability)**

- **Purpose**: Mac OS 7.6.1 with stability improvements over 7.5.3
- **Hardware**: Quadra 800, 68040 CPU, 128MB RAM
- **Performance**: Balanced optimization approach
- **Graphics**: Enhanced display support
- **Use Cases**: Production work requiring stability
- **Stability**: Higher stability than 7.5.3

**Key Features**:
- Stability-focused optimizations
- Enhanced Mac OS 7.6.1 feature support
- Improved software compatibility
- Balanced performance profile

### m68k-macos81.conf
**Mac OS 8.1 (Final 68k Mac OS)**

- **Purpose**: Final Mac OS version supporting 68k architecture
- **Hardware**: Quadra 800, 68040 CPU, 128MB RAM
- **Performance**: Optimized for Mac OS 8.x features
- **Graphics**: Enhanced UI support
- **Use Cases**: Latest 68k software, modern Mac OS features
- **Compatibility**: Maximum 68k software compatibility

**Key Features**:
- Final 68k Mac OS support
- Enhanced user interface features
- Modern Mac OS functionality
- Legacy software compatibility

## Configuration Parameters

### Critical Parameters

**ARCH="m68k"**: Architecture detection for automatic system selection

**QEMU_MACHINE="q800"**: Quadra 800 (only QEMU-supported 68k Mac)

**QEMU_ROM="m68k/800.ROM"**: Required Quadra 800 ROM file path

### Performance Parameters

**TCG Threading**:
- `QEMU_TCG_THREAD_MODE="multi"`: Multi-threaded (faster, warnings)
- `QEMU_TCG_THREAD_MODE="single"`: Single-threaded (stable)

**Storage Cache**:
- `QEMU_SCSI_CACHE_MODE="writeback"`: Fastest (regular saves required)
- `QEMU_SCSI_CACHE_MODE="writethrough"`: Balanced performance/safety
- `QEMU_SCSI_CACHE_MODE="directsync"`: Safest (slower)

**AIO Mode**:
- `QEMU_SCSI_AIO_MODE="native"`: Linux kernel async I/O (fastest)
- `QEMU_SCSI_AIO_MODE="threads"`: Cross-platform threaded I/O

### Hardware Parameters

**CPU Models**:
- `QEMU_CPU_MODEL="m68040"`: Best performance (default)
- `QEMU_CPU_MODEL="m68030"`: Good compatibility
- `QEMU_CPU_MODEL="m68020"`: Maximum compatibility

**Memory Sizes**:
- `QEMU_RAM="256"`: Maximum for some software
- `QEMU_RAM="128"`: Optimal for most Mac OS 7.x/8.x (default)
- `QEMU_RAM="64"`: Minimum recommended
- `QEMU_RAM="32"`: Historical accuracy

**Graphics Options**:
- `QEMU_GRAPHICS="1152x870x8"`: Authentic Mac resolution
- `QEMU_GRAPHICS="1024x768x16"`: Modern compatibility
- `QEMU_GRAPHICS="800x600x8"`: Performance optimization

## How It Works

### Configuration Loading Process
1. **File Validation**: `runmac.sh` validates configuration file syntax and required parameters
2. **Architecture Detection**: `ARCH="m68k"` triggers 68k-specific processing
3. **Parameter Processing**: Configuration variables are loaded and validated
4. **Hardware Assembly**: QEMU command line is constructed from parameters
5. **Resource Validation**: ROM files, disk images, and dependencies are verified
6. **Launch**: QEMU is executed with optimized parameters

### SCSI System Configuration
68k configurations implement SCSI storage with fixed device assignments:
- **SCSI ID 6**: Primary OS hard disk (boot priority)
- **SCSI ID 5**: Shared disk for file transfer
- **SCSI ID 4**: Additional hard disk (if specified)
- **SCSI ID 3**: CD-ROM drive (installation mode)

### Network Integration
Configurations implement user-mode networking with DP83932 Ethernet:
- No host network configuration required
- Out-of-the-box internet connectivity
- Compatible with Mac OS TCP/IP stack
- Supports file transfers and network applications

### Audio System
Apple Sound Chip (ASC) emulation with configurable backends:
- PulseAudio (Linux default)
- CoreAudio (macOS)
- DirectSound (Windows)
- Latency optimization for multimedia

## Improvements That Could Be Made

### 1. Dynamic Performance Profiles
**Current State**: Each configuration has fixed performance settings
**Improvement**: Implement profile system with automatic detection:
```bash
# Proposed enhancement
QEMU_PERFORMANCE_PROFILE="auto"  # auto, maximum, balanced, safe
# System would detect SSD vs HDD, available RAM, CPU cores
# and automatically select optimal cache/AIO/threading settings
```

### 2. Hardware Variant Support
**Current State**: Only Quadra 800 machine type supported
**Improvement**: Add configuration variants for other 68k models:
```bash
# Proposed variants
QEMU_MACHINE_VARIANT="quadra800"    # Current default
QEMU_MACHINE_VARIANT="macii"        # Mac II series support
QEMU_MACHINE_VARIANT="se30"         # SE/30 compact Mac support
```

### 3. Advanced Validation and Repair
**Current State**: Basic parameter validation
**Improvement**: Implement comprehensive validation with auto-repair:
```bash
# Proposed validation enhancements
- ROM file integrity checking (MD5 validation)
- Disk image corruption detection and repair
- Performance setting compatibility warnings
- Automatic fallback to safer settings on errors
- Configuration migration for QEMU version changes
```

## Integration Points

### With Main Runner
- Configurations are loaded by `runmac.sh` via architecture auto-detection
- Parameter validation ensures consistent behavior
- Error handling provides clear diagnostic information

### With Library System
- Software compatibility matching uses configuration metadata
- Automatic configuration selection based on software requirements
- Boot option integration for installation vs application usage

### With Performance System
- Cache and AIO settings optimize for host system capabilities
- Memory allocation matches Mac OS version requirements
- Graphics settings balance authenticity with performance

## Development Patterns

### Adding New Configurations
1. Copy existing configuration as template
2. Modify header documentation and CONFIG_NAME
3. Update image paths and system-specific parameters
4. Test boot sequence and functionality
5. Document performance characteristics and use cases

### Parameter Customization
- All parameters include comprehensive inline documentation
- Multiple options provided with performance/compatibility trade-offs
- Troubleshooting guidance for common issues
- Migration path documentation for configuration changes

### Testing and Validation
- Boot testing with multiple Mac OS versions
- Performance benchmarking across different host systems
- Compatibility validation with classic Mac software
- Error condition testing and recovery procedures