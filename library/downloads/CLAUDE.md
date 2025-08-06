# CLAUDE.md - library/downloads Directory

This directory serves as the local cache for downloaded classic Macintosh software. It stores ISO/disk images of games, applications, and operating systems that are automatically downloaded by the Mac Library Manager system.

## Purpose and Architecture

The downloads directory implements a persistent local cache for classic Mac software, enabling offline usage and reducing repeated downloads. It supports both manual file placement and automatic retrieval from internet archives and repositories.

## Entry Points

**Automatic Downloads**: Triggered by mac-library.sh when software is requested but not locally available.

**Manual Placement**: Users can manually place disk images in this directory for recognition by the library system.

**Direct Access**: Files can be accessed directly for mounting, copying, or manual management.

## Directory Contents

### Current Software Collection

The directory contains a curated collection of classic Macintosh software:

```
downloads/
├── Apple Legacy Recovery.iso      # Apple system recovery disc (580MB)
├── MacOS 922 Universal.iso       # Mac OS 9.2.2 installation (610MB)  
├── MacOSX.4.iso                  # Mac OS X 10.4 Tiger installation (3.7GB)
├── MacOSXLeopard10.5.iso         # Mac OS X 10.5 Leopard installation (4.2GB)
├── Marathon Trilogy.iso          # Bungie Marathon games collection (650MB)
├── Myst.iso                      # Cyan Myst adventure game (500MB)
├── Power Mac G4 Install 9.2.toast # Power Mac installation disc (650MB)
├── SC4.iso                       # SimCity 4 Deluxe city simulation (2.1GB)
├── SimCity3000.toast             # SimCity 3000 city simulation (650MB)
└── game-pack-2.iso               # LucasArts adventure games (650MB)
```

### File Categories

**Operating Systems**:
- System installation discs for Mac OS 9.x and Mac OS X
- Recovery and utility discs
- Hardware-specific installation media

**Games**:
- Classic Mac games from 1990s-2000s era
- Adventure games, strategy games, first-person shooters
- Original retail disc images with copy protection removed

**Applications**:
- Productivity software and creative applications
- Development tools and system utilities
- Period-appropriate software versions

## How It Works

### Download Management System

**Automatic Download Process**:
1. User selects software from library menu or command line
2. System checks for local file in downloads directory
3. If missing, downloads from URL specified in software-database.json
4. File saved with clean filename for easy identification
5. Optional MD5 verification ensures file integrity
6. Software immediately available for launching

**Download Sources**:
- Internet Archive (archive.org) - Primary source for preservation
- Macintosh Garden (macintoshgarden.org) - Community-maintained archives
- Original publisher sites - For currently available software
- Community FTP servers - Specialized classic Mac collections

### File Naming and Organization

**Clean Filenames**: Downloads use descriptive names instead of original URLs:
- `MacOSXLeopard10.5.iso` instead of complex archive.org URL
- `Marathon Trilogy.iso` instead of repository hash codes
- Consistent naming enables easy manual file management

**Format Support**:
- **ISO**: Standard CD/DVD disc images
- **TOAST**: Roxio Toast proprietary format (common on Mac)  
- **IMG/DMG**: Apple disk image formats
- **ZIP**: Compressed archives (automatically handled)

### Integration with Library Database

**Metadata Linking**: Each file corresponds to entry in software-database.json:
```json
{
  "marathon_trilogy": {
    "name": "Marathon Trilogy",
    "filename": "Marathon Trilogy.iso",
    "url": "ftp://mirror:mirror@ftp.macintosh.garden/games/marathontrilogy.zip",
    "md5": "ec4b56162044b9a34e0c60cc859f073f",
    "architecture": ["m68k"]
  }
}
```

**Smart Filename Resolution**: System uses both `filename` and `nice_filename` fields for optimal file naming and compatibility.

## Storage Management

### Disk Space Considerations

**Current Collection Size**: ~12GB total
**Individual File Sizes**:
- Games: 500MB - 2GB typical
- Operating Systems: 600MB - 4GB typical  
- Applications: 100MB - 1GB typical

**Growth Management**:
- Downloads persist indefinitely once cached
- Manual cleanup available via library management tools
- Storage monitoring prevents disk space exhaustion

### File Integrity

**MD5 Verification**: Optional integrity checking for critical files
**Corruption Detection**: Automatic redownload on verification failure
**Backup Recommendations**: Regular backup of downloads directory for offline preservation

## Performance Characteristics

### Download Performance

**Resume Support**: Partial download resumption for large files
**Progress Tracking**: Visual progress bars during downloads
**Bandwidth Optimization**: Respectful download behavior with rate limiting

**Typical Download Times** (25Mbps connection):
- Mac OS Installation (4GB): ~22 minutes
- Game Collection (650MB): ~3.5 minutes
- Individual Game (500MB): ~2.7 minutes

### Local Access Performance

**SSD Storage**: Optimal for fast game/application launching
**HDD Storage**: Acceptable but slower boot times
**Network Storage**: Not recommended for frequently-used software

## File Format Details

### ISO Format (Standard)
- **Compatibility**: Excellent across all platforms
- **Mount Support**: Native mounting on macOS, Linux (loop), Windows (third-party)
- **QEMU Integration**: Direct mounting via `-cdrom` parameter
- **Preservation**: Exact bit-for-bit disc image

