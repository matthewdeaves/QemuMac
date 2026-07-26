#!/usr/bin/env bash
#
# Build QEMU from source through install-deps.sh, then check run-mac.sh
# prefers the local build and can launch a VM with it.
#
# This is the other half of install-deps.sh - clone the latest stable tag,
# configure with whatever optional dependencies are present, build, install
# into ./qemu-install. It takes tens of minutes, so CI runs it on demand and
# weekly rather than on every push.
#
# Usage: ./tests/ci/linux-source-build.sh
#
set -Eeuo pipefail

# shellcheck source=tests/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_os Linux

cleanup() {
    pkill -f 'qemu-system-m68k' 2>/dev/null || true
    rm -rf vms/src_m68k
}
trap cleanup EXIT

step "Build QEMU from source"
# '2' selects the source build, then '1' installs into ./qemu-install.
printf '2\n1\n' | ./install-deps.sh

step "The local build exists and runs"
[[ -x qemu-install/bin/qemu-system-m68k ]] || fail "no local qemu-system-m68k"
[[ -x qemu-install/bin/qemu-system-ppc ]]  || fail "no local qemu-system-ppc"
./qemu-install/bin/qemu-system-m68k --version | head -1
./qemu-install/bin/qemu-system-ppc --version | head -1

step "run-mac.sh prefers the local build"
command -v xvfb-run >/dev/null || fail "xvfb-run not installed"
mkdir -p vms/src_m68k
cat > vms/src_m68k/src_m68k.conf <<'CONF'
ARCH="m68k"
MACHINE_TYPE="q800"
RAM_SIZE="128M"
HD_SIZE="512M"
PRAM_FILE="vms/src_m68k/pram.img"
HD_IMAGE="vms/src_m68k/hdd.qcow2"
MAC_ADDRESS="08:00:07:c1:c1:03"
HD_SCSI_ID=6
CD_SCSI_ID=3
CONF

log="${TMPDIR:-/tmp}/qemumac-src.log"
xvfb-run -a ./run-mac.sh --config vms/src_m68k/src_m68k.conf > "$log" 2>&1 &
sleep 25

grep -q "local QEMU build" "$log" || { cat "$log"; fail "did not use ./qemu-install"; }
pgrep -f qemu-system-m68k >/dev/null || { cat "$log"; fail "the source-built QEMU did not start"; }
pkill -f qemu-system-m68k || true

printf '\nLinux source build: OK\n'
