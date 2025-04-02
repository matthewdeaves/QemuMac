# QEMU m68k Mac Emulation Helper Scripts


Introduction
------------
This project provides a set of scripts to simplify the setup and management of classic Macintosh (m68k architecture) emulation using QEMU. It allows you to define different Mac OS configurations in separate files and easily launch them, while also providing a utility to share files between your host Linux system and the emulated Mac environment via a shared disk image.

Purpose
-------
- To provide a consistent and repeatable way to launch QEMU for specific Mac models and OS versions.
- To manage separate disk images (OS, shared data, PRAM) for different configurations.
- To simplify the process of booting from CD/ISO images for OS installation.
- To offer a convenient method (`mac_disc_mounter.sh`) for accessing a shared disk image from the Linux host for file transfer.

Prerequisites
-------------
1.  **QEMU:** You need the `qemu-system-m68k` package installed.
    - On Debian/Ubuntu: `sudo apt update && sudo apt install qemu-system-m68k`
2.  **Macintosh ROM Files:** You MUST obtain the correct ROM file(s) for the Macintosh model(s) you wish to emulate (e.g., `800.ROM` for a Quadra 800).
    - **IMPORTANT:** ROM files are copyrighted software and are NOT included with this project. You must acquire them legally (e.g., dump them from your own physical hardware). Place the ROM file(s) where the configuration files expect them (or update the paths in the `.conf` files). You can often find ROM files online. A common source is [Macintosh Repository](https://www.macintoshrepository.org/7038-all-macintosh-roms-68k-ppc-)
3.  **Mac OS Installation Media:** You need CD-ROM images (.iso, .img, .toast) or floppy disk images for the version(s) of Mac OS you intend to install. These are also NOT included. I use the Apple Legacy Software Recovery CD from  [Macintosh Garden](https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd)
4.  **Linux Host:** The `mac_disc_mounter.sh` script is specifically designed for Linux systems (using `apt` for package management and standard mount commands). The `run68k.sh` script might work on other Unix-like systems (like macOS) with potential minor adjustments (e.g., display type).
5.  **(For `mac_disc_mounter.sh`) HFS/HFS+ Utilities:** The mounting script requires `hfsprogs` and `hfsplus` to interact with Mac-formatted disk images. The script will attempt to install these automatically using `sudo apt-get install` if they are not found.

File Structure
--------------
- `run68k.sh`: The main script to launch the QEMU emulator.
- `mac_disc_mounter.sh`: Utility script to mount/unmount the shared disk image on the Linux host.
- `*.conf`: Configuration files defining specific emulation setups (e.g., `sys755-q800.conf`).
- `*.ROM`: (User-provided) Macintosh ROM files.
- Directories (e.g., `710/`, `755/`, `761/`): These directories (or similar, as defined in your `.conf` files) will be created by `run68k.sh` if they don't exist, and will contain the hard disk images (`.img`) and PRAM files for each configuration.

Configuration (`.conf` files)
-----------------------------
These files define the parameters for a specific emulation instance using shell variable assignments. Key variables include:
- `CONFIG_NAME`: A descriptive name for the setup.
- `QEMU_MACHINE`: The QEMU machine type (e.g., `q800`, `mac99`).
- `QEMU_RAM`: RAM allocation in Megabytes (MB).
- `QEMU_ROM`: Path to the required ROM file for the specified machine.
- `QEMU_HDD`: Path to the primary OS hard disk image file for this configuration.
- `QEMU_SHARED_HDD`: Path to the shared disk image file for this configuration.
- `QEMU_PRAM`: Path to the PRAM (Parameter RAM) file for this configuration.
- `QEMU_GRAPHICS`: Desired screen resolution and color depth (e.g., `1152x870x8`).
- `QEMU_HDD_SIZE`: (Optional) Size for the OS HDD if it needs to be created (default: 1G).
- `QEMU_SHARED_HDD_SIZE`: (Optional) Size for the Shared HDD if it needs to be created (default: 200M).
- `QEMU_CPU`: (Optional) Specify a specific CPU variant if needed.

You can create new `.conf` files for different Mac OS versions, machine types, or experimental setups. Ensure the paths point to unique locations if you want separate installations.

Usage: `run68k.sh`
-------------------
This script launches the QEMU emulator based on a specified configuration file.

**Syntax:**
`./run68k.sh -C <config_file.conf> [options]`

**Required Argument:**
- `-C FILE`: Specify the configuration file to use (e.g., `-C sys755-q800.conf`).

**Options:**
- `-c FILE`: Specify a CD-ROM image file (.iso, .img) to attach to the emulator. *Note this is little c not big C.*
- `-b`: Boot from the attached CD-ROM (requires the `-c` option). Use this for OS installation.
- `-d TYPE`: Force a specific QEMU display type (`sdl`, `gtk`, `cocoa`). If omitted, it attempts to auto-detect (cocoa for macOS, sdl otherwise).
- `-?`: Show help message.

**Examples:**

1.  **Run an existing System 7.5.5 installation:**
    `./run68k.sh -C sys755-q800.conf`

2.  **Boot from a System 7.6.1 install CD to install the OS:**
    `./run68k.sh -C sys761-q800.conf -c /path/to/your/Mac_OS_7.6.1.iso -b`
    *(will create `761/hdd_sys761.img`, `761/shared_761.img`, and `761/pram_761_q800.img` if they don't exist)*
    *You will need to use Drive Setup to format the disks on first boot before installing an OS*

Usage: `mac_disc_mounter.sh` (Linux Only)
-----------------------------------------
This script mounts or unmounts the *shared* disk image associated with a specific configuration file on your Linux host system, allowing you to copy files between the host and the guest OS environment.

**IMPORTANT:**
- The shared disk image (`QEMU_SHARED_HDD` specified in the `.conf` file) must typically be formatted *within* the emulated Mac OS first (using Drive Setup or similar utility, usually as HFS or HFS+) before it can be mounted and used effectively on the host. The [Apple Legacy software Recovery CD](https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd) has Drive Setup tools for this.
- You will likely need `sudo` to run mount and unmount operations on Linux.
- Ensure the QEMU virtual machine associated with the config file is **shut down** before attempting to mount or unmount its shared disk.

**Syntax:**
`sudo ./mac_disc_mounter.sh -C <config_file.conf> [options]`

**Required Argument:**
- `-C FILE`: Specify the configuration file whose `QEMU_SHARED_HDD` you want to interact with (e.g., `-C sys755-q800.conf`).

**Options:**
- `-m DIR`: Specify a custom mount point (default: `/mnt/mac_shared`).
- `-u`: Unmount the disk image from the mount point.
- `-c`: Check the filesystem type of the disk image.
- `-r`: Attempt to repair the filesystem on the disk image (tries HFS+ then HFS).
- `-h`: Show help message.

**Examples:**

1.  **Mount the shared disk for the System 7.5.5 configuration:**
    `sudo ./mac_disc_mounter.sh -C sys755-q800.conf`
    *(Mounts `755/shared_755.img` to `/mnt/mac_shared` by default)*

2.  **Unmount the shared disk for the System 7.5.5 configuration:**
    `sudo ./mac_disc_mounter.sh -C sys755-q800.conf -u`

3.  **Mount the shared disk for System 7.6.1 to a custom location:**
    `sudo ./mac_disc_mounter.sh -C sys761-q800.conf -m /home/user/macshare`

4.  **Check the filesystem type of the System 7.1 shared disk:**
    `sudo ./mac_disc_mounter.sh -C sys710-q800.conf -c`


Getting Started / First OS Installation
---------------------------------------
1.  **Install Prerequisites:** Ensure QEMU is installed.
2.  **Obtain ROM:** Get the correct ROM file (e.g., `800.ROM`) and place it where the `.conf` file expects it (e.g., in the same directory as the scripts, or update the `QEMU_ROM` path in the `.conf` file).
3.  **Obtain Install Media:** Get the Mac OS install CD/ISO image.
4.  **Choose Config:** Select a `.conf` file corresponding to the OS you want to install (e.g., `sys761-q800.conf`).
5.  **Run Installer:** Execute `run68k.sh` with the `-c` (CD image) and `-b` (boot from CD) flags:
    `./run68k.sh -C sys761-q800.conf -c /path/to/your/Mac_OS_7.6.1.iso -b`
    *(The script will create the necessary directories and empty disk image files specified in the config if they don't exist)*
6.  **Install OS:** Inside the QEMU window, follow the standard Mac OS installation procedure. You will need to initialize/format the virtual hard disk (`QEMU_HDD`) using a tool like "Drive Setup" or "Apple HD SC Setup" from the installer before you can install onto it.
7.  **(Optional) Format Shared Disk:** While the installer is running (or after installation), you can also format the *shared* disk (`QEMU_SHARED_HDD`) using Drive Setup so it's ready for file transfer later. Format it as HFS or HFS+.
8.  **Shutdown:** Once installation is complete, shut down the emulated Mac.
9.  **First Boot from HDD:** Run the script *without* the `-c` and `-b` flags to boot from the newly installed OS on the virtual hard disk:
    `./run68k.sh -C sys761-q800.conf`
10. **File Transfer:**
    - Shut down the emulated Mac.
    - Mount the shared disk on your Linux host: `sudo ./mac_disc_mounter.sh -C sys761-q800.conf`
    - Copy files to/from the mount point (e.g., `/mnt/mac_shared`).
    - Unmount the disk: `sudo ./mac_disc_mounter.sh -C sys761-q800.conf -u`
    - Start the emulator again: `./run68k.sh -C sys761-q800.conf`

Important Notes
---------------
- **ROM Legality:** Remember, you are responsible for legally obtaining any Macintosh ROM files.
- **Permissions:** You may need `sudo` for `mac_disc_mounter.sh`. Ensure you have write permissions in the directories where disk images will be created by `run68k.sh`.
- **Shared Disk Formatting:** The shared disk image needs to be formatted *inside* the emulated Mac OS before `mac_disc_mounter.sh` can successfully mount it for read/write access on the host.
- **VM Shutdown:** Always shut down the QEMU virtual machine cleanly before attempting to mount its shared disk image on the host.

Troubleshooting
---------------
- **"ROM file ... not found"**: Verify the `QEMU_ROM` path in your `.conf` file is correct and the ROM file exists at that location.
- **"Failed to create directory/image"**: Check filesystem permissions for the directories specified in the `.conf` file paths (`QEMU_HDD`, `QEMU_SHARED_HDD`, `QEMU_PRAM`).
- **QEMU display issues**: If the default display (`sdl` or `cocoa`) doesn't work, try forcing another type with `-d gtk` or `-d sdl`. Ensure necessary host libraries (like SDL or GTK development headers) are installed.
- **Cannot mount shared disk**: Ensure the VM is shut down. Ensure the disk was formatted inside the VM. Try the check (`-c`) or repair (`-r`) options with `mac_disc_mounter.sh`. Check system logs (`dmesg`) for mount errors.