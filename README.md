# QEMU Mac OS 7.5.5 Emulation Scripts

This project provides scripts to help run Mac OS 7.5.5 in a QEMU emulation of a Macintosh Quadra 800 and manage file sharing between the host Linux system and the emulated Mac.

------------------------------------
Required Files
------------------------------------

Before you begin, you will need:

1.  **QEMU:** The `qemu-system-m68k` emulator and `qemu-img` utility. On Debian/Ubuntu systems, you can usually install this with:
    `sudo apt update && sudo apt install qemu-system-m68k qemu-utils`

2.  **Macintosh Quadra 800 ROM:** A ROM file is required to boot the emulated machine.
    *   You can often find ROM files online. A common source is Macintosh Repository:
        https://www.macintoshrepository.org/7038-all-macintosh-roms-68k-ppc-
    *   Download the appropriate ROM file and rename it to `800.ROM` (or specify the path using the `-r` option in `run68k.sh`).

3.  **Mac OS Install Media:** You need an installation disk image (ISO) for Mac OS 7.5.x. System 7.5.3 or 7.5.5 is recommended.
    *   The "Apple Legacy Software Recovery CD" is a great resource containing System 7.5.3 and updates to 7.5.5. You can find it at Macintosh Garden:
        https://macintoshgarden.org/apps/apple-legacy-software-recovery-cd
    *   Download the ISO file (e.g., `Apple Legacy Recovery.iso`). You will use this with the `-c` option in `run68k.sh` to install the OS.

4.  **(For mac_disc_mounter.sh on Linux):** The `hfsprogs` and `hfsplus` packages are needed to mount Mac-formatted disks. The script will attempt to install these automatically using `sudo apt-get` if they are missing.

------------------------------------
Scripts Overview
------------------------------------

1.  **`run68k.sh`:**
    *   **Purpose:** Launches the QEMU emulator configured for a Macintosh Quadra 800.
    *   **Features:**
        *   Sets up the QEMU command line with appropriate machine type, memory, ROM, display, and SCSI devices.
        *   Automatically creates disk image files (`hdd1.img`, `shared.img`) and a PRAM file (`pram.img`) if they don't exist in the current directory.
        *   Allows specifying custom paths for ROM, PRAM, and disk images.
        *   Supports attaching a CD-ROM image (ISO).
        *   Allows booting directly from the CD-ROM (e.g., for OS installation).
        *   Includes a dedicated "shared" hard disk image (`shared.img`) for easier file transfer.
        *   Attempts to select the best display output (Cocoa on macOS, SDL/GTK on Linux).

2.  **`mac_disc_mounter.sh`:**
    *   **Purpose:** Mounts and unmounts the `shared.img` (or other HFS/HFS+ formatted disk images) on a Linux host system. This allows you to easily copy files between your Linux system and the emulated Mac environment.
    *   **Features:**
        *   Checks for and attempts to install required packages (`hfsprogs`, `hfsplus`).
        *   Mounts the image with read/write permissions for the current user.
        *   Provides options to unmount, check the filesystem type, and attempt repairs.
        *   Requires `sudo` privileges for mounting, unmounting, and package installation.

------------------------------------
Using `run68k.sh`
------------------------------------

Make the script executable: `chmod +x run68k.sh`

**Basic Usage:**
Place the `800.ROM` file in the same directory. Then simply run:
`./run68k.sh`
This will create `hdd1.img` (1GB), `shared.img` (200MB), and `pram.img` if they don't exist, and start the emulation, booting from `hdd1.img`.

**Installing Mac OS:**
1.  Download the Mac OS install ISO (e.g., `Apple Legacy Recovery.iso`).
2.  Run the script, specifying the ISO with `-c` and telling it to boot from CD with `-b`:
    `./run68k.sh -c "Apple Legacy Recovery.iso" -b`
3.  Follow the on-screen instructions within the emulator to partition and format the primary hard drive (`hdd1.img`) and install Mac OS onto it. You may also want to format the second hard drive (`shared.img`) using the Drive Setup utility within the Mac OS installer (format it as HFS/Mac OS Standard).
4.  Once installation is complete, shut down the emulator.
5.  Run the emulator normally (without `-b`) to boot from the newly installed OS:
    `./run68k.sh`

