# QemuMac - Classic Macintosh Emulation Made Easy

Emulate classic Macintosh computers with QEMU! This project provides simple scripts to run both **68k Macs** (like the Quadra 800) and **PowerPC Macs** (like the Power Mac G4) with just a few commands.

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install everything you need automatically
./install-dependencies.sh

# Or check what's needed first
./install-dependencies.sh --check
```

### 2. Get a ROM File (68k only)

For 68k Mac emulation, you'll need a `800.ROM` file. Place it in the `m68k/` directory:
```bash
# You need to obtain this file legally
cp your-800.ROM m68k/800.ROM
```

PowerPC Macs don't need ROM files - they use built-in BIOS!

## 💿 Installing Operating Systems

Before you can run a Mac, you need to install an operating system! Here's how to do a fresh installation:

### 68k Mac OS Installation (7.5.3 or 7.6.1)

1. **Boot from installer CD** with the `-b` flag:
```bash
# Boot Mac OS 7.5.3 installer
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf -c "Mac OS 7.5.3 Install.iso" -b
```

2. **Format the drives** using Disk Utility in the installer:
   - Open "Disk First Aid" or "Drive Setup" from the installer
   - Initialize (format) the main hard drive as "Mac OS Standard" (HFS)
   - Also format the shared drive for file transfers
   - Quit the disk utility

3. **Install the operating system**:
   - Run the Mac OS installer
   - Select your formatted drive as the destination
   - Wait for installation to complete
   - The Mac will restart automatically

4. **Boot normally** (remove `-b` and installation CD):
```bash
# Boot from the installed system
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf
```

### PowerPC Mac Installation (Mac OS 9 or Mac OS X)

1. **Boot from installer DVD** with the `-b` flag:
```bash
# Boot Mac OS 9.1 installer
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf -c "Mac OS 9.1 Install.iso" -b

# Or boot Mac OS X Tiger installer
./ppc/runppc.sh -C ppc/configs/osxtiger104-standard.conf -c "Mac OS X Tiger Install.iso" -b
```

2. **Format the drives** using Disk Utility:
   - **Mac OS 9**: Use "Drive Setup" to initialize drives as "Mac OS Standard"
   - **Mac OS X**: Use "Disk Utility" to format drives as "Mac OS Extended (HFS+)"
   - Format both the main drive and shared drive
   - Quit the utility

3. **Install the operating system**:
   - Run the installer (Install Mac OS 9 or Install Mac OS X)
   - Follow the setup wizard
   - Select your formatted drive
   - Wait for installation (Mac OS X takes longer!)

4. **Boot the installed system**:
```bash
# Boot Mac OS 9.1
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf

# Boot Mac OS X Tiger  
./ppc/runppc.sh -C ppc/configs/osxtiger104-standard.conf
```

### Tips for Installation
- **Be patient** - installations can take 15-30 minutes
- **Keep installer CDs** - you might need them for software later
- **Format shared drives** during installation for easy file transfer
- **Use fast configs** for quicker installation (like `sys753-fast.conf`)

## 🖥️ Running Your Installed Mac

Once installed, running your Mac is simple:

### 68k Macs
```bash
# Run Mac OS 7.5.3 (balanced performance)
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf

# Run Mac OS 7.6.1 (maximum performance)
./m68k/run68k.sh -C m68k/configs/sys761-ultimate.conf
```

### PowerPC Macs
```bash
# Run Mac OS 9.1
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf

# Run Mac OS X 10.4 Tiger
./ppc/runppc.sh -C ppc/configs/osxtiger104-standard.conf
```

### Adding Software After Installation
```bash
# Mount additional software disc on 68k Mac
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf -c software-disc.iso

# Mount additional software disc on PowerPC Mac  
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf -c software-disc.iso

# Or mount an additional hard drive with software
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf -a games-collection.img
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf -a applications.img
```

## 📚 Using the Mac Library

The easiest way to get classic Mac software! The library automatically downloads and launches games and applications.

### Interactive Mode (Recommended)
```bash
# Launch the colorful menu system
./mac-library.sh
```

Navigate through the menus to:
- Browse available software (games, applications, system tools)
- Download software automatically
- Launch with optimal settings

### Command Line Mode
```bash
# See what's available
./mac-library.sh list

