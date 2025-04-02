# QEMU m68k Mac Emulation Helper Scripts


Introduction
------------
This project provides a set of scripts to simplify the setup and management of classic Macintosh (m68k architecture) emulation using QEMU. It allows you to define different Mac OS configurations in separate files and easily launch them. Key features include flexible networking options (bridged TAP for inter-VM communication or simple User Mode for internet access) and a utility to share files between your host Linux system and the emulated Mac environment via a shared disk image. See it in use on [YouTube](https://www.youtube.com/watch?v=YA2fHUXZhas)

Known bug: the -b flag (or lack of) is not respected when supplying a .ISO as a CD. If a CD is provided the Mac will always try to boot from it.

Purpose
-------
- To provide a consistent and repeatable way to launch QEMU for specific Mac models and OS versions.
- To manage separate disk images (OS, shared data, PRAM) for different configurations.
- To offer flexible networking:
    - **TAP Mode (Default):** Automatically configures bridged TAP networking, enabling direct communication (AppleTalk, TCP/IP) between multiple running VM instances, but with no access to the internet.
    - **User Mode:** Provides simple internet access for the VM via QEMU's built-in NAT, without requiring host network configuration or special privileges.
- To simplify the process of booting from CD/ISO images for OS installation.
- To offer a convenient method (`mac_disc_mounter.sh`) for accessing a shared disk image from the Linux host for file transfer.

Prerequisites
-------------
1.  **QEMU:** You need the `qemu-system-m68k` package installed.
    - On Debian/Ubuntu: `sudo apt update && sudo apt install qemu-system-m68k`
2.  **Networking Utilities (for TAP Mode):** If using the default TAP network mode (`-N tap`), you need `bridge-utils` and `iproute2` (usually installed by default).
    - On Debian/Ubuntu: `sudo apt update && sudo apt install bridge-utils`
    - The script will check for `brctl` and `ip` if TAP mode is selected and prompt if needed packages are missing.
3.  **Sudo Privileges:** The `run68k.sh` script requires `sudo` privileges *when using the default TAP network mode* (`-N tap`) to create and manage the network bridge and TAP interfaces. You will likely be prompted for your password when launching a VM in TAP mode. User mode (`-N user`) does not require sudo for networking itself.
4.  **Macintosh ROM Files:** You MUST obtain the correct ROM file(s) for the Macintosh model(s) you wish to emulate (e.g., `800.ROM` for a Quadra 800).
    - **IMPORTANT:** ROM files are copyrighted software and are NOT included with this project. You must acquire them legally (e.g., dump them from your own physical hardware). Place the ROM file(s) where the configuration files expect them (or update the paths in the `.conf` files). You can often find ROM files online. A common source is [Macintosh Repository](https://www.macintoshrepository.org/7038-all-macintosh-roms-68k-ppc-)
5.  **Mac OS Installation Media:** You need CD-ROM images (.iso, .img, .toast) or floppy disk images for the version(s) of Mac OS you intend to install. These are also NOT included. I use the Apple Legacy Software Recovery CD from [Macintosh Garden](https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd)
6.  **Linux Host:** The `mac_disc_mounter.sh` script is specifically designed for Linux systems (using `apt` for package management and standard mount commands). The `run68k.sh` script is tested on Ubuntu but might work on other Unix-like systems (like macOS) with potential minor adjustments (e.g., display type, network setup commands if using TAP).
7.  **(For `mac_disc_mounter.sh`) HFS/HFS+ Utilities:** The mounting script requires `hfsprogs` and `hfsplus` to interact with Mac-formatted disk images. The script will attempt to install these automatically using `sudo apt-get install` if they are not found.
8.  **TAP Functions Script (for TAP Mode):** The file `qemu-tap-functions.sh` must be present in the same directory as `run68k.sh` if you are using the default TAP network mode. It contains the necessary functions for setting up and tearing down TAP interfaces and bridges.

File Structure
--------------
- `run68k.sh`: The main script to launch the QEMU emulator.
- `qemu-tap-functions.sh`: Contains helper functions for TAP networking setup/cleanup (used only when `-N tap` is active).
- `mac_disc_mounter.sh`: Utility script to mount/unmount the shared disk image on the Linux host.
- `*.conf`: Configuration files defining specific emulation setups (e.g., `sys755-q800.conf`).
- `*.ROM`: (User-provided) Macintosh ROM files.
- Directories (e.g., `710/`, `755/`, `761/`): These directories (or similar, as defined in your `.conf` files) will be created by `run68k.sh` if they don't exist, and will contain the hard disk images (`.img`) and PRAM files for each configuration.

Configuration (`.conf` files)
-----------------------------
These files define the parameters for a specific emulation instance using shell variable assignments. Key variables include:
- `CONFIG_NAME`: A descriptive name for the setup.
- `QEMU_MACHINE`: The QEMU machine type (e.g., `q800`).
- `QEMU_RAM`: RAM allocation in Megabytes (MB).
- `QEMU_ROM`: Path to the required ROM file for the specified machine.
- `QEMU_HDD`: Path to the primary OS hard disk image file for this configuration.
- `QEMU_SHARED_HDD`: Path to the shared disk image file for this configuration.
- `QEMU_PRAM`: Path to the PRAM (Parameter RAM) file for this configuration.
- `QEMU_GRAPHICS`: Desired screen resolution and color depth (e.g., `1152x870x8`).
- `QEMU_HDD_SIZE`: (Optional) Size for the OS HDD if it needs to be created (default: 1G).
- `QEMU_SHARED_HDD_SIZE`: (Optional) Size for the Shared HDD if it needs to be created (default: 200M).
- `QEMU_CPU`: (Optional) Specify a specific CPU variant if needed.
- **TAP Mode Specific (Optional):** These are only used if network mode is `tap`.
    - `BRIDGE_NAME`: Name of the host network bridge to use (default: `br0`).
    - `QEMU_TAP_IFACE`: Specify a fixed name for the VM's TAP network interface. If omitted, a unique name is generated based on the config filename (e.g., `tap_sys755q800`).
    - `QEMU_MAC_ADDR`: Specify a fixed MAC address for the VM's network interface. If omitted, a unique QEMU MAC address is generated.

You can create new `.conf` files for different Mac OS versions, machine types, or experimental setups. Ensure the paths point to unique locations if you want separate installations.

Usage: `run68k.sh`
-------------------
This script launches the QEMU emulator based on a specified configuration file and sets up networking according to the chosen mode.

**Syntax:**
`./run68k.sh -C <config_file.conf> [options]`

**Required Argument:**
- `-C FILE`: Specify the configuration file to use (e.g., `-C sys755-q800.conf`).

**Options:**
- `-c FILE`: Specify a CD-ROM image file (.iso, .img) to attach to the emulator. *Note this is little c not big C.*
- `-b`: Boot from the attached CD-ROM (requires the `-c` option). Use this for OS installation.
- `-d TYPE`: Force a specific QEMU display type (`sdl`, `gtk`, `cocoa`). If omitted, it attempts to auto-detect (cocoa for macOS, sdl for Linux/other).
- `-N TYPE`: Specify network type:
    - `tap` (Default): Use bridged TAP networking. Requires `sudo` and `qemu-tap-functions.sh`. Enables inter-VM communication but no internet access.
    - `user`: Use QEMU User Mode networking. No `sudo` needed for networking, provides simple internet access (NAT), but no inter-VM communication.
- `-?`: Show help message.

**Examples:**

1.  **Run an existing System 7.5.5 installation (using default TAP networking):**
    `./run68k.sh -C sys755-q800.conf`
    *(You will likely be prompted for your sudo password for network setup)*

2.  **Run an existing System 7.5.5 installation with User Mode networking (for internet access):**
    `./run68k.sh -C sys755-q800.conf -N user`
    *(No sudo prompt for networking expected)*

3.  **Boot from a System 7.6.1 install CD to install the OS (using default TAP networking):**
    `./run68k.sh -C sys761-q800.conf -c /path/to/your/Mac_OS_7.6.1.iso -b`
    *(will create `761/hdd_sys761.img`, `761/shared_761.img`, and `761/pram_761_q800.img` if they don't exist)*
    *You will need to use Drive Setup to format the disks on first boot before installing an OS*

Networking Setup
----------------
The `run68k.sh` script configures networking based on the mode selected with the `-N` option.

**Why the Choice?**
- **TAP Mode (`-N tap`, Default):** Best for running multiple VMs that need to communicate directly with each other (e.g., AppleTalk file sharing, network games). It simulates VMs being on the same physical network segment. However, it does *not* automatically grant the VMs internet access; that requires extra manual configuration on the host (bridging to a physical interface, NAT setup).
- **User Mode (`-N user`):** Best for a single VM that needs simple access to the internet (if the host has it). QEMU handles NAT internally. It's simpler to set up (no `sudo`, no extra host config) but makes direct communication between VMs, or from the host to the VM, difficult.

**TAP Mode (`-N tap`, Default) Details:**
- **Requires:** `sudo`, `bridge-utils`, `iproute2`, `qemu-tap-functions.sh`.
- **How it Works:**
    1.  **Bridge Creation:** Ensures a network bridge (default `br0`) exists on the host (`sudo ip link`).
    2.  **TAP Interface Creation:** Creates a dedicated TAP device (e.g., `tap_sys755q800`) for the VM (`sudo ip tuntap`).
    3.  **Connecting TAP to Bridge:** Connects the TAP interface to the bridge (`sudo brctl addif`).
    4.  **QEMU Connection:** QEMU uses this TAP device (`-netdev tap,... -net nic,...`).
    5.  **Cleanup:** When the script exits, it automatically removes the TAP device from the bridge and deletes it (`sudo`).
- **Benefits:** Direct VM-to-VM communication (AppleTalk, TCP/IP).
- **Limitations:** No internet access for VMs.
- **In-VM Configuration (TAP Mode):**
    - **Control Panels:** Use `MacTCP` or `TCP/IP` (Open Transport).
    - **Connection Method:** Select `Ethernet`.
    - **IP Address:** Assign static IP addresses via DHCP.
    - **AppleTalk:** Use the `AppleTalk` control panel (set to `Active`, via `Ethernet`). VMs on the same bridge should see each other in the Chooser.

**User Mode (`-N user`) Details:**
- **Requires:** None beyond QEMU itself.
- **How it Works:** QEMU uses its internal network stack (`-net nic,model=dp83932 -net user`). It creates a virtual DHCP server and NAT router for the VM.
- **Benefits:** Simple internet access for the VM (if host has it). No `sudo` needed for networking. No host network configuration.
- **Limitations:** No easy direct communication between multiple VMs or from host to VM.
- **In-VM Configuration (User Mode):**
    - **Control Panels:** Use `MacTCP` or `TCP/IP`.
    - **Connection Method:** Select `Ethernet`.
    - **IP Address:** Configure using `DHCP Server`. QEMU will assign an IP (usually in the `10.0.2.x` range).

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
1.  **Install Prerequisites:** Ensure QEMU is installed. If using TAP networking (default), install `bridge-utils` and ensure `qemu-tap-functions.sh` is present.
2.  **Obtain ROM:** Get the correct ROM file and place it appropriately.
3.  **Obtain Install Media:** Get the Mac OS install CD/ISO image.
4.  **Choose Config:** Select a `.conf` file.
5.  **Run Installer:** Execute `run68k.sh` with the `-c` (CD image) and `-b` (boot from CD) flags. The default TAP networking is usually fine for installation.
    `./run68k.sh -C sys761-q800.conf -c /path/to/your/Mac_OS_7.6.1.iso -b`
    *(If using TAP mode, the script will prompt for sudo password, create network interfaces, etc.)*
6.  **Install OS:** Inside QEMU, initialize/format the virtual HDD (`QEMU_HDD`) using "Drive Setup" or similar, then install the OS.
7.  **(Optional) Format Shared Disk:** Format the `QEMU_SHARED_HDD` as HFS/HFS+ using Drive Setup.
8.  **Shutdown:** Shut down the emulated Mac.
9.  **First Boot from HDD:** Run the script *without* `-c` and `-b`. Choose your network mode with `-N` if needed (default is TAP).
    `./run68k.sh -C sys761-q800.conf` (Boots with TAP networking)
    `./run68k.sh -C sys755-q800.conf` (Boots with TAP networking)

OR
    `./run68k.sh -C sys761-q800.conf -N user` (Boots with User networking)
    `./run68k.sh -C sys755-q800.conf -N user` (Boots with User networking)
10. **Configure Networking (Inside VM):** Set up MacTCP/TCP/IP and AppleTalk according to the network mode chosen (see "Networking Setup" section).
11. **File Transfer:** Shut down VM, use `mac_disc_mounter.sh` to mount/unmount shared disk, copy files, restart VM.

Important Notes
---------------
- **ROM Legality:** You are responsible for legally obtaining Macintosh ROM files.
- **Permissions:** `run68k.sh` requires `sudo` *when using TAP networking*. `mac_disc_mounter.sh` also requires `sudo`. Ensure write permissions for disk image directories.
- **Shared Disk Formatting:** Format the shared disk *inside* the VM first.
- **VM Shutdown:** Always shut down the VM before using `mac_disc_mounter.sh`.
- **Multiple VMs:** Don't run the same VM config concurrently - you don't want 2 VMs accessing the same disk images at the same time.

Troubleshooting
---------------
- **"ROM file ... not found"**: Verify `QEMU_ROM` path in `.conf`.
- **"Failed to create directory/image"**: Check filesystem permissions.
- **Network Errors (TAP Mode - "Failed to create bridge/TAP", etc.)**: Ensure `bridge-utils` installed. Check `sudo`. Check for interface name conflicts. Check system logs (`dmesg`, `journalctl`). Ensure `qemu-tap-functions.sh` exists.
- **VMs Cannot See Each Other:** Ensure you are using TAP mode (`-N tap` or default). Verify both VMs are on the same bridge. Check in-VM IP/AppleTalk settings (see TAP Mode config details). This is expected behavior in User mode (`-N user`).
- **No Internet Access:** This is expected in TAP mode (`-N tap`) without extra host configuration. If internet access is the priority, try User mode (`-N user`). Verify User mode in-VM config is set to DHCP.
- **QEMU display issues**: Try forcing display type with `-d`. Ensure host libraries (SDL/GTK) are installed.
- **Cannot mount shared disk**: Ensure VM is off. Ensure disk was formatted in VM. Try check (`-c`) or repair (`-r`) options. Check `dmesg`.