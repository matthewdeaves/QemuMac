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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

TMP="${TMPDIR:-/tmp}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "skip: this test targets macOS (host is $(uname -s))"
    exit 0
fi

fail() { echo "::error::$1"; exit 1; }
warn() { echo "::warning::$1"; }
step() { printf '\n=== %s ===\n' "$1"; }

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
# Proves QEMU emulates rather than merely starting. Needs the real ROM.
if [[ ! -f roms/800.ROM ]]; then
    url=$(jq -r '.roms.quadra800.url' iso/software-database.json)
    md5_want=$(jq -r '.roms.quadra800.md5' iso/software-database.json)
    mkdir -p roms
    if curl --fail -sL --retry 3 --retry-delay 2 -o roms/800.ROM "$url"; then
        md5_got=$(md5 -q roms/800.ROM)
        [[ "$md5_got" == "$md5_want" ]] \
            || fail "ROM checksum mismatch: expected ${md5_want}, got ${md5_got}"
        echo "  ROM downloaded and verified"
    else
        rm -f roms/800.ROM
        warn "ROM download failed (third-party archive) - guest execution NOT verified"
    fi
fi

if [[ -f roms/800.ROM ]]; then
    shot="${TMP}/qemumac-screen.ppm"
    rm -f "$shot"
    ( sleep 20; printf 'screendump %s\nquit\n' "$shot" ) | \
        qemu-system-m68k -M q800,audiodev=audio0 -audiodev none,id=audio0 \
            -m 128M -g 800x600x8 -bios roms/800.ROM \
            -display none -monitor stdio >/dev/null 2>&1 || true

    [[ -s "$shot" ]] || fail "no framebuffer dump - the guest did not run"
    distinct=$(od -An -v -tx1 "$shot" | sort -u | wc -l | tr -d ' ')
    echo "  framebuffer: $(wc -c < "$shot" | tr -d ' ') bytes, ${distinct} distinct rows"
    [[ "$distinct" -gt 20 ]] \
        || fail "framebuffer looks blank (${distinct} distinct rows) - the guest did not draw"
    echo "  the Quadra ROM booted and rendered on macOS"
    rm -f "$shot"

    step "Negative control"
    out=$(qemu-system-m68k -M q800,audiodev=audio0 -audiodev none,id=audio0 \
            -m 128M -display none -bios roms/800.ROM \
            -device definitely-not-a-real-device 2>&1 || true)
    echo "$out" | tail -1
    echo "$out" | grep -q "is not a valid device model name" \
        || fail "negative control did not trip - these checks may be vacuous"
fi

printf '\nmacOS integration: OK\n'
