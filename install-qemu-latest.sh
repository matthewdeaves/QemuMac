#!/bin/bash
set -euo pipefail

# Install Latest QEMU from Git Source
# This script will completely replace your current QEMU installation

echo "=== Installing Latest QEMU from Git Source ==="
echo

# Step 1: Uninstall current QEMU
echo "Step 1: Removing current QEMU installation..."
sudo apt remove --purge -y qemu-system qemu-system-ppc qemu-system-x86 qemu-system-arm qemu-system-mips qemu-system-misc qemu-system-s390x qemu-system-sparc qemu-utils qemu-system-gui qemu-system-common qemu-system-data qemu-block-extra qemu-system-modules-opengl qemu-system-modules-spice 2>/dev/null || true
sudo apt autoremove -y
echo "✓ Current QEMU removed"
echo

# Step 2: Install build dependencies
echo "Step 2: Installing build dependencies..."
sudo apt update
sudo apt install -y git build-essential pkg-config libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build libslirp-dev libcap-ng-dev libattr1-dev libssl-dev python3-sphinx python3-sphinx-rtd-theme libaio-dev libbluetooth-dev libbrlapi-dev libbz2-dev libcap-dev libcurl4-gnutls-dev libgtk-3-dev libibverbs-dev libjpeg8-dev libncurses5-dev libnuma-dev librbd-dev librdmacm-dev libsasl2-dev libsdl2-dev libseccomp-dev libsnappy-dev libssh-dev libvde-dev libvdeplug-dev libvte-2.91-dev libxen-dev liblzo2-dev valgrind xfslibs-dev libnfs-dev libiscsi-dev
echo "✓ Build dependencies installed"
echo

# Step 3: Clone QEMU source
echo "Step 3: Cloning QEMU source..."
if [ -d "qemu" ]; then
    echo "Removing existing qemu directory..."
    rm -rf qemu
fi
git clone https://gitlab.com/qemu-project/qemu.git
cd qemu
echo "✓ QEMU source cloned"
echo

# Step 4: Configure build
echo "Step 4: Configuring build..."
./configure --enable-slirp --enable-gtk --enable-sdl --enable-curses --enable-vnc --enable-tools --enable-guest-agent
echo "✓ Build configured"
echo

# Step 5: Build QEMU
echo "Step 5: Building QEMU (this will take 15-30+ minutes)..."
echo "Using $(nproc) CPU cores for parallel compilation..."
make -j$(nproc)
echo "✓ QEMU built successfully"
echo

# Step 6: Install QEMU
echo "Step 6: Installing QEMU system-wide..."
sudo make install
echo "✓ QEMU installed to /usr/local/bin/"
echo

# Step 7: Verify installation
echo "Step 7: Verifying installation..."
echo "QEMU PowerPC version:"
qemu-system-ppc --version
echo
echo "QEMU m68k version:"
qemu-system-m68k --version
echo
echo "Installation paths:"
which qemu-system-ppc
which qemu-system-m68k
echo

echo "=== QEMU Installation Complete ==="
echo "QEMU has been installed to /usr/local/bin/"
echo "You may need to restart your terminal or run 'hash -r' to refresh the PATH cache"
echo