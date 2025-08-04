# library CLAUDE.md

This directory contains the Mac Library Manager system, which provides a curated database of classic Macintosh software with automated download and launch capabilities. It serves as a software distribution system for both 68k and PowerPC emulation.

## Architecture Overview

The library system consists of a JSON-based software database, download management, and integration with the emulation runners. It automatically detects architecture requirements and launches software with appropriate configurations.

## Directory Structure

```
library/
├── software-database.json       # Curated software database
└── downloads/                   # Downloaded software storage
    ├── Apple Legacy Recovery.iso
    ├── MacOSX.4.iso
    ├── Mac_OS_X_Leopard_10.5.6.iso
    ├── Marathon Trilogy.iso
    ├── Myst.iso
    └── game-pack-2.iso
```

## Major Entry Points

### Main Library Interface
Accessed via the root-level `mac-library.sh` script, which provides:
- Interactive menu system with colorized output
- Command-line interface for scripting
- Automatic software detection and download
- Configuration-based launch system

## Key Features

### Software Database Management
- **JSON Database**: `software-database.json` contains metadata for all available software
- **Automatic Downloads**: Integrated download system with progress tracking
- **Architecture Detection**: Automatically determines if software requires 68k or PowerPC
- **Configuration Matching**: Suggests appropriate emulation configurations

### Software Metadata Schema
Each software entry contains:
```json
{
  "software_key": {
    "name": "Human-readable name",
    "description": "Brief description of software",
    "filename": "downloaded_file.iso",
    "url": "https://download.url/file.iso",
    "architecture": "m68k|ppc|both",
    "recommended_configs": ["config1.conf", "config2.conf"],
    "size_mb": 650,
    "md5": "optional_checksum"
  }
}
```

### Download Management
- **Automatic Downloads**: Downloads software when first requested
- **Resume Support**: Supports partial download resumption
- **Integrity Checking**: Optional MD5 checksum verification
- **Storage Optimization**: Organizes downloads by type and architecture

## Interactive Menu System

### Main Menu Features
- **Colorized Interface**: Terminal color support for better usability
- **Progress Bars**: Visual download progress indication
- **Software Browser**: Browse available software by category
- **Quick Launch**: One-click software launch with optimal configs

### Menu Navigation
```
Main Menu
├── Browse Software
│   ├── Games
│   ├── Applications  
│   ├── System Software
│   └── Development Tools
├── Download Manager
│   ├── Check Downloads
│   ├── Download All
│   └── Cleanup Downloads
└── Configuration Manager
    ├── List Configs
    ├── Test Config
    └── Performance Test
```

## Command Line Interface

### Available Commands
```bash
# Interactive mode
./mac-library.sh

# List all available software
./mac-library.sh list

# Download specific software
./mac-library.sh download marathon

# Launch software with specific config
./mac-library.sh launch marathon m68k/configs/sys753-standard.conf
```

### Integration with Emulation
```bash
# Automatic architecture detection and launch
./mac-library.sh launch myst
# → Detects 68k requirement
# → Suggests sys753-standard.conf
# → Downloads if needed
# → Launches with optimal settings
```

## Software Categories

### Games and Entertainment
- **Marathon Trilogy**: Classic FPS series for 68k/PowerPC
- **Myst**: Iconic adventure game
- **Game Pack Collections**: Curated game compilations
- **Classic Mac Games**: Period-appropriate software

### System and Recovery Software
- **Apple Legacy Recovery**: System recovery tools
- **Mac OS Installation CDs**: Various Mac OS versions
- **System Utilities**: Disk repair and maintenance tools

### Development and Applications
- **Development Tools**: CodeWarrior, Think C, HyperCard
- **Creative Software**: Early versions of Photoshop, Illustrator
- **Productivity Software**: Microsoft Office, FileMaker Pro

## Architecture Integration

