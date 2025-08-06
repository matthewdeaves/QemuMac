# CLAUDE.md - ppc/configs Directory

This directory contains configuration files for PowerPC Macintosh emulation. Each configuration represents a complete system setup optimized for specific Mac OS versions, from the final classic Mac OS through early Mac OS X releases.

## Purpose and Architecture

PowerPC configurations enable emulation of the transition era of Macintosh computing (1994-2006), supporting both classic Mac OS and the revolutionary Mac OS X. These configurations balance the complexity of PowerPC hardware with the demands of increasingly sophisticated operating systems.

## Entry Points

**Primary Usage**: Configuration files are loaded by `runmac.sh` via the `-C` parameter:
```bash
./runmac.sh -C ppc/configs/ppc-macos91.conf
```

**Library Integration**: Automatically selected by mac-library system for PowerPC-compatible software.

**Direct Configuration**: Files can be edited directly for performance tuning and feature customization.

## Configuration Architecture

### File Structure
PowerPC configurations follow the standardized structure with architecture-specific adaptations:

1. **Header Documentation**: Purpose, compatibility, performance characteristics
2. **Architecture Declaration**: `ARCH="ppc"` for automatic PowerPC detection  
3. **Machine Configuration**: mac99 hardware emulation parameters
4. **CPU Configuration**: PowerPC G3/G4 processor selection
5. **Memory Configuration**: High-capacity RAM for Mac OS X requirements
6. **Performance Tuning**: PowerPC-specific optimization settings
7. **Storage Configuration**: IDE-based disk management
8. **Display Configuration**: ATI VGA graphics with EDID support
9. **Audio Configuration**: ES1370 sound card compatibility
10. **Network Configuration**: Sun GEM Ethernet emulation

### PowerPC-Specific Features

**OpenFirmware Boot**: No external ROM files required (built into QEMU)
**IDE Storage**: Simplified storage compared to 68k SCSI systems
**Higher Memory**: 512MB to 2GB+ RAM for Mac OS X performance
**Modern Graphics**: ATI VGA with resolution auto-detection
**Enhanced Audio**: ES1370 with lower latency and better compatibility

## Available Configurations

### ppc-macos91.conf
**Mac OS 9.1 (Maximum Performance)**

- **Purpose**: Final major Mac OS 9 release with optimal classic Mac experience
- **Hardware**: Power Mac G3/G4 (mac99), PowerPC G4, 512MB RAM
- **Performance**: Optimized for Mac OS 9 with balanced settings
- **Graphics**: ATI VGA with authentic Mac resolution support
- **Use Cases**: Classic Mac OS software, legacy application compatibility
- **Stability**: High stability with mature Mac OS 9 support

**Key Features**:
- Single-core optimization (Mac OS 9 SMP limitations)
- 512MB RAM optimal for Mac OS 9.1
- ES1370 audio for excellent sound compatibility
- Sun GEM networking for authentic PowerPC experience

### ppc-osxtiger104.conf
**Mac OS X 10.4 Tiger (Balanced Performance)**

- **Purpose**: Mac OS X 10.4 Tiger with early Mac OS X features
- **Hardware**: Power Mac G3/G4 (mac99), PowerPC G4, 2GB RAM
- **Performance**: High memory allocation for acceptable Mac OS X performance
- **Graphics**: Enhanced display support for Mac OS X interface
- **Use Cases**: Early Mac OS X development, Tiger-specific software
- **Requirements**: PowerPC G4 minimum, high RAM essential

**Key Features**:
- 2GB RAM for Mac OS X Tiger performance
- PowerPC G4 CPU requirement for Tiger compatibility
- Enhanced graphics for Aqua interface
- Network optimization for Mac OS X networking stack

### ppc-osxleopard105.conf
**Mac OS X 10.5 Leopard (Resource Intensive)**

- **Purpose**: Final PowerPC Mac OS X release with modern features
- **Hardware**: Power Mac G3/G4 (mac99), PowerPC G4, 2GB RAM
- **Performance**: Maximum resources allocated for Leopard requirements
- **Graphics**: Full resolution support for Leopard interface
- **Use Cases**: Final PowerPC compatibility, Leopard-specific features
- **Performance**: Slower emulation due to resource intensity

