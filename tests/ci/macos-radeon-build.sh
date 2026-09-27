#!/usr/bin/env bash
#
# Build QEMU with the ATI Radeon 9700 through install-deps.sh's macOS-only
# third route, then check the result against real QEMU:
#   - the build has the Radeon and the Screamer sound chip
#   - the device's offline R300 tests pass (vertex programs, fragment
#     programs compiled by the Metal compiler, formats, rasterizer)
#   - the command line run-mac.sh builds for a DISPLAY_GPU="radeon9700" VM
#     boots on it, and the Radeon draws the Open Firmware screen
#
# The source build takes tens of minutes, so CI runs it on demand and weekly.
#
# Usage: ./tests/ci/macos-radeon-build.sh
#
set -Eeuo pipefail

# shellcheck source=tests/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_os Darwin

QEMU="qemu-install/bin/qemu-system-ppc"
REC_DIR=""

# No pkill: the test's QEMU runs in the foreground and quits itself, and a
# pattern match would also kill a VM the user has running from the same build.
cleanup() {
    [[ -n "$REC_DIR" ]] && rm -rf "$REC_DIR"
    rm -rf vms/ci_radeon
}
trap cleanup EXIT

step "Build the Radeon QEMU from source"
# '3' selects the Radeon source build, then '1' installs into ./qemu-install.
printf '3\n1\n' | ./install-deps.sh

step "The build has the Radeon and the Screamer"
"$QEMU" --version | head -1
devices=$("$QEMU" -device help 2>&1 || true)
printf '%s' "$devices" | grep -q '"ati-radeon-9700"' \
    || fail "qemu-system-ppc has no ati-radeon-9700"
props=$("$QEMU" -device screamer,help 2>&1 || true)
printf '%s' "$props" | grep -q "audiodev=" \
    || fail "qemu-system-ppc has no Screamer sound chip"
echo "  ati-radeon-9700 and screamer present"

step "The R300 offline tests pass"
sh qemu-source/tests/r300/run.sh

step "run-mac.sh's Radeon command line boots and the card draws"
mkdir -p vms/ci_radeon
cat > vms/ci_radeon/ci_radeon.conf <<'CONF'
ARCH="ppc"
MACHINE_TYPE="mac99"
RAM_SIZE="512M"
HD_SIZE="1G"
HD_IMAGE="vms/ci_radeon/hdd.qcow2"
MAC_ADDRESS="08:00:07:c1:c1:09"
DISPLAY_GPU="radeon9700"
CONF

# Record the argv run-mac.sh builds, without launching: a wrapper that passes
# version and help probes to the real QEMU and prints anything else.
REC_DIR=$(mktemp -d)
mkdir -p "$REC_DIR/bin"
cat > "$REC_DIR/bin/qemu-system-ppc" <<WRAP
#!/bin/sh
for a in "\$@"; do
    case "\$a" in --version|help|*,help) exec "$PWD/$QEMU" "\$@" ;; esac
done
printf '%s\n' "\$@"
WRAP
chmod +x "$REC_DIR/bin/qemu-system-ppc"
ln -s "$PWD/qemu-install/bin/qemu-img" "$REC_DIR/bin/qemu-img"

argv_file="$REC_DIR/argv"
QEMUMAC_QEMU_INSTALL_DIR="$REC_DIR" ./run-mac.sh --config vms/ci_radeon/ci_radeon.conf \
    > "$argv_file" 2>/dev/null || fail "run-mac.sh did not build a command line"
grep -q "ati-radeon-9700" "$argv_file" || { cat "$argv_file"; fail "no Radeon on the command line"; }

# Same argv, with the Cocoa window swapped for no display and a monitor, so a
# runner without a window server can boot it and take a screenshot.
args=()
skip=false
while IFS= read -r a; do
    if [[ "$skip" == true ]]; then skip=false; continue; fi
    if [[ "$a" == "-display" ]]; then skip=true; continue; fi
    args+=("$a")
done < "$argv_file"

shot="${TMPDIR:-/tmp}/qemumac-radeon.ppm"
rm -f "$shot"
( sleep 25; printf 'screendump %s\nquit\n' "$shot" ) | \
    "$QEMU" "${args[@]}" -display none -monitor stdio >/dev/null 2>&1 || true

[[ -s "$shot" ]] || fail "no framebuffer dump - the Radeon VM did not run"
distinct=$(od -An -v -tx1 "$shot" | sort -u | wc -l | tr -d ' ')
echo "  framebuffer: $(wc -c < "$shot" | tr -d ' ') bytes, ${distinct} distinct rows"
[[ "$distinct" -gt 20 ]] \
    || fail "framebuffer looks blank (${distinct} distinct rows) - the Radeon did not draw"
rm -f "$shot"

printf '\nmacOS Radeon build: OK\n'