**Command-Line Options:**
`./run68k.sh [options]`
  `-r FILE`  Specify ROM file (default: `800.ROM`)
  `-p FILE`  Specify PRAM file (default: `pram.img`)
  `-h FILE`  Specify main hard disk image file (default: `hdd1.img`)
  `-f FILE`  Specify shared disk image file (default: `shared.img`)
  `-c FILE`  Specify CD-ROM image file (e.g., `MyOS.iso`)
  `-s SIZE`  Specify size for new main hard disk (e.g., `2G`, default: `1G`)
  `-S SIZE`  Specify size for new shared disk (e.g., `500M`, default: `200M`)
  `-b`       Boot from CD-ROM (requires `-c`)
  `-d TYPE`  Force display type (`sdl`, `gtk`, `cocoa`)
  `-?`       Show help message

**Example with custom paths and CD:**
`./run68k.sh -r /path/to/my.ROM -h /data/macos_main.img -f /data/macos_share.img -c /isos/utility_disk.iso`

------------------------------------
Using `mac_disc_mounter.sh` (Linux Only)
------------------------------------

Make the script executable: `chmod +x mac_disc_mounter.sh`

**Purpose:** To access the `shared.img` from your Linux system for file transfer.

**Important:** You need `sudo` to run this script because mounting filesystems requires root privileges.

**Mounting the Shared Disk:**
Ensure the emulator is **not** running when you mount the image on the host.
`sudo ./mac_disc_mounter.sh`
This will:
1. Check for `hfsprogs`/`hfsplus` and install them if needed (will prompt for password).
2. Create the mount point `/mnt/mac_shared` if it doesn't exist.
3. Mount `shared.img` to `/mnt/mac_shared`.
4. Set permissions so your user can read/write.
5. Open your file manager at the mount point.

You can now copy files into or out of `/mnt/mac_shared`.

**Unmounting the Shared Disk:**
When you are finished transferring files, unmount the image:
`sudo ./mac_disc_mounter.sh -u`
It's crucial to unmount before starting the emulator again.

**Command-Line Options:**
`sudo ./mac_disc_mounter.sh [options]`
  `-i FILE`  Specify disk image file (default: `shared.img`)
  `-m DIR`   Specify mount point (default: `/mnt/mac_shared`)
  `-u`       Unmount the disk image from the specified mount point.
  `-c`       Check disk image filesystem type (uses `file` command).
  `-r`       Attempt to repair the disk image filesystem (uses `fsck.hfsplus`/`fsck.hfs`).
  `-h`       Show help message

**Example mounting a different image to a custom location:**
`sudo ./mac_disc_mounter.sh -i /data/another_mac_disk.img -m /media/mymacdrive`
**Example unmounting from the custom location:**
`sudo ./mac_disc_mounter.sh -m /media/mymacdrive -u`

------------------------------------
File Transfer Workflow
------------------------------------

1.  **Inside Emulator:** Ensure the `shared.img` disk (usually the second hard drive icon on the Mac desktop) is formatted (HFS / Mac OS Standard). You only need to do this once using Drive Setup during OS installation or later.
2.  **Shut Down Emulator:** Quit QEMU.
3.  **Mount on Host (Linux):** `sudo ./mac_disc_mounter.sh`
4.  **Transfer Files:** Copy files to/from `/mnt/mac_shared` using your Linux file manager or command line.
5.  **Unmount on Host:** `sudo ./mac_disc_mounter.sh -u`
6.  **Start Emulator:** `./run68k.sh`
7.  **Access Files in Emulator:** Open the second hard drive icon on the Mac desktop to see the files you copied.

------------------------------------
`.gitignore` File
------------------------------------

The `.gitignore` file included tells the Git version control system to ignore the ROM file, ISO file, and the disk image files (`.img`, `.ROM`, `.iso`). This is standard practice because these files are typically large binaries and don't belong in a source code repository. You should obtain them separately as described above.