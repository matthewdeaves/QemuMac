#!/usr/bin/env bash
#
# Shared helpers for the tests/ci/ integration scripts.
#
# Sourced, not executed. Every script here runs from the repo root, reports
# through the same ::error::/::warning:: annotations (which GitHub renders and
# a terminal simply prints), and several need the same two proofs: that the
# guest really executes, and that the checks are capable of failing.
#

# Repo root, so callers can source this and immediately be in the right place.
CI_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$CI_REPO_ROOT" || exit 1

fail() { echo "::error::$1"; exit 1; }
warn() { echo "::warning::$1"; }
step() { printf '\n=== %s ===\n' "$1"; }

# Exit 0 (a pass, not a failure) when this script does not apply to the host.
require_os() {
    local want="$1"
    if [[ "$(uname -s)" != "$want" ]]; then
        echo "skip: this test targets ${want} (host is $(uname -s))"
        exit 0
    fi
}

# Make sure roms/800.ROM exists. Echoes "real" if it is the genuine ROM and
# "placeholder" if the download failed and a zero-filled stand-in was made -
# a placeholder cannot boot, so callers must not assert guest behaviour with
# one. archive.org is a third party and answers 500 under load; that must not
# fail a build, but it must not silently look like coverage either.
ensure_rom() {
    if [[ -f roms/800.ROM ]]; then
        echo real
        return 0
    fi

    local url md5_want md5_got
    url=$(jq -r '.roms.quadra800.url' iso/software-database.json)
    md5_want=$(jq -r '.roms.quadra800.md5' iso/software-database.json)
    mkdir -p roms

    if curl --fail -sL --retry 3 --retry-delay 2 -o roms/800.ROM "$url"; then
        md5_got=$(compute_ci_md5 roms/800.ROM)
        if [[ "$md5_got" != "$md5_want" ]]; then
            rm -f roms/800.ROM
            fail "ROM checksum mismatch: expected ${md5_want}, got ${md5_got}"
        fi
        echo real
        return 0
    fi

    warn "ROM download failed (third-party archive) - the download path was NOT exercised"
    dd if=/dev/zero of=roms/800.ROM bs=1024 count=1024 2>/dev/null
    echo placeholder
}

# md5 digest, GNU or BSD. lib/common.sh has compute_md5, but these scripts
# deliberately avoid sourcing the code under test.
compute_ci_md5() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$1" | awk '{print $1}'
    else
        md5 -q "$1"
    fi
}

# Prove QEMU emulates rather than merely starting: drive the monitor to dump
# the framebuffer once the ROM has had time to boot, then check the image is
# not a uniform blank. A Quadra with no bootable disk still draws a flashing
# floppy icon, which is plenty. Needs the real ROM.
assert_guest_draws() {
    local qemu="$1"
    local shot="${TMPDIR:-/tmp}/qemumac-screen.ppm"
    rm -f "$shot"

    ( sleep 20; printf 'screendump %s\nquit\n' "$shot" ) | \
        "$qemu" -M q800,audiodev=audio0 -audiodev none,id=audio0 \
            -m 128M -g 800x600x8 -bios roms/800.ROM \
            -display none -monitor stdio >/dev/null 2>&1 || true

    [[ -s "$shot" ]] || fail "no framebuffer dump - the guest did not run"

    # A blank screen has almost no distinct byte rows; a rendered one has many.
    local distinct
    distinct=$(od -An -v -tx1 "$shot" | sort -u | wc -l | tr -d ' ')
    echo "  framebuffer: $(wc -c < "$shot" | tr -d ' ') bytes, ${distinct} distinct rows"
    [[ "$distinct" -gt 20 ]] \
        || fail "framebuffer looks blank (${distinct} distinct rows) - the guest did not draw"
    rm -f "$shot"
    echo "  the Quadra ROM booted and rendered"
}

# The checks above must be capable of failing. QEMU validates -device only
# after loading the ROM, so this needs the real ROM; and the null audiodev is
# required for the same reason run-mac.sh passes one - a bare `-M q800` on a
# soundless host segfaults in the ASC backend before device validation.
assert_rejects_bad_device() {
    local qemu="$1" out
    out=$("$qemu" -M q800,audiodev=audio0 -audiodev none,id=audio0 \
            -m 128M -display none -bios roms/800.ROM \
            -device definitely-not-a-real-device 2>&1 || true)
    echo "$out" | tail -1
    echo "$out" | grep -q "is not a valid device model name" \
        || fail "negative control did not trip - these checks may be vacuous"
}
