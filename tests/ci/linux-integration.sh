#!/usr/bin/env bash
#
# Linux integration test: installs QEMU the way a user would, then boots real
# VMs end to end through run-mac.sh.
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

# shellcheck source=tests/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_os Linux

RUN_LOG="${TMPDIR:-/tmp}/qemumac-ci-run.log"

cleanup() {
    pkill -f 'qemu-system-' 2>/dev/null || true
    rm -rf vms/ci_m68k vms/ci_ppc
}
trap cleanup EXIT

# Write a throwaway VM config and echo its path.
make_config() {
    local name="$1" arch="$2"
    mkdir -p "vms/${name}"
    if [[ "$arch" == "m68k" ]]; then
        cat > "vms/${name}/${name}.conf" <<CONF
ARCH="m68k"
MACHINE_TYPE="q800"
RAM_SIZE="128M"
HD_SIZE="512M"
PRAM_FILE="vms/${name}/pram.img"
HD_IMAGE="vms/${name}/hdd.qcow2"
MAC_ADDRESS="08:00:07:c1:c1:01"
HD_SCSI_ID=6
CD_SCSI_ID=3
SHARED_SCSI_ID=4
DISPLAY_RES="800x600x8"
CONF
    else
        cat > "vms/${name}/${name}.conf" <<CONF
ARCH="ppc"
MACHINE_TYPE="mac99"
RAM_SIZE="512M"
HD_SIZE="512M"
HD_IMAGE="vms/${name}/hdd.qcow2"
MAC_ADDRESS="08:00:07:c1:c1:02"
DISPLAY_RES="1024x768x32"
CONF
    fi
    echo "vms/${name}/${name}.conf"
}

# Launch through run-mac.sh and report whether QEMU is still alive after it
# has had time to start. A blank disk is fine - we are testing the launcher,
# not the guest OS.
boot_vm() {
    local conf="$1" arch="$2"
    xvfb-run -a ./run-mac.sh --config "$conf" > "$RUN_LOG" 2>&1 &
    sleep 25
    pgrep -f "qemu-system-${arch}" >/dev/null
}

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
command -v xvfb-run >/dev/null || fail "xvfb-run not installed"

# ---------------------------------------------------------------------------

step "Boot a 68k VM end to end through run-mac.sh"
conf=$(make_config ci_m68k m68k)

# The first attempt deliberately lets run-mac.sh fetch the ROM itself, so the
# real download path is exercised.
rom_kind=real
if ! boot_vm "$conf" m68k; then
    if [[ ! -f roms/800.ROM ]] && grep -q "Download failed" "$RUN_LOG"; then
        tail -3 "$RUN_LOG"
        rom_kind=$(ensure_rom)      # warns and falls back to a placeholder
        boot_vm "$conf" m68k || { cat "$RUN_LOG"; fail "68k VM did not start"; }
    else
        cat "$RUN_LOG"
        fail "68k VM did not start"
    fi
fi

cmdline=$(pgrep -af qemu-system-m68k | head -1)
echo "  ${cmdline}"
case "$cmdline" in *"-display sdl"*) ;; *) fail "expected the SDL backend on Linux" ;; esac
case "$cmdline" in *"audiodev="*) ;;   *) fail "no audiodev - a soundless host segfaults without one" ;; esac
case "$cmdline" in *"-bios roms/800.ROM"*) ;; *) fail "the Quadra ROM was not passed" ;; esac
pkill -f qemu-system-m68k || true

[[ -f roms/800.ROM ]]           || fail "ROM was not downloaded"
[[ -f vms/ci_m68k/hdd.qcow2 ]]  || fail "disk image was not created"
[[ -f vms/ci_m68k/pram.img ]]   || fail "PRAM file was not created"
[[ -f shared/shared-disk.img ]] || fail "shared disk was not created"

# PRAM is guest state once QEMU starts: the Quadra ROM rewrites offset 120
# within about three seconds of boot, so the patched RefNum cannot be asserted
# after a real run. The patch itself is covered by the unit suite.
size=$(wc -c < vms/ci_m68k/pram.img | tr -d ' ')
[[ "$size" == "256" ]] || fail "expected a 256-byte PRAM image, got ${size}"
echo "68k: SDL, audiodev, ROM, disk, PRAM and shared disk all correct"

# ---------------------------------------------------------------------------

step "Boot a PowerPC VM end to end through run-mac.sh"
# PPC needs no ROM (OpenBIOS is built in), so this also proves the launcher
# works when the ROM path is skipped entirely.
conf=$(make_config ci_ppc ppc)
boot_vm "$conf" ppc || { cat "$RUN_LOG"; fail "PPC VM did not start"; }

cmdline=$(pgrep -af qemu-system-ppc | head -1)
echo "  ${cmdline}"
case "$cmdline" in *"-display sdl"*) ;; *) fail "expected the SDL backend on Linux" ;; esac
case "$cmdline" in *"mac99,via=pmu"*) ;; *) fail "expected the mac99 machine with the PMU" ;; esac
case "$cmdline" in *"bootindex="*) ;;   *) fail "PPC boot order was not set" ;; esac
case "$cmdline" in *"800.ROM"*) fail "PPC must not require a ROM" ;; *) ;; esac
pkill -f qemu-system-ppc || true
[[ -f vms/ci_ppc/hdd.qcow2 ]] || fail "PPC disk image was not created"
echo "ppc: SDL, mac99, bootindex and disk all correct"

# ---------------------------------------------------------------------------

step "The guest actually executes and draws"
if [[ "$rom_kind" == "real" ]]; then
    assert_guest_draws qemu-system-m68k
else
    warn "only a placeholder ROM is available - guest execution was NOT verified"
fi

# ---------------------------------------------------------------------------

step "Negative control"
if [[ "$rom_kind" == "real" ]]; then
    assert_rejects_bad_device qemu-system-m68k
else
    warn "only a placeholder ROM is available - the negative control was NOT run"
fi

printf '\nLinux integration: OK\n'
