#!/usr/bin/env bash
#
# Real HFS+ shared-disk test for Linux.
#
# The unit suite covers the delivery *orchestration* with a stubbed
# mount-shared.sh. This does the genuine article: formats an HFS+ volume,
# mounts it through mount-shared.sh, writes a file, unmounts, remounts and
# checks the file survived - then confirms the in-use guard refuses a disk
# another process holds open.
#
# Needs a Linux host with passwordless sudo, hfsprogs, and a kernel that can
# mount hfsplus. Usage: ./tests/ci/linux-shared-disk.sh
#

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

DISK="shared/shared-disk.img"
MOUNT_POINT="/tmp/qemu-shared"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "skip: this test targets Linux (host is $(uname -s))"
    exit 0
fi

fail() { echo "::error::$1"; exit 1; }
step() { printf '\n=== %s ===\n' "$1"; }

cleanup() {
    mountpoint -q "$MOUNT_POINT" 2>/dev/null && sudo umount "$MOUNT_POINT" 2>/dev/null
    rm -f "$DISK"
    return 0
}
trap cleanup EXIT

# ---------------------------------------------------------------------------

step "Does this kernel support hfsplus?"
sudo modprobe hfsplus 2>/dev/null || true
if ! grep -qw hfsplus /proc/filesystems; then
    # A warning, not a pass: silently skipping would read as "covered".
    echo "::warning::kernel has no hfsplus support - the real mount was NOT exercised"
    echo "skip: no hfsplus in /proc/filesystems"
    exit 0
fi
command -v mkfs.hfsplus >/dev/null || fail "mkfs.hfsplus missing - install hfsprogs"
echo "hfsplus available"

step "Format a real HFS+ volume"
mkdir -p shared
qemu-img create -f raw "$DISK" 64M >/dev/null
mkfs.hfsplus -v QemuMacTest "$DISK" >/dev/null
echo "formatted ${DISK}"

step "Mount through mount-shared.sh, deliver a file, release"
./mount-shared.sh
mountpoint -q "$MOUNT_POINT" || fail "mount-shared.sh did not mount the disk"

echo "built-on-the-host" > "${MOUNT_POINT}/MyApp"
[[ -f "${MOUNT_POINT}/MyApp" ]] || fail "could not write to the mounted volume"

./mount-shared.sh -u
mountpoint -q "$MOUNT_POINT" && fail "mount-shared.sh -u did not release the disk"
echo "mounted, wrote, released"

step "The file survives a round trip through the HFS+ volume"
./mount-shared.sh
grep -q built-on-the-host "${MOUNT_POINT}/MyApp" \
    || fail "the delivered file did not persist across a remount"
./mount-shared.sh -u
echo "round trip OK"

step "iso-downloader delivers onto the real volume"
# The unit suite covers this function with a stubbed mount-shared.sh. Here it
# runs against a genuine HFS+ mount: the whole point of the project is getting
# a host-built artifact onto a disk a classic Mac can read.
payload="${TMPDIR:-/tmp}/qemumac-payload.bin"
printf 'a-host-built-artifact' > "$payload"

lib=$(mktemp)
sed '$d' iso-downloader.sh > "$lib"
# shellcheck disable=SC1090  # generated at runtime from iso-downloader.sh
source "$lib"
_handle_shared_delivery_linux "$payload" "MyApp"
rm -f "$lib"

[[ -f "$payload" ]] && fail "the temp file was left behind after delivery"

./mount-shared.sh
grep -q a-host-built-artifact "${MOUNT_POINT}/MyApp" \
    || fail "the delivered artifact is not readable from the mounted volume"
./mount-shared.sh -u
echo "delivered through iso-downloader onto a real HFS+ volume"

step "The in-use guard refuses a real mount"
# Holding the image open stands in for a running VM. Nothing arbitrates
# access to the image, so a host write underneath a guest corrupts the
# catalog - this refusal is the only thing preventing that.
exec 9<>"$DISK"
out=$(./mount-shared.sh 2>&1 || true)
exec 9>&-
echo "$out" | tail -3

echo "$out" | grep -q "in use" \
    || fail "mount-shared.sh did not refuse a disk held open by another process"
mountpoint -q "$MOUNT_POINT" && fail "it mounted the disk anyway"
echo "in-use guard held against a real mount"

printf '\nLinux shared disk: OK\n'