### TOAST Format (Roxio)
- **Origin**: Created by Roxio Toast burning software on Mac
- **Compatibility**: Best on macOS, limited elsewhere
- **Conversion**: Can be converted to ISO using Toast or disk utilities
- **Features**: Supports Mac-specific disc formatting

### Archive Formats
- **ZIP**: Automatic extraction and conversion to ISO
- **StuffIt**: Classic Mac compression format support
- **DMG**: Apple disk image mounting and conversion

## Usage Patterns

### Automatic Usage (Recommended)
```bash
# Software downloaded automatically when launched
./mac-library.sh launch marathon_trilogy m68k-macos753.conf

# Interactive selection triggers downloads
./mac-library.sh   # Choose software, system downloads as needed
```

### Manual Management
```bash
# List downloaded software
./mac-library.sh list

# Check download status
ls -lh library/downloads/

# Manual download of specific software
./mac-library.sh download myst
```

### Direct File Access
```bash
# Mount ISO on Linux for inspection
sudo mount -o loop library/downloads/Myst.iso /mnt

# Mount TOAST on macOS
hdiutil attach library/downloads/SimCity3000.toast

# Copy for external use
cp library/downloads/Marathon\ Trilogy.iso ~/external_drive/
```

## Maintenance and Management

### Cleanup Procedures

**Removing Unused Downloads**:
```bash
# Identify large files
du -sh library/downloads/* | sort -hr

# Remove specific software
rm library/downloads/SC4.iso

# System will redownload if requested again
```

**Archive Management**:
```bash
# Compress rarely-used files
gzip library/downloads/MacOSXLeopard10.5.iso

# Decompress when needed
gunzip library/downloads/MacOSXLeopard10.5.iso.gz
```

### Backup Strategies

**Full Collection Backup**:
```bash
# Create complete backup
tar -czf ~/mac_software_backup.tar.gz library/downloads/

# Restore complete collection
tar -xzf ~/mac_software_backup.tar.gz
```

**Selective Backup**:
```bash
# Backup only operating systems
tar -czf ~/mac_os_backup.tar.gz library/downloads/*OS* library/downloads/*macos*

# Backup only games
tar -czf ~/mac_games_backup.tar.gz library/downloads/*trilogy* library/downloads/*pack* library/downloads/Myst.iso
```

## Integration Points

### With Library Database
- Filename resolution for clean naming
- URL management for download sources  
- Category-based organization and filtering
- Architecture compatibility checking

### With Emulation System
- Direct mounting in QEMU via runmac.sh
- Boot option integration (CD vs Mac desktop mounting)
- Architecture detection for proper emulation

### With User Interface
- Progress tracking during downloads
- Status reporting (downloaded/not downloaded)
- Error handling and retry mechanisms

## Improvements That Could Be Made

### 1. Intelligent Storage Management
**Current State**: Downloads persist indefinitely
**Improvement**: Implement smart cleanup system:
```bash
# Proposed storage optimization
CLEANUP_UNUSED_AFTER="90days"       # Remove unused downloads after period
COMPRESS_INACTIVE="30days"          # Compress rarely-used files
CACHE_SIZE_LIMIT="50GB"             # Maximum cache size before cleanup
PRIORITY_RETENTION="favorites"       # Never remove favorited software
```

### 2. Enhanced Download System
**Current State**: Single-threaded downloads with basic progress
**Improvement**: Advanced download management:
```bash
# Proposed download enhancements  
PARALLEL_DOWNLOADS="3"              # Multiple simultaneous downloads
MIRROR_FALLBACK="true"              # Automatic failover to alternate sources
BANDWIDTH_LIMIT="5MB/s"             # Configurable rate limiting
DOWNLOAD_SCHEDULING="off-peak"      # Schedule large downloads
```

### 3. Content Organization and Discovery
**Current State**: Flat directory structure
**Improvement**: Organized content management:
```bash
# Proposed organization system
downloads/
├── games/
│   ├── adventure/
│   ├── strategy/
│   └── action/
├── operating_systems/
│   ├── classic/
│   └── osx/
├── applications/
│   ├── productivity/
│   └── creative/
└── utilities/
```

## Security Considerations

### Download Verification
- MD5 checksums verify file integrity
- Source validation prevents malicious downloads
- Trusted source prioritization (Internet Archive, established communities)

### Malware Prevention  
- Downloads from reputable archive sources only
- No execution of downloaded content on host system
- Emulated environment provides sandboxing

### Legal Compliance
- Links to legally available software only
- Abandonware and explicitly freely-distributed content
- No circumvention of active copy protection
- Respect for intellectual property rights

## Development Patterns

### Adding New Software
1. Verify legal availability and source legitimacy
2. Add entry to software-database.json with metadata
3. Test download and verification process
4. Ensure proper filename and category assignment
5. Validate emulation compatibility

### Source Management
- Maintain multiple mirror URLs when possible
- Monitor source availability and update as needed
- Document source policies and terms of use
- Establish relationships with preservation communities

### Quality Assurance
- Test each downloaded image boots properly
- Verify software functionality within emulated environment
- Document any special requirements or limitations
- Maintain compatibility matrix for different configurations