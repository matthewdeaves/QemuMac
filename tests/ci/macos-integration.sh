#!/usr/bin/env bash
#
# macOS integration test: installs QEMU through install-deps.sh's Homebrew
# path, then checks the resulting build against real QEMU.
#
# The unit suite stubs QEMU and never runs brew, so a wrong formula name or a
# broken feature probe would only surface on a user's machine.
#
# run-mac.sh itself is deliberately not launched here: it selects the Cocoa
# display, which needs a window server that a CI runner may not provide. The
# macOS launcher path is covered by the unit suite and by interactive use.
#
# Usage: ./tests/ci/macos-integration.sh
#

set -Eeuo pipefail

# shellcheck source=tests/ci/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_os Darwin

# ---------------------------------------------------------------------------

step "Install QEMU through install-deps.sh (Homebrew path)"
# '1' selects the package manager rather than a source build.
printf '1\n' | ./install-deps.sh

step "Both QEMU targets and the runtime tools are present"
qemu-system-m68k --version | head -1
qemu-system-ppc --version | head -1
qemu-img --version | head -1
command -v jq curl unzip >/dev/null || fail "runtime dependencies missing"
command -v hmount >/dev/null || fail "hfsutils missing - mount-shared.sh needs it on macOS"

step "The Quadra framebuffer accepts the modes the docs promise"
# README states 640x480 and 800x600 support 24-bit, 1152x870 does not. If that
# ever stops being true the documented DISPLAY_RES values become wrong.
probe_mode() {
    local mode="$1" out
    out=$(qemu-system-m68k -M q800 -g "$mode" -display none -bios /nonexistent 2>&1 || true)
    ! printf '%s' "$out" | grep -q "unknown display mode"
}
for mode in 640x480x24 800x600x24 1152x870x8; do
    probe_mode "$mode" || fail "q800 rejected ${mode}, which the docs list as valid"
    echo "  ${mode} accepted"
done
if probe_mode 1152x870x24; then
    warn "1152x870x24 is now accepted - the docs say it is not; they may need updating"
else
    echo "  1152x870x24 correctly rejected"
fi

step "Quadra 800 audio is available in this build"
qemu-system-m68k -M q800,help 2>&1 | grep -q audiodev \
    || fail "this QEMU has no q800 audiodev - run-mac.sh's audio selection assumes it"
echo "  audiodev supported"

step "The guest actually executes and draws"
rom_kind=$(ensure_rom)
if [[ "$rom_kind" == "real" ]]; then
    assert_guest_draws qemu-system-m68k

    step "Negative control"
    assert_rejects_bad_device qemu-system-m68k
else
    warn "only a placeholder ROM is available - guest execution was NOT verified"
fi

printf '\nmacOS integration: OK\n'