### 68k Software Support
- Automatically detects 68k-only software requirements
- Suggests appropriate sys753 or sys761 configurations
- Handles SCSI device requirements
- Manages PRAM boot order for installation

### PowerPC Software Support  
- Identifies PowerPC-compatible software
- Suggests Mac OS 9.1 or Mac OS X configurations
- Handles IDE storage requirements
- Manages simple boot order control

### Universal Software
- Software that runs on both architectures
- Provides configuration options for both 68k and PowerPC
- Allows user choice of target architecture

## Download System Architecture

### Source Management
- **Multiple Sources**: Support for various download mirrors
- **Fallback URLs**: Automatic failover to alternate sources
- **Rate Limiting**: Respectful download behavior
- **Resume Support**: Partial download continuation

### Storage Organization
```
downloads/
├── games/                       # Game software
├── applications/                # Application software  
├── system/                      # System and recovery software
└── development/                 # Development tools
```

### Integrity Verification
- **Checksum Validation**: MD5/SHA256 verification when available
- **Size Validation**: File size verification
- **Corruption Detection**: Automatic redownload on corruption
- **Quarantine System**: Isolate suspicious downloads

## Configuration Database

### Recommended Configurations
The system maintains a mapping of software to optimal configurations:
```json
{
  "marathon": {
    "68k_configs": ["sys753-fast.conf", "sys761-ultimate.conf"],
    "ppc_configs": ["macos91-standard.conf"],
    "recommended": "sys753-fast.conf"
  }
}
```

### Performance Optimization
- **Automatic Performance Selection**: Chooses optimal configs based on software requirements
- **Memory Recommendations**: Suggests appropriate RAM settings
- **Graphics Settings**: Optimizes display settings per software
- **Audio Configuration**: Sets appropriate audio backends

## Usage Workflows

### First-Time Setup
```bash
# Initialize library system
./mac-library.sh

# Browse and select software
# → System downloads and caches locally
# → Suggests appropriate configuration
# → Launches emulation automatically
```

### Bulk Operations
```bash
# Download all software for offline use
./mac-library.sh download --all

# Download by category
./mac-library.sh download --category games

# Cleanup unused downloads
./mac-library.sh cleanup --unused
```

### Development Workflow
```bash
# Add new software to database
# 1. Edit software-database.json
# 2. Add metadata and download URL
# 3. Test download and launch
# 4. Commit to repository
```

## Database Schema

### Required Fields
```json
{
  "name": "string",              # Display name
  "filename": "string",          # Download filename
  "url": "string",               # Download URL
  "architecture": "string"       # m68k|ppc|both
}
```

### Optional Fields
```json
{
  "description": "string",       # Software description
  "size_mb": "number",          # Expected file size
  "md5": "string",              # Integrity checksum
  "category": "string",         # Software category
  "recommended_configs": "array", # Suggested configurations
  "requires_installation": "boolean", # Needs installation process
  "notes": "string"             # Special instructions
}
```

## Integration Points

### With Emulation Scripts
- Library system calls `runmac.sh` with appropriate parameters
- Passes CD-ROM images via `-c` flag
- Suggests installation mode via `-b` flag when needed
- Provides configuration file via `-C` flag

### With Configuration System
- Reads available configurations from both m68k/ and ppc/ directories
- Validates configuration compatibility with software requirements
- Provides fallback configurations when recommended ones unavailable

### With Network System
- Utilizes user mode networking for downloads within emulation
- Provides file sharing mechanisms for software transfer
- Supports both SMB and shared disk methods

## Maintenance and Updates

### Adding New Software
1. Obtain legal download URL or create disk image
2. Add metadata to software-database.json
3. Test download and launch process
4. Update documentation if special requirements exist

### Database Maintenance
- Regular URL validation to detect broken links
- Size and checksum updates for existing entries
- Category organization and cleanup
- Performance optimization recommendations

This library system provides a comprehensive software distribution and management solution, making classic Mac software easily accessible while maintaining proper emulation configurations and performance optimization.