# Download Marathon (classic FPS game)
./mac-library.sh download marathon

# Launch Marathon on Mac OS 7.5.3
./mac-library.sh launch marathon m68k/configs/sys753-standard.conf
```

## 📁 File Sharing Between Host and Mac

### Method 1: Shared Disk (Recommended)
1. Format the shared disk in Mac OS as HFS+
2. On Linux host: `sudo mount -t hfsplus -o loop shared.img /mnt`
3. Copy files to `/mnt`
4. Unmount: `sudo umount /mnt`

### Method 2: SMB Network Share (PowerPC only)
Add to your PowerPC config file:
```bash
QEMU_USER_SMB_DIR="/path/to/shared/folder"
```
Access in Mac OS at network address `10.0.2.4`

## ⚙️ Configuration Options

### Performance Levels
- **standard** - Balanced performance and reliability
- **fast** - Better performance, some risk
- **ultimate** - Maximum performance (68k only)
- **safest** - Maximum data safety, slower

### Examples
```bash
# Safe and slow
./m68k/run68k.sh -C m68k/configs/sys753-safest.conf

# Fast and risky  
./m68k/run68k.sh -C m68k/configs/sys753-ultimate.conf

# PowerPC performance
./ppc/runppc.sh -C ppc/configs/macos91-fast.conf
```

## 🌐 Networking

### Linux (Default: TAP networking)
- VMs can talk to each other
- Requires `sudo` for setup
- Best for development/multiple VMs

### macOS/Windows (User mode networking)
```bash
# Force user mode networking
./m68k/run68k.sh -C m68k/configs/sys753-standard.conf -N user
./ppc/runppc.sh -C ppc/configs/macos91-standard.conf -N user
```
- Simple internet access
- No special setup required
- Good for single VM use

## 🔧 Common Options

### 68k Options
```bash
-C config.conf    # Configuration file (required)
-c image.iso      # CD-ROM image
-a disk.img       # Additional hard drive
-b                # Boot from CD (for installation)
-N tap|user|passt # Network type
-D                # Debug mode
```

### PowerPC Options
```bash
-C config.conf    # Configuration file (required)  
-c image.iso      # CD-ROM image
-a disk.img       # Additional hard drive
-b                # Boot from CD (for installation)
-D                # Debug mode
```

## 🆘 Troubleshooting

### "Command not found: qemu-system-m68k"
```bash
# Install dependencies
./install-dependencies.sh
```

### "ROM file not found" (68k only)
- Obtain a legal `800.ROM` file
- Place it at `m68k/800.ROM`

### Mac won't boot from hard drive
```bash
# Try booting from CD first to install/repair
./m68k/run68k.sh -C your-config.conf -c install-cd.iso -b
```

### Network not working
```bash
# Try user mode networking (works everywhere)
./m68k/run68k.sh -C your-config.conf -N user
```

### Performance is slow
```bash
# Try a faster configuration
./m68k/run68k.sh -C m68k/configs/sys753-fast.conf
./ppc/runppc.sh -C ppc/configs/macos91-fast.conf
```

## 📖 More Information

- **CLAUDE.md** - Comprehensive technical documentation
- **CHANGELOG.md** - Project history and changes
- **m68k/CLAUDE.md** - 68k-specific details
- **ppc/CLAUDE.md** - PowerPC-specific details
- **library/CLAUDE.md** - Software library details

## 🎯 What's the Difference?

### 68k Macs (Motorola 68000)
- **Era**: 1984-1996
- **OS**: Mac OS 7.0-8.1  
- **Software**: Classic Mac applications, vintage games
- **Experience**: Authentic retro computing

### PowerPC Macs  
- **Era**: 1994-2006
- **OS**: Mac OS 9.1, Mac OS X 10.4 Tiger
- **Software**: Modern Mac apps, early Mac OS X software
- **Experience**: Bridge between classic and modern Mac

Both are awesome for different reasons - try them both! 🚀

---

*Happy emulating! Relive the golden age of Macintosh computing.*