#!/usr/bin/env bash
#
# Linux integration test: installs QEMU the way a user would, then boots a VM
# end to end through run-mac.sh.
#
# This is the only place the Linux path runs for real - the SDL display branch,
# the automatic ROM download and its checksum, qemu-img disk creation, PRAM
# creation and boot patching, shared-disk setup, and the exec into QEMU. The
# unit suite stubs QEMU, so none of that is exercised there.
#
# Needs a Linux host with passwordless sudo and xvfb (SDL needs a display).
# Usage: ./tests/ci/linux-integration.sh
#

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

VM_DIR="vms/ci_m68k"
RUN_LOG="${TMPDIR:-/tmp}/qemumac-ci-run.log"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "skip: this test targets Linux (host is $(uname -s))"
    exit 0
fi

# GitHub renders ::error:: as an annotation; harmless when run by hand.
fail() { echo "::error::$1"; exit 1; }
step() { printf '\n=== %s ===\n' "$1"; }

cleanup() {
    pkill -f 'qemu-system-m68k' 2>/dev/null || true
    rm -rf "$VM_DIR"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------

step "Install QEMU through install-deps.sh"
# '1' selects the package-manager path. The unit suite only greps the apt
# package names; this proves they actually resolve - there is no 'qemu-img'
# package, qemu-utils provides it.
printf '1\n' | ./install-deps.sh

step "Both QEMU targets and the runtime tools are present"
qemu-system-m68k --version | head -1
qemu-system-ppc --version | head -1
qemu-img --version | head -1
command -v jq curl unzip >/dev/null || fail "runtime dependencies missing"

step "Boot a VM end to end through run-mac.sh"
command -v xvfb-run >/dev/null || fail "xvfb-run not installed"

mkdir -p "$VM_DIR"
cat > "${VM_DIR}/ci_m68k.conf" <<CONF
ARCH="m68k"
MACHINE_TYPE="q800"
RAM_SIZE="128M"
HD_SIZE="512M"
PRAM_FILE="${VM_DIR}/pram.img"
HD_IMAGE="${VM_DIR}/hdd.qcow2"
MAC_ADDRESS="08:00:07:c1:c1:01"
HD_SCSI_ID=6
CD_SCSI_ID=3
SHARED_SCSI_ID=4
DISPLAY_RES="800x600x8"
CONF

xvfb-run -a ./run-mac.sh --config "${VM_DIR}/ci_m68k.conf" > "$RUN_LOG" 2>&1 &
sleep 30

if ! pgrep -f qemu-system-m68k >/dev/null; then
    echo "--- run-mac.sh output ---"
    cat "$RUN_LOG"
    fail "run-mac.sh did not leave QEMU running"
fi

# Assert on the real command line rather than on log wording.
cmdline=$(pgrep -af qemu-system-m68k | head -1)
echo "QEMU command line:"
echo "  ${cmdline}"

case "$cmdline" in
    *"-display sdl"*) ;;
    *) fail "expected the SDL display backend on Linux" ;;
esac
case "$cmdline" in
    *"audiodev="*) ;;
    *) fail "no audiodev selected - a soundless host segfaults without one" ;;
esac
case "$cmdline" in
    *"-bios roms/800.ROM"*) ;;
    *) fail "the Quadra ROM was not passed" ;;
esac

pkill -f qemu-system-m68k || true

step "Everything run-mac.sh should have created exists"
[[ -f roms/800.ROM ]]           || fail "ROM was not downloaded"
[[ -f "${VM_DIR}/hdd.qcow2" ]]  || fail "disk image was not created"
[[ -f "${VM_DIR}/pram.img" ]]   || fail "PRAM file was not created"
[[ -f shared/shared-disk.img ]] || fail "shared disk was not created"
echo "ROM, disk, PRAM and shared disk all present"

step "PRAM boot patch is byte-correct"
# The boot device on 68k is a SCSI RefNum patched into PRAM at offset 120:
# ~(id + 32), big-endian. For HD_SCSI_ID=6 that is 0xffffffd9.
got=$(od -An -tx1 -j120 -N4 "${VM_DIR}/pram.img" | tr -d ' \n')
echo "PRAM bytes at offset 120: ${got}"
[[ "$got" == "ffffffd9" ]] || fail "expected ffffffd9 for SCSI ID 6, got ${got}"

step "Negative control"
# The checks above must be capable of failing. QEMU validates -device only
# after loading the ROM, so this needs the real ROM to be meaningful.
out=$(qemu-system-m68k -M q800 -m 128M -display none \
        -bios roms/800.ROM -device definitely-not-a-real-device 2>&1 || true)
echo "$out" | tail -1
echo "$out" | grep -q "is not a valid device model name" \
    || fail "negative control did not trip - these checks may be vacuous"

printf '\nLinux integration: OK\n'
