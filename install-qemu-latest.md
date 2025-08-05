# Install Latest QEMU from Git Source

## Step 1: Uninstall Current QEMU Installation

```bash
# Remove all QEMU packages
sudo apt remove --purge qemu-system qemu-system-ppc qemu-system-x86 qemu-system-arm qemu-system-mips qemu-system-misc qemu-system-s390x qemu-system-sparc qemu-utils qemu-system-gui qemu-system-common qemu-system-data qemu-block-extra qemu-system-modules-opengl qemu-system-modules-spice

# Clean up any remaining dependencies
sudo apt autoremove
```

## Step 2: Install Build Dependencies

```bash
# Install required build tools and libraries
sudo apt update
sudo apt install git build-essential pkg-config libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build libslirp-dev libcap-ng-dev libattr1-dev libssl-dev python3-sphinx python3-sphinx-rtd-theme libaio-dev libbluetooth-dev libbrlapi-dev libbz2-dev libcap-dev libcurl4-gnutls-dev libgtk-3-dev libibverbs-dev libjpeg8-dev libncurses5-dev libnuma-dev librbd-dev librdmacm-dev libsasl2-dev libsdl2-dev libseccomp-dev libsnappy-dev libssh-dev libvde-dev libvdeplug-dev libvte-2.91-dev libxen-dev liblzo2-dev valgrind xfslibs-dev libnfs-dev libiscsi-dev
```

## Step 3: Clone and Build QEMU

```bash
# Clone the latest QEMU source
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu

# Configure build (this will take a few minutes)
./configure --enable-slirp --enable-gtk --enable-sdl --enable-curses --enable-vnc --enable-tools --enable-guest-agent

# Build QEMU (this will take 15-30 minutes depending on your system)
make -j$(nproc)

# Install QEMU system-wide
sudo make install
```

## Step 4: Verify Installation

```bash
# Check QEMU version
qemu-system-ppc --version
qemu-system-m68k --version

# Verify installation paths
which qemu-system-ppc
which qemu-system-m68k
```

## Notes

- The build process will take significant time (15-30+ minutes)
- QEMU will be installed to `/usr/local/bin/` by default
- You may need to update your PATH or scripts if they reference specific paths
- The configure step automatically detects available libraries and features