# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Running VMs
- `./launch.sh` - Interactive menu-driven launcher for VMs and ISOs
- `./run-mac.sh --config <vm_config_file>` - Launch a specific VM configuration
- `./run-mac.sh --config <vm_config_file> --iso <iso_file>` - Launch VM with attached ISO
- `./run-mac.sh --config <vm_config_file> --iso <iso_file> --boot-from-cd` - Boot from CD/ISO
- `./run-mac.sh --create-config <vm_name>` - Create new VM configuration interactively

### Software Management
- `./iso-downloader.sh` - Interactive downloader for operating systems and software from the database
- Custom software can be added to `iso/custom-software.json` to extend the available downloads

### Dependencies
Required tools: `qemu-system-m68k`, `qemu-system-ppc`, `qemu-img`, `jq`, `curl`, `unzip`

## Architecture Overview

### VM Management System
The project provides a complete QEMU-based classic Macintosh emulation environment supporting two architectures:

**m68k Architecture (Macintosh Quadra):**
- Uses `qemu-system-m68k` with q800 machine type
- Requires ROM file at `roms/800.ROM`
- Uses PRAM file for boot device selection (SCSI-based)
- Typical RAM: 128M, disk: 2G
- SCSI device configuration with customizable IDs

**PPC Architecture (PowerMac G4):**
- Uses `qemu-system-ppc` with mac99 machine type
- No ROM file required (built into QEMU)
- Uses bootindex for boot device selection
- Typical RAM: 512M, disk: 10G
- IDE device configuration with USB keyboard/mouse support

### Key Components
- `run-mac.sh`: Core VM runner with architecture-specific QEMU argument building
- `launch.sh`: User-friendly menu system for VM and ISO selection
- `iso-downloader.sh`: Software acquisition from JSON database
- `vms/`: Directory containing VM configurations and disk images
- `iso/`: Directory for ISO files and software database
- `roms/`: Directory for required ROM files

### VM Configuration Format
VM configs are bash files defining variables:
- `ARCH`: "m68k" or "ppc"
- `MACHINE_TYPE`: QEMU machine type
- `RAM_SIZE`: Memory allocation
- `HD_SIZE`: Disk size for new VMs
- `HD_IMAGE`: Path to disk image
- Architecture-specific settings (PRAM_FILE, SCSI IDs for m68k)

### Boot Device Handling
- **m68k**: PRAM file is patched with SCSI RefNum calculations for boot device selection
- **PPC**: Uses QEMU's bootindex parameter for IDE devices

### Display and Input
- Automatically detects host OS (macOS uses Cocoa, Linux uses SDL)
- Host-specific keyboard shortcuts and mouse handling
- Color-coded terminal output for user guidance