**Key Features**:
- Final PowerPC Mac OS X support
- Time Machine, Spotlight, and modern Mac OS X features
- Maximum RAM allocation for acceptable performance
- Comprehensive hardware emulation for Leopard compatibility

## PowerPC Configuration Parameters

### Critical Parameters

**ARCH="ppc"**: Architecture detection for PowerPC system selection

**QEMU_MACHINE="mac99,via=pmu"**: Power Mac G3/G4 with Power Management Unit

### CPU Configuration

**PowerPC Processor Selection**:
- `QEMU_CPU="g4"`: PowerPC G4 (required for Mac OS X 10.4+, optimal performance)
- `QEMU_CPU="g3"`: PowerPC G3 (compatible, slightly slower)

**SMP Configuration**:
- `QEMU_SMP_CORES="1"`: Single core (Mac OS 9 limitation, mac99 constraint)
- Mac OS X SMP support limited by mac99 machine constraints

### Memory Configuration

**RAM Requirements by OS**:
- **Mac OS 9.1**: 256MB minimum, 512MB optimal
- **Mac OS X Tiger**: 1GB minimum, 2GB optimal  
- **Mac OS X Leopard**: 1GB absolute minimum, 2GB+ essential

**Memory Backends**:
- `QEMU_MEMORY_BACKEND="ram"`: Standard RAM (default)
- `QEMU_MEMORY_BACKEND="file"`: File-backed (debugging)

### Performance Parameters

**TCG Threading** (PowerPC-specific considerations):
- `QEMU_TCG_THREAD_MODE="single"`: Stable (recommended for PowerPC)
- `QEMU_TCG_THREAD_MODE="multi"`: Experimental (PowerPC MTTCG issues)

**Translation Block Cache**:
- `QEMU_TB_SIZE="512"`: 512MB optimal for PowerPC (default)
- `QEMU_TB_SIZE="1024"`: 1GB maximum performance
- `QEMU_TB_SIZE="256"`: Balanced for memory-constrained systems

### Storage Configuration

**IDE Architecture**: Simplified compared to 68k SCSI systems

**Boot Management**:
- `BOOT_FROM_CD="false"`: Boot from hard disk (normal operation)
- `BOOT_FROM_CD="true"`: Boot from CD (installation mode)

**Cache Modes**:
- `QEMU_IDE_CACHE_MODE="writeback"`: Maximum performance
- `QEMU_IDE_CACHE_MODE="writethrough"`: Balanced safety/performance
- `QEMU_IDE_CACHE_MODE="none"`: Maximum safety

## How It Works

### OpenFirmware Boot Process
1. QEMU initializes mac99 machine with OpenFirmware
2. OpenFirmware scans IDE buses for bootable devices
3. Boot device selected based on `-boot` parameter (c=HDD, d=CD)
4. Mac OS loads from selected device
5. Hardware initialization proceeds automatically

### IDE Storage Architecture
PowerPC configurations use IDE storage with simple device assignment:
- **Primary Master**: Main system hard disk
- **Primary Slave**: Shared disk for file transfer
- **Secondary Master**: CD-ROM drive (when present)
- **Boot Order**: Managed by OpenFirmware boot parameters

### Memory Management
PowerPC systems require significantly more memory than 68k:
- **Mac OS 9**: 512MB provides excellent performance
- **Mac OS X**: 2GB minimum for acceptable performance
- **Host Impact**: PowerPC emulation requires substantial host resources

### Graphics and Display
ATI VGA emulation with enhanced capabilities:
- **EDID Support**: Automatic resolution detection
- **Multiple Resolutions**: Wide range of supported display modes
- **Aqua Interface**: Full support for Mac OS X graphical interface
- **Color Depth**: Up to 32-bit color support

## Performance Characteristics

### Mac OS 9.1 Performance
- **Boot Time**: 30-60 seconds typical
- **Application Launch**: Fast, comparable to native hardware
- **Overall Responsiveness**: Excellent user experience
- **Resource Usage**: Moderate host system impact

### Mac OS X Tiger Performance  
- **Boot Time**: 2-5 minutes typical
- **Application Launch**: Acceptable with 2GB RAM
- **Overall Responsiveness**: Usable for development and testing
- **Resource Usage**: High host CPU and RAM requirements

### Mac OS X Leopard Performance
- **Boot Time**: 3-8 minutes typical
- **Application Launch**: Slow but functional
- **Overall Responsiveness**: Requires patience and optimal settings
- **Resource Usage**: Very high host resource demands

## Troubleshooting and Optimization

### Common Performance Issues

**Mac OS X Slowness**:
- Increase RAM to 2GB+ 
- Enable writeback cache mode
- Use SSD storage on host
- Close unnecessary host applications

**Boot Problems**:
- Verify CPU model compatibility (G4 for Mac OS X 10.4+)
- Check RAM allocation (minimum requirements vary by OS)
- Use installation boot mode (`-b` flag) for CD installation

**Audio Issues**:
- ES1370 provides excellent Mac compatibility
- Adjust latency settings for multimedia applications
- Verify host audio system functionality

### Optimization Strategies

**Memory Optimization**:
- Allocate maximum host RAM to guest system
- Use RAM backend for fastest memory access
- Monitor host swap usage during emulation

**Storage Optimization**:
- Use writeback cache for maximum performance
- Place disk images on SSD storage
- Enable native AIO on Linux hosts

**CPU Optimization**:
- G4 CPU required for Mac OS X 10.4+
- Single-core limitation due to mac99 constraints
- Consider host CPU frequency scaling

## Improvements That Could Be Made

### 1. Enhanced SMP Support  
**Current State**: Limited to single CPU core due to mac99 machine constraints
**Improvement**: Implement enhanced multi-processor support:
```bash
# Proposed SMP enhancement
QEMU_MACHINE="powermac3_1"  # Multi-CPU capable machine
QEMU_SMP_CORES="2"          # Dual processor support
QEMU_SMP_THREADS="2"        # Hyperthreading simulation
# Would enable Mac OS X SMP performance improvements
```

### 2. Advanced Graphics Configuration
**Current State**: Basic ATI VGA emulation
**Improvement**: Enhanced graphics capabilities:
```bash  
# Proposed graphics improvements
QEMU_GPU_ACCELERATION="true"        # Hardware-accelerated graphics
QEMU_3D_ACCELERATION="opengl"       # 3D graphics support
QEMU_DISPLAY_SCALING="2x"           # High-DPI support
QEMU_GRAPHICS_MEMORY="128"          # Dedicated GPU memory
```

### 3. Dynamic Resource Scaling
**Current State**: Fixed resource allocation
**Improvement**: Adaptive resource management:
```bash
# Proposed dynamic scaling
QEMU_AUTO_RAM="true"                # Automatic RAM adjustment
QEMU_CPU_SCALING="ondemand"         # CPU frequency scaling
QEMU_CACHE_ADAPTIVE="true"          # Adaptive cache sizing
# System would adjust resources based on guest OS demands
```

## Integration Points

### With Main Runner
- Configurations loaded via `ARCH="ppc"` detection
- OpenFirmware boot management integration
- IDE storage system initialization
- Performance parameter validation

### With Library System
- PowerPC software compatibility detection
- Automatic configuration selection for PPC software
- Boot option integration for Mac OS vs application usage

### With Performance Monitoring
- Resource usage tracking for optimization
- Performance bottleneck identification
- Host system capability assessment

## Development Patterns

### Adding Mac OS X Versions
1. Research minimum hardware requirements
2. Create configuration based on existing template
3. Adjust RAM and CPU requirements appropriately
4. Test installation and boot process
5. Document performance characteristics and limitations

### Performance Profile Creation
- Develop performance/safety profiles (maximum/balanced/safe)
- Create OS-specific optimization templates
- Implement automatic performance detection
- Document trade-offs and use case recommendations

### Cross-Architecture Testing
- Validate software compatibility across Mac OS versions
- Test performance across different host system configurations
- Document migration paths between Mac OS versions
- Ensure consistent user experience across configurations