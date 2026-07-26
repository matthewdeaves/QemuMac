#!/usr/bin/env bash
#
# QemuMac test suite.
#
# These tests assert on *behaviour*, not on the text of the scripts. The core
# trick is a stub qemu-system-* on PATH that prints its own argv, so a test can
# run the real run-mac.sh end to end and assert on the command line it builds.
# Grepping the source for expected strings instead - the previous approach -
# breaks whenever a line is reworded and passes whenever a bug is introduced
# without changing the wording.
#
# Runs on macOS and Ubuntu. Usage: ./tests/run-tests.sh [name-filter]

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

FILTER="${1:-}"
TESTS_RUN=0
TESTS_FAILED=0
STUB_DIR=""
SANDBOX=""

if [[ -t 1 ]]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; N=""
fi

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

# Invoked via the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
    [[ -n "$STUB_DIR" && -d "$STUB_DIR" ]] && rm -rf "$STUB_DIR"
    [[ -n "$SANDBOX" && -d "$SANDBOX" ]] && rm -rf "$SANDBOX"
    rm -rf "$REPO_ROOT/vms/_test_"* 2>/dev/null
    return 0
}
trap cleanup EXIT

# Stub binaries that record how they were called. qemu-system-* prints its
# argv one item per line; qemu-img creates a real (tiny) file so existence
# checks behave, without allocating the configured size.
make_stubs() {
    STUB_DIR=$(mktemp -d)

    local arch
    for arch in m68k ppc; do
        cat > "$STUB_DIR/qemu-system-$arch" <<'STUB'
#!/bin/sh
# Reject display suboptions listed in QEMU_STUB_REJECT so tests can simulate
# an older QEMU that lacks them.
for a in "$@"; do
    for bad in ${QEMU_STUB_REJECT:-}; do
        case "$a" in *"$bad"*)
            echo "qemu-system: -display $a: Parameter '$bad' is unexpected" >&2
            exit 1 ;;
        esac
    done
done
printf '%s\n' "$@"
STUB
        chmod +x "$STUB_DIR/qemu-system-$arch"
    done

    cat > "$STUB_DIR/qemu-img" <<'STUB'
#!/bin/sh
# usage: qemu-img create -f FMT PATH SIZE
if [ "${1:-}" = "create" ]; then
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            -f) shift 2 ;;
            *) : > "$1"; exit 0 ;;
        esac
    done
fi
exit 0
STUB
    chmod +x "$STUB_DIR/qemu-img"
}

# Run run-mac.sh with the stubs in front of PATH; echo the QEMU argv.
run_mac() {
    PATH="$STUB_DIR:$PATH" ./run-mac.sh "$@" 2>/dev/null
}

# Run run-mac.sh and echo only its diagnostics (stderr).
# The redirection order is deliberate: 2>&1 first points stderr at the
# caller's capture, then >/dev/null discards stdout. Reversing it would
# capture stdout instead.
# shellcheck disable=SC2069
run_mac_stderr() {
    PATH="$STUB_DIR:$PATH" ./run-mac.sh "$@" 2>&1 >/dev/null
}

pass() { printf '  %s✓%s %s\n' "$G" "$N" "$1"; }
fail() {
    printf '  %s✗%s %s\n' "$R" "$N" "$1"
    [[ $# -gt 1 ]] && printf '      %s\n' "$2"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

assert_contains() {
    local haystack="$1" needle="$2" desc="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        pass "$desc"
    else
        fail "$desc" "expected to find: ${needle}"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" desc="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        fail "$desc" "did not expect: ${needle}"
    else
        pass "$desc"
    fi
}

assert_eq() {
    local actual="$1" expected="$2" desc="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc" "expected '${expected}', got '${actual}'"
    fi
}

assert_file_missing() {
    local path="$1" desc="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -e "$path" ]]; then
        fail "$desc" "${path} exists but should not"
    else
        pass "$desc"
    fi
}

suite() {
    [[ -n "$FILTER" && "$1" != *"$FILTER"* ]] && return 1
    printf '\n%s%s%s\n' "$Y" "$1" "$N"
    return 0
}

# Write a throwaway VM config and echo its path.
make_vm() {
    local name="$1"; shift
    local dir="vms/_test_${name}"
    mkdir -p "$dir"
    printf '%s\n' "$@" > "${dir}/${name}.conf"
    echo "${dir}/${name}.conf"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_m68k_args() {
    suite "m68k command line" || return 0

    local conf out
    conf=$(make_vm m68k \
        'ARCH="m68k"' 'MACHINE_TYPE="q800"' 'RAM_SIZE="128M"' 'HD_SIZE="2G"' \
        'PRAM_FILE="vms/_test_m68k/pram.img"' 'HD_IMAGE="vms/_test_m68k/hdd.qcow2"' \
        'HD_SCSI_ID=6' 'CD_SCSI_ID=3' 'SHARED_SCSI_ID=4' \
        'MAC_ADDRESS="08:00:07:aa:bb:cc"')
    out=$(run_mac --config "$conf")

    assert_contains "$out" "q800"          "uses the q800 machine type"
    assert_contains "$out" "m68040"        "uses the authentic m68040 CPU"
    assert_contains "$out" "roms/800.ROM"  "passes the Quadra ROM"
    assert_contains "$out" "1152x870x8"    "defaults to 1152x870x8"
    assert_contains "$out" "mac=08:00:07:aa:bb:cc" "uses the configured MAC address"
    assert_contains "$out" "scsi-hd,scsi-id=6,drive=hd0" "puts the hard disk on its configured SCSI ID"
    assert_not_contains "$out" "ide-hd"    "does not emit PPC IDE devices"
    assert_not_contains "$out" "7400_v2.9" "does not emit the PPC CPU"
}

test_ppc_args() {
    suite "ppc command line" || return 0

    local conf out
    conf=$(make_vm ppc \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_ppc/hdd.qcow2"' 'MAC_ADDRESS="08:00:07:dd:ee:ff"')
    out=$(run_mac --config "$conf")

    assert_contains "$out" "mac99,via=pmu" "uses mac99 with the PMU"
    assert_contains "$out" "7400_v2.9"     "uses the authentic G4 CPU"
    assert_contains "$out" "1024x768x32"   "defaults to 1024x768x32"
    assert_contains "$out" "usb-kbd"       "attaches a USB keyboard"
    assert_contains "$out" "bootindex=1"   "boots the hard disk first by default"
    assert_not_contains "$out" "scsi-hd"   "does not emit m68k SCSI devices"
    assert_not_contains "$out" "800.ROM"   "does not require a ROM file"

    out=$(run_mac --config "$conf" --iso "iso/software-database.json" --boot-from-cd)
    assert_contains "$out" "bootindex=1" "boot-from-cd reorders the boot index"
    assert_contains "$out" "ide-cd"      "attaches the ISO as an IDE CD"
}

test_display_options() {
    suite "display configuration" || return 0

    local conf out
    conf=$(make_vm disp \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_disp/hdd.qcow2"' 'DISPLAY_RES="800x600x24"')

    out=$(run_mac --config "$conf")
    assert_contains "$out" "800x600x24" "DISPLAY_RES overrides the default resolution"

    # Zoom is a Cocoa feature; only assert it where Cocoa is in play.
    if [[ "$(uname -s)" == "Darwin" ]]; then
        assert_contains "$out" "zoom-to-fit=on" "zoom-to-fit is on by default on macOS"

        echo 'DISPLAY_ZOOM=false' >> "$conf"
        out=$(run_mac --config "$conf")
        assert_not_contains "$out" "zoom-to-fit" "DISPLAY_ZOOM=false disables zoom-to-fit"

        # An older QEMU that rejects the option must still launch.
        sed -i.bak 's/DISPLAY_ZOOM=false/DISPLAY_ZOOM=true/' "$conf" && rm -f "${conf}.bak"
        out=$(QEMU_STUB_REJECT="zoom-to-fit" run_mac --config "$conf")
        assert_contains "$out" "cocoa" "still builds a Cocoa display line on older QEMU"
        assert_not_contains "$out" "zoom-to-fit" "drops zoom-to-fit when QEMU rejects it"
    else
        assert_contains "$out" "sdl" "uses the SDL display on Linux"

        echo 'DISPLAY_FULLSCREEN=true' >> "$conf"
        out=$(run_mac --config "$conf")
        assert_contains "$out" "full-screen=on" "DISPLAY_FULLSCREEN works on SDL"
    fi
}

test_first_run_is_retryable() {
    suite "first-run installer is retryable" || return 0

    # An installer key that is not in the database stands in for a failed
    # acquisition. The VM must not be left with a disk image, or it would
    # never be treated as a first run again.
    local conf out
    conf=$(make_vm retry \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_retry/hdd.qcow2"' 'DEFAULT_INSTALLER="no_such_installer"')

    out=$(run_mac_stderr --config "$conf")
    assert_contains "$out" "not found in software database" "reports the unusable installer key"

    # A bad key is a config error, not a transient one, so the run continues
    # and the user can attach media by hand.
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "vms/_test_retry/hdd.qcow2" ]]; then
        pass "creates the disk anyway for a bad installer key (manual setup)"
    else
        fail "creates the disk anyway for a bad installer key (manual setup)"
    fi

    # A download failure must leave nothing behind. Point at an unroutable
    # host so curl fails fast without touching the network.
    rm -rf vms/_test_dl
    conf=$(make_vm dl \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_dl/hdd.qcow2"' 'DEFAULT_INSTALLER="_test_unreachable"')
    cat > iso/custom-software.json <<'JSON'
{"cds":{"_test_unreachable":{"name":"Unreachable","url":"http://127.0.0.1:1/x.iso",
"filename":"x.iso","md5":null,"architectures":["ppc"],"category":"Test"}}}
JSON
    out=$(run_mac_stderr --config "$conf")
    rm -f iso/custom-software.json

    assert_contains "$out" "Download failed" "aborts on a failed download"
    assert_file_missing "vms/_test_dl/hdd.qcow2" \
        "leaves no disk image behind, so the next run retries the installer"
}

# The m68k boot device is selected by writing a SCSI RefNum into the PRAM
# image at offset 120: RefNum = ~(id + 32), big-endian, preceded by 0xffff.
# Nothing else verifies these bytes, and the value is built with printf escape
# sequences, so a formatting slip here silently boots the wrong device.
test_pram_boot_patch() {
    suite "m68k PRAM boot patch" || return 0

    local conf out pram
    conf=$(make_vm pram \
        'ARCH="m68k"' 'MACHINE_TYPE="q800"' 'RAM_SIZE="128M"' 'HD_SIZE="2G"' \
        'PRAM_FILE="vms/_test_pram/pram.img"' 'HD_IMAGE="vms/_test_pram/hdd.qcow2"' \
        'HD_SCSI_ID=6' 'CD_SCSI_ID=3' 'SHARED_SCSI_ID=4')
    pram="vms/_test_pram/pram.img"

    # Boot from hard disk (ID 6): ~(6+32) = 0xffd9
    run_mac --config "$conf" >/dev/null
    out=$(dd if="$pram" bs=1 skip=120 count=4 2>/dev/null | od -An -tx1 | tr -s ' ' | sed 's/^ //;s/ $//')
    assert_eq "$out" "ff ff ff d9" "hard-disk boot writes the RefNum for SCSI ID 6"

    # Boot from CD (ID 3): ~(3+32) = 0xffdc
    run_mac --config "$conf" --iso "iso/software-database.json" --boot-from-cd >/dev/null
    out=$(dd if="$pram" bs=1 skip=120 count=4 2>/dev/null | od -An -tx1 | tr -s ' ' | sed 's/^ //;s/ $//')
    assert_eq "$out" "ff ff ff dc" "CD boot writes the RefNum for SCSI ID 3"

    # Byte 0 must be untouched - the patch is a 4-byte splice, not a rewrite.
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$(wc -c < "$pram" | tr -d ' ')" == "256" ]]; then
        pass "PRAM image stays 256 bytes after patching"
    else
        fail "PRAM image stays 256 bytes after patching" "$(wc -c < "$pram") bytes"
    fi
}

# QEMU device strings contain commas and interpolate config values. If they
# are not quoted, a config value with whitespace splits them into separate
# arguments and QEMU rejects the command line.
test_device_args_are_single_words() {
    suite "device arguments survive word splitting" || return 0

    local conf out
    conf=$(make_vm split \
        'ARCH="m68k"' 'MACHINE_TYPE="q800"' 'RAM_SIZE="128M"' 'HD_SIZE="2G"' \
        'PRAM_FILE="vms/_test_split/pram.img"' 'HD_IMAGE="vms/_test_split/hdd.qcow2"' \
        'HD_SCSI_ID=6' 'CD_SCSI_ID=3' 'SHARED_SCSI_ID=4')

    # The stub prints one argv element per line, so a whole device string
    # appearing on its own line proves it was passed as a single argument.
    out=$(run_mac --config "$conf")
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s\n' "$out" | grep -qx 'scsi-hd,scsi-id=6,drive=hd0'; then
        pass "m68k device string is one argv element"
    else
        fail "m68k device string is one argv element" \
            "$(printf '%s\n' "$out" | grep -n 'scsi-hd' | head -2)"
    fi

    conf=$(make_vm split2 \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_split2/hdd.qcow2"')
    out=$(run_mac --config "$conf")
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s\n' "$out" | grep -qx 'ide-hd,bus=ide.0,unit=0,drive=hd0,bootindex=1'; then
        pass "ppc device string is one argv element"
    else
        fail "ppc device string is one argv element" \
            "$(printf '%s\n' "$out" | grep -n 'ide-hd' | head -2)"
    fi
}

# ShellCheck is part of the contract, not just CI decoration. Run it here when
# available so a local run catches what CI would.
test_shellcheck() {
    suite "shellcheck" || return 0

    if ! command -v shellcheck >/dev/null 2>&1; then
        printf '  %s-%s skipped (shellcheck not installed)\n' "$Y" "$N"
        return 0
    fi

    local out
    TESTS_RUN=$((TESTS_RUN + 1))
    # No excludes: intentional patterns carry inline directives instead.
    if out=$(shellcheck -S warning run-mac.sh iso-downloader.sh install-deps.sh \
                mount-shared.sh lib/common.sh tests/run-tests.sh 2>&1); then
        pass "clean at severity=warning with no blanket excludes"
    else
        fail "clean at severity=warning with no blanket excludes" "$(echo "$out" | head -12)"
    fi
}

test_arch_validation() {
    suite "config validation" || return 0

    local conf out
    conf=$(make_vm badarch 'ARCH="sparc"' 'HD_IMAGE="vms/_test_badarch/hdd.qcow2"')
    out=$(run_mac_stderr --config "$conf")
    assert_contains "$out" "unsupported ARCH" "rejects an unknown ARCH instead of falling through to PPC"

    conf=$(make_vm noarch 'HD_IMAGE="vms/_test_noarch/hdd.qcow2"')
    out=$(run_mac_stderr --config "$conf")
    assert_contains "$out" "does not set ARCH" "rejects a config with no ARCH"

    out=$(run_mac_stderr --config "vms/_test_nope/nope.conf")
    assert_contains "$out" "Config file not found" "reports a missing config file"
}

test_shared_disk_locking() {
    suite "shared disk locking" || return 0

    SANDBOX=$(mktemp -d)
    local disk="$SANDBOX/shared.img"
    : > "$disk"

    local conf out
    conf=$(make_vm lock \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_lock/hdd.qcow2"' "SHARED_DISK=\"$disk\"")

    out=$(run_mac --config "$conf")
    assert_contains "$out" "$disk" "attaches a free shared disk"

    # Hold the image open to stand in for a running VM.
    if command -v lsof >/dev/null 2>&1 || command -v fuser >/dev/null 2>&1; then
        exec 9<>"$disk"
        out=$(run_mac --config "$conf")
        assert_not_contains "$out" "$disk" "omits the shared disk while another process holds it"

        # On macOS mount-shared.sh needs hfsutils; without it the script dies
        # on the missing command before reaching its own in-use check, so the
        # assertion would be testing the wrong thing. Skip rather than
        # pretend, and let CI install hfsutils so this really does run there.
        if [[ "$(uname -s)" != "Darwin" ]] || command -v hmount >/dev/null 2>&1; then
            out=$(SHARED_DISK="$disk" ./mount-shared.sh 2>&1 || true)
            assert_contains "$out" "in use" "mount-shared.sh refuses to mount a disk that is in use"
        else
            printf '  %s-%s mount-shared.sh in-use check skipped (no hfsutils)\n' "$Y" "$N"
        fi
        exec 9>&-
    else
        printf '  %s-%s skipped (no lsof or fuser)\n' "$Y" "$N"
    fi
}

test_shared_disk_override() {
    suite "per-VM shared disk override" || return 0

    local out
    out=$(SHARED_DISK="vms/_test_nonexistent/shared.img" ./mount-shared.sh 2>&1 || true)
    assert_contains "$out" "vms/_test_nonexistent/shared.img" \
        "mount-shared.sh honours the SHARED_DISK override"
}

# mount-shared.sh had no behavioural coverage at all, which let a quoting bug
# ship: "...gid=${gid}""$SHARED_DISK" concatenates into a single argument, so
# the mount options absorbed the device path and `mount` got no device at all.
# It is Linux-only, so a macOS test run could never have caught it by running
# the script - hence stubbing the whole mount toolchain and asserting on argv.
test_mount_shared_commands() {
    suite "mount-shared.sh command construction" || return 0

    SANDBOX=$(mktemp -d)
    local disk="$SANDBOX/shared.img"
    local log="$SANDBOX/mount.argv"
    : > "$disk"

    # Linux path: uname + OSTYPE together decide detect_os.
    cat > "$STUB_DIR/uname" <<'STUB'
#!/bin/sh
[ "$1" = "-s" ] && echo Linux || /usr/bin/uname "$@"
STUB
    cat > "$STUB_DIR/mountpoint" <<'STUB'
#!/bin/sh
exit 1
STUB
    cat > "$STUB_DIR/sudo" <<'STUB'
#!/bin/sh
exec "$@"
STUB
    cat > "$STUB_DIR/mount" <<STUB
#!/bin/sh
printf '%s\n' "\$@" > "$log"
exit 0
STUB
    chmod +x "$STUB_DIR/uname" "$STUB_DIR/mountpoint" "$STUB_DIR/sudo" "$STUB_DIR/mount"

    PATH="$STUB_DIR:$PATH" OSTYPE=linux-gnu SHARED_DISK="$disk" \
        ./mount-shared.sh >/dev/null 2>&1

    local argv=""
    [[ -f "$log" ]] && argv=$(cat "$log")

    # The device must arrive as its own argument, not glued to -o options.
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s\n' "$argv" | grep -qx -- "$disk"; then
        pass "mount receives the disk image as a standalone argument"
    else
        fail "mount receives the disk image as a standalone argument" \
             "argv was: $(printf '%s' "$argv" | tr '\n' '|')"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s\n' "$argv" | grep -q "gid=[0-9]*${disk}"; then
        fail "mount options are not concatenated with the device path" \
             "argv was: $(printf '%s' "$argv" | tr '\n' '|')"
    else
        pass "mount options are not concatenated with the device path"
    fi

    assert_contains "$argv" "hfsplus" "mount tries HFS+ first"

    # uid/gid must be a single -o value, still one argument.
    TESTS_RUN=$((TESTS_RUN + 1))
    if printf '%s\n' "$argv" | grep -qxE "loop,rw,uid=[0-9]+,gid=[0-9]+"; then
        pass "mount options form one well-shaped -o argument"
    else
        fail "mount options form one well-shaped -o argument" \
             "argv was: $(printf '%s' "$argv" | tr '\n' '|')"
    fi

    rm -f "$STUB_DIR/uname" "$STUB_DIR/mountpoint" "$STUB_DIR/sudo" "$STUB_DIR/mount"
    rmdir /tmp/qemu-shared 2>/dev/null
}

# The host-side write guard is shared by mount-shared.sh and iso-downloader.sh.
# iso-downloader.sh used a plain `if disk_in_use ...`, which reads the "cannot
# tell" status 2 as false and would have written underneath a running VM.
test_shared_disk_write_guard() {
    suite "shared disk write guard" || return 0

    local sandbox out
    sandbox=$(mktemp -d)
    : > "$sandbox/disk.img"

    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c "source lib/common.sh
command_exists() { return 1; }
if shared_disk_is_writable '$sandbox/disk.img' 2>/dev/null; then echo proceed; else echo refuse; fi")
    if [[ "$out" == "proceed" ]]; then
        pass "guard proceeds (with a warning) when neither lsof nor fuser exists"
    else
        fail "guard proceeds (with a warning) when neither lsof nor fuser exists" "got '${out}'"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c "source lib/common.sh
disk_in_use() { return 0; }
if shared_disk_is_writable '$sandbox/disk.img' 2>/dev/null; then echo proceed; else echo refuse; fi")
    if [[ "$out" == "refuse" ]]; then
        pass "guard refuses while the disk is held open"
    else
        fail "guard refuses while the disk is held open" "got '${out}'"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c "source lib/common.sh
disk_in_use() { return 1; }
if shared_disk_is_writable '$sandbox/disk.img' 2>/dev/null; then echo proceed; else echo refuse; fi")
    if [[ "$out" == "proceed" ]]; then
        pass "guard proceeds when the disk is free"
    else
        fail "guard proceeds when the disk is free" "got '${out}'"
    fi

    rm -rf "$sandbox"
}

# Anything that can die() must do so before the disk image exists. The absence
# of HD_IMAGE is the only marker of "not yet installed", so a late failure
# leaves a VM that skips its installer forever and boots to a flashing disk.
test_no_disk_before_validation() {
    suite "nothing is created before validation can fail" || return 0

    local conf out
    conf=$(make_vm badiso \
        'ARCH="m68k"' 'MACHINE_TYPE="q800"' 'RAM_SIZE="128M"' 'HD_SIZE="2G"' \
        'PRAM_FILE="vms/_test_badiso/pram.img"' \
        'HD_IMAGE="vms/_test_badiso/hdd.qcow2"' \
        'HD_SCSI_ID=6' 'CD_SCSI_ID=3')

    out=$(run_mac_stderr --config "$conf" --iso "iso/_test_missing.iso")
    assert_contains "$out" "not found" "a missing --iso is rejected"
    assert_file_missing "vms/_test_badiso/hdd.qcow2" \
        "no disk image is created when the ISO is missing"
    assert_file_missing "vms/_test_badiso/pram.img" \
        "no PRAM file is created when the ISO is missing"

    # Same VM, valid media: the disk must now appear, proving the check moved
    # rather than the whole branch being skipped.
    : > "iso/_test_present.iso"
    run_mac --config "$conf" --iso "iso/_test_present.iso" >/dev/null 2>&1
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "vms/_test_badiso/hdd.qcow2" ]]; then
        pass "the disk image is still created when the ISO is valid"
    else
        fail "the disk image is still created when the ISO is valid"
    fi
    rm -f "iso/_test_present.iso"
}

# DEFAULT_INSTALLER used to overwrite CD_ISO_FILE unconditionally on a first
# run, so an explicit --iso was silently discarded and the VM booted something
# the user never asked for.
test_explicit_iso_beats_default_installer() {
    suite "explicit --iso overrides DEFAULT_INSTALLER" || return 0

    local conf out
    conf=$(make_vm isowins \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_isowins/hdd.qcow2"' \
        'DEFAULT_INSTALLER="apple_legacy_recovery"')

    : > "iso/_test_mine.iso"
    out=$(run_mac --config "$conf" --iso "iso/_test_mine.iso")
    assert_contains "$out" "iso/_test_mine.iso" "the ISO passed on the command line is attached"
    assert_not_contains "$out" "Apple Legacy Recovery" \
        "the default installer does not replace an explicit --iso"

    # And with no --iso the default installer must still be used, so the
    # override cannot have disabled first-run setup altogether.
    rm -rf vms/_test_isowins/hdd.qcow2
    out=$(run_mac_stderr --config "$conf")
    assert_contains "$out" "first-run installer" \
        "the default installer still runs when no --iso is given"

    rm -f "iso/_test_mine.iso"
}

# download_and_place_file must never report success without leaving a file at
# dest_path - run-mac.sh treats its success as "installer media is ready".
test_download_extraction_failures() {
    suite "download/extract failure handling" || return 0

    local sandbox out
    sandbox=$(mktemp -d)

    # A zip whose contents do not match the database's `filename`.
    mkdir -p "$sandbox/src"
    : > "$sandbox/src/actual-name.iso"
    (cd "$sandbox/src" && zip -q ../archive.zip actual-name.iso)

    # Drive the real function with a local file:// URL so no network is needed.
    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c "
cd '$REPO_ROOT'
source lib/common.sh
download_and_place_file 'file://$sandbox/archive.zip' '' '$sandbox/out.iso' 'wrong-name.iso'
" 2>&1)
    if [[ -f "$sandbox/out.iso" ]]; then
        fail "a zip missing the expected file does not install anything" \
             "out.iso was created anyway"
    else
        pass "a zip missing the expected file does not install anything"
    fi

    assert_contains "$out" "actual-name.iso" \
        "the error lists what the archive really contains"

    # The matching case must still work.
    TESTS_RUN=$((TESTS_RUN + 1))
    bash -c "
cd '$REPO_ROOT'
source lib/common.sh
download_and_place_file 'file://$sandbox/archive.zip' '' '$sandbox/good.iso' 'actual-name.iso'
" >/dev/null 2>&1
    if [[ -f "$sandbox/good.iso" ]]; then
        pass "a zip containing the expected file installs correctly"
    else
        fail "a zip containing the expected file installs correctly"
    fi

    rm -rf "$sandbox"
}

# An unresolved menu selection used to reach curl as the literal string
# "null", surfacing as "Could not resolve host: null".
test_downloader_guards() {
    suite "downloader input validation" || return 0

    # Strip the trailing `main "$@"` so the functions can be driven directly.
    local lib out
    lib=$(mktemp)
    sed '$d' iso-downloader.sh > "$lib"

    out=$(bash -c "set -euo pipefail
cd '$REPO_ROOT'
source '$lib'
db=\$(load_database)
download_file \"\$db\" ''" 2>&1)
    assert_contains "$out" "No item selected" "an empty selection is rejected with a clear message"
    assert_not_contains "$out" "resolve host" "an empty selection never reaches curl"

    out=$(bash -c "set -euo pipefail
cd '$REPO_ROOT'
source '$lib'
db=\$(load_database)
download_file \"\$db\" \"\$(printf 'bogus_key\tBogus\tdesc\tcd')\"" 2>&1)
    assert_contains "$out" "not in the software database" "an unknown key is reported by name"
    assert_not_contains "$out" "resolve host" "an unknown key never reaches curl"

    rm -f "$lib"
}

# The Linux shared-disk delivery path had no coverage at all. It calls
# mount-shared.sh by path (not via PATH), so it is exercised in a sandbox repo
# whose mount-shared.sh is a recording stub. That covers the orchestration and
# both failure paths on any host; the real loop mount is a separate CI job,
# since it needs root and kernel hfsplus.
test_shared_delivery_linux() {
    suite "Linux shared-disk delivery" || return 0

    local sandbox mountpoint out
    sandbox=$(mktemp -d)
    mountpoint="$sandbox/mnt"
    mkdir -p "$sandbox/lib" "$mountpoint"
    cp lib/common.sh "$sandbox/lib/common.sh"
    sed '$d' iso-downloader.sh > "$sandbox/iso-downloader.sh"

    # Recording stub: logs how it was called and succeeds.
    cat > "$sandbox/mount-shared.sh" <<STUB
#!/bin/sh
echo "mount-shared.sh \$*" >> "$sandbox/calls.log"
exit 0
STUB
    chmod +x "$sandbox/mount-shared.sh"

    cat > "$sandbox/runner.sh" <<STUB
source "$sandbox/iso-downloader.sh"
SHARED_MOUNT_POINT="$mountpoint"
_handle_shared_delivery_linux "\$1" "\$2"
STUB

    # Happy path: file is delivered, disk mounted then released.
    printf 'payload' > "$sandbox/payload.bin"
    out=$(bash "$sandbox/runner.sh" "$sandbox/payload.bin" "MyApp" 2>&1)

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "$mountpoint/MyApp" ]]; then
        pass "the downloaded file is delivered onto the shared disk"
    else
        fail "the downloaded file is delivered onto the shared disk" "$out"
    fi

    assert_contains "$(cat "$sandbox/calls.log")" "mount-shared.sh -u" \
        "the shared disk is released after delivery"
    assert_file_missing "$sandbox/payload.bin" "the temp file is not left behind"

    # Mount failure: must not leave the temp file, and must not claim success.
    cat > "$sandbox/mount-shared.sh" <<'STUB'
#!/bin/sh
[ "$1" = "-u" ] && exit 0
exit 1
STUB
    chmod +x "$sandbox/mount-shared.sh"
    printf 'payload' > "$sandbox/payload2.bin"
    out=$(bash "$sandbox/runner.sh" "$sandbox/payload2.bin" "Other" 2>&1)

    assert_contains "$out" "Failed to mount" "a failed mount is reported"
    assert_not_contains "$out" "Successfully delivered" "a failed mount does not report success"
    assert_file_missing "$sandbox/payload2.bin" "the temp file is cleaned up when the mount fails"
    assert_file_missing "$mountpoint/Other" "nothing is delivered when the mount fails"

    rm -rf "$sandbox"
}

test_script_hygiene() {
    suite "script hygiene" || return 0

    local f out
    for f in run-mac.sh install-deps.sh iso-downloader.sh mount-shared.sh lib/common.sh; do
        TESTS_RUN=$((TESTS_RUN + 1))
        if out=$(/bin/bash -n "$f" 2>&1); then
            pass "$f parses under the system bash ($(/bin/bash --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1))"
        else
            fail "$f parses under the system bash" "$out"
        fi
    done

    # bash 3.2 is what macOS ships, so bash 4+ only syntax must not appear.
    # The test suite is scanned too: `source <(...)` slipped in here and failed
    # only on macOS CI, because a dev box with Homebrew bash 5 first on PATH
    # runs everything under bash 5 and never exercises 3.2.
    # Now that tests/ is in scope these greps can match their own pattern
    # strings and comments, so drop comment lines and the checker lines here.
    local scan_files="*.sh lib/*.sh tests/*.sh"
    local self='grep -nE|:[[:space:]]*#'

    TESTS_RUN=$((TESTS_RUN + 1))
    # shellcheck disable=SC2086
    if out=$(grep -nE 'local -n|declare -n|mapfile|readarray' -- $scan_files 2>/dev/null \
             | grep -vE "$self"); then
        fail "no bash 4+ only constructs" "$out"
    else
        pass "no bash 4+ only constructs"
    fi

    # `source <(cmd)` / `. <(cmd)` silently defines nothing under bash 3.2:
    # the process substitution is gone before source reads it. Redirect to a
    # temp file and source that instead.
    TESTS_RUN=$((TESTS_RUN + 1))
    # shellcheck disable=SC2086
    if out=$(grep -nE '(^|[^a-zA-Z_])(source|\.)[[:space:]]+<\(' -- $scan_files 2>/dev/null \
             | grep -vE "$self"); then
        fail "no process-substitution sourcing - unsupported in bash 3.2" "$out"
    else
        pass "no process-substitution sourcing - unsupported in bash 3.2"
    fi

    # Every VM ships a distinct MAC, or guests collide on the same network.
    TESTS_RUN=$((TESTS_RUN + 1))
    local total unique
    total=$(grep -h '^MAC_ADDRESS=' vms/*/*.conf 2>/dev/null | wc -l | tr -d ' ')
    unique=$(grep -h '^MAC_ADDRESS=' vms/*/*.conf 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [[ "$total" == "$unique" && "$total" -gt 0 ]]; then
        pass "all ${total} VM configs have unique MAC addresses"
    else
        fail "all VM configs have unique MAC addresses" "${total} configs, ${unique} distinct"
    fi

    # Every shipped config must name an architecture run-mac.sh understands.
    TESTS_RUN=$((TESTS_RUN + 1))
    local bad=""
    for f in vms/*/*.conf; do
        grep -qE '^ARCH="(m68k|ppc)"' "$f" || bad="${bad} ${f}"
    done
    if [[ -z "$bad" ]]; then
        pass "all VM configs declare a supported ARCH"
    else
        fail "all VM configs declare a supported ARCH" "offending:${bad}"
    fi
}

test_database_integrity() {
    suite "software database" || return 0

    TESTS_RUN=$((TESTS_RUN + 1))
    if jq empty iso/software-database.json 2>/dev/null; then
        pass "software-database.json is valid JSON"
    else
        fail "software-database.json is valid JSON"
    fi

    # Every default installer referenced by a shipped VM must resolve, or the
    # VM's first run fails.
    local f key
    for f in vms/*/*.conf; do
        key=$(grep '^DEFAULT_INSTALLER=' "$f" 2>/dev/null | cut -d'"' -f2)
        [[ -z "$key" ]] && continue
        TESTS_RUN=$((TESTS_RUN + 1))
        if jq -e --arg k "$key" '.cds[$k]' iso/software-database.json >/dev/null 2>&1; then
            pass "$(basename "$f"): DEFAULT_INSTALLER '${key}' exists in the database"
        else
            fail "$(basename "$f"): DEFAULT_INSTALLER '${key}' exists in the database"
        fi
    done

    # Every shipped entry carries a checksum. Several are served over plaintext
    # HTTP, so the digest is the only integrity check there is; the ROM in
    # particular is auto-downloaded on every m68k first run. A missing or
    # malformed digest means silent acceptance of a corrupt or tampered file.
    # (download_file_to_temp still warns at runtime for user-added entries in
    # custom-software.json, which this test cannot see.)
    TESTS_RUN=$((TESTS_RUN + 1))
    local bad_md5
    bad_md5=$(jq -r '(.cds, .roms) | to_entries[]
        | select((.value.md5 | type) != "string"
              or (.value.md5 | test("^[0-9a-f]{32}$") | not))
        | "\(.key)=\(.value.md5)"' iso/software-database.json 2>/dev/null)
    if [[ -z "$bad_md5" ]]; then
        pass "every database entry has a well-formed 32-char hex md5"
    else
        fail "every database entry has a well-formed 32-char hex md5" "$bad_md5"
    fi

    # Every entry needs the fields the downloader dereferences unconditionally.
    TESTS_RUN=$((TESTS_RUN + 1))
    local incomplete
    incomplete=$(jq -r '(.cds, .roms) | to_entries[]
        | select((.value | has("url") | not)
              or (.value | has("filename") | not)
              or (.value | has("name") | not))
        | .key' iso/software-database.json 2>/dev/null)
    if [[ -z "$incomplete" ]]; then
        pass "every database entry has url, filename and name"
    else
        fail "every database entry has url, filename and name" "$incomplete"
    fi

    # Installers must declare the architectures they support, or the
    # create-config filter silently offers nothing.
    TESTS_RUN=$((TESTS_RUN + 1))
    local missing
    missing=$(jq -r '.cds | to_entries[] | select(.value.architectures == null) | .key' \
        iso/software-database.json 2>/dev/null)
    if [[ -z "$missing" ]]; then
        pass "every installer declares its architectures"
    else
        fail "every installer declares its architectures" "missing: $(echo "$missing" | tr '\n' ' ')"
    fi
}

# GNU coreutils and BSD/macOS userland differ in ways that fail silently or
# only at runtime. Each pattern below is a construct that works on one and
# breaks on the other, so it must not appear in the scripts.
test_gnu_bsd_portability() {
    suite "GNU/BSD userland portability" || return 0

    local scripts="run-mac.sh iso-downloader.sh install-deps.sh mount-shared.sh lib/common.sh"
    local desc pattern hits

    # Format: description<TAB>extended-regex
    while IFS=$'\t' read -r desc pattern; do
        [[ -z "$desc" ]] && continue
        TESTS_RUN=$((TESTS_RUN + 1))
        # shellcheck disable=SC2086
        hits=$(grep -nE "$pattern" $scripts 2>/dev/null | grep -v '^\s*#' || true)
        if [[ -z "$hits" ]]; then
            pass "$desc"
        else
            fail "$desc" "$(echo "$hits" | head -3)"
        fi
    done <<'PATTERNS'
sed -i takes a mandatory suffix on BSD	sed +-i[[:space:]]
readlink -f is GNU only (absent on older macOS)	readlink[[:space:]]+-f
stat -c is GNU; BSD uses stat -f	stat[[:space:]]+-c
grep -P (PCRE) is unavailable in BSD grep	grep[[:space:]]+(-[a-zA-Z]*P|--perl-regexp)
date -d is GNU; BSD uses date -v	date[[:space:]]+-d[[:space:]]
find -printf is GNU only	find[[:space:]].*-printf
cp --parents is GNU only	cp[[:space:]].*--parents
sort -h is GNU only	sort[[:space:]]+-h[[:space:]]
seq is absent on some minimal systems	[^a-z]seq[[:space:]]+[0-9]
realpath is not on stock macOS	[^a-z_]realpath[[:space:]]
timeout is GNU coreutils and absent on stock macOS	(^|[|;(&][[:space:]]*)timeout[[:space:]]+[0-9]
xargs -r is GNU only (BSD xargs skips empty input already)	xargs[[:space:]]+(-[a-zA-Z]*r|--no-run-if-empty)
PATTERNS

    # md5sum is coreutils; stock macOS provides md5. Only compute_md5 (in
    # lib/common.sh) may invoke either directly - everything else must route
    # through it, or one platform silently loses checksum verification.
    TESTS_RUN=$((TESTS_RUN + 1))
    # Anchored to command position so the tool names can still be mentioned
    # in comments and error messages.
    hits=$(grep -nE '(^[[:space:]]*|[|;(&][[:space:]]*|\$\()(md5sum|md5)[[:space:]]+[-"$/]' \
        run-mac.sh iso-downloader.sh install-deps.sh mount-shared.sh 2>/dev/null || true)
    if [[ -z "$hits" ]]; then
        pass "md5 is only invoked through compute_md5"
    else
        fail "md5 is only invoked through compute_md5" "$(echo "$hits" | head -3)"
    fi
}

# The OS branch that does not match the host still has to be exercised. A stub
# uname on PATH makes detect_os report Linux, which drives run-mac.sh down the
# SDL path even on a macOS developer machine (and vice versa is covered by CI).
test_cross_platform_branches() {
    suite "cross-platform display branches" || return 0

    local conf out
    conf=$(make_vm xplat \
        'ARCH="ppc"' 'MACHINE_TYPE="mac99"' 'RAM_SIZE="512M"' 'HD_SIZE="10G"' \
        'HD_IMAGE="vms/_test_xplat/hdd.qcow2"')

    cat > "$STUB_DIR/uname" <<'STUB'
#!/bin/sh
[ "$1" = "-s" ] && echo Linux || /usr/bin/uname "$@"
STUB
    chmod +x "$STUB_DIR/uname"

    out=$(OSTYPE=linux-gnu run_mac --config "$conf")
    assert_contains "$out" "sdl"           "Linux branch selects the SDL display"
    assert_contains "$out" "grab-mod=rctrl" "Linux branch sets the mouse-grab modifier"
    assert_not_contains "$out" "cocoa"     "Linux branch never emits Cocoa options"
    assert_not_contains "$out" "zoom-to-fit" "Linux branch never emits Cocoa-only zoom options"

    echo 'DISPLAY_FULLSCREEN=true' >> "$conf"
    out=$(OSTYPE=linux-gnu run_mac --config "$conf")
    assert_contains "$out" "full-screen=on" "DISPLAY_FULLSCREEN applies on the SDL branch"

    # DISPLAY_ZOOM is Cocoa-only and must be inert, not an invalid SDL option.
    echo 'DISPLAY_ZOOM=true' >> "$conf"
    out=$(OSTYPE=linux-gnu run_mac --config "$conf")
    assert_not_contains "$out" "zoom-to-fit" "DISPLAY_ZOOM is ignored on SDL rather than passed through"

    rm -f "$STUB_DIR/uname"

    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c 'source lib/common.sh; OSTYPE=darwin24 detect_os')
    if [[ "$out" == "macos" ]]; then
        pass "detect_os identifies macOS from OSTYPE"
    else
        fail "detect_os identifies macOS from OSTYPE" "got '${out}'"
    fi
}

# The md5 helper must work whichever tool the host provides. Shadowing PATH
# lets both branches be exercised on a single machine.
test_md5_fallbacks() {
    suite "checksum tool fallbacks" || return 0

    local sandbox out
    sandbox=$(mktemp -d)

    # Only md5sum available (the Linux case)
    mkdir -p "$sandbox/gnu"
    if command -v md5sum >/dev/null 2>&1; then
        ln -sf "$(command -v md5sum)" "$sandbox/gnu/md5sum"
        out=$(PATH="$sandbox/gnu:/usr/bin:/bin" bash -c 'source lib/common.sh; compute_md5 /dev/null')
        assert_eq "$out" "d41d8cd98f00b204e9800998ecf8427e" "compute_md5 works with only md5sum present"
    fi

    # Only md5 available (the stock-macOS case)
    mkdir -p "$sandbox/bsd"
    if command -v md5 >/dev/null 2>&1; then
        cat > "$sandbox/bsd/md5" <<STUB
#!/bin/sh
exec $(command -v md5) "\$@"
STUB
        chmod +x "$sandbox/bsd/md5"
        cat > "$sandbox/bsd/runner.sh" <<'STUB'
source lib/common.sh
# hide md5sum so the BSD branch is taken
md5sum() { return 127; }
command_exists() { [ "$1" != "md5sum" ] && command -v "$1" >/dev/null 2>&1; }
compute_md5 /dev/null
STUB
        out=$(bash "$sandbox/bsd/runner.sh")
        assert_eq "$out" "d41d8cd98f00b204e9800998ecf8427e" "compute_md5 falls back to BSD md5 -q"
    fi

    # Neither available: must report failure, not a bogus digest
    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c 'source lib/common.sh
command_exists() { return 1; }
if compute_md5 /dev/null >/dev/null 2>&1; then echo unexpected-success; else echo failed; fi')
    if [[ "$out" == "failed" ]]; then
        pass "compute_md5 reports failure when no checksum tool exists"
    else
        fail "compute_md5 reports failure when no checksum tool exists" "got '${out}'"
    fi

    # disk_in_use must say "unknown" (2), not "free", without lsof/fuser -
    # guessing "free" here would let two writers corrupt the shared disk.
    TESTS_RUN=$((TESTS_RUN + 1))
    : > "$sandbox/disk.img"
    out=$(bash -c "source lib/common.sh
command_exists() { return 1; }
disk_in_use '$sandbox/disk.img'; echo \$?")
    if [[ "$out" == "2" ]]; then
        pass "disk_in_use reports 'unknown' when neither lsof nor fuser exists"
    else
        fail "disk_in_use reports 'unknown' when neither lsof nor fuser exists" "got '${out}'"
    fi

    rm -rf "$sandbox"
}

# The installer must resolve the newest stable QEMU on either platform, and
# must not regress to the old pattern that skipped every bugfix release.
test_installer_logic() {
    suite "install-deps.sh logic" || return 0

    # Load the functions without executing main(). Via a temp file, not
    # `source <(...)`: process substitution with source silently fails under
    # bash 3.2, which is what macOS ships and what CI's macOS runner uses.
    # Every version_at_least call then became "command not found" - i.e. false
    # - and the assertion failed only on macOS CI, never on a dev box with
    # Homebrew bash 5 first on PATH.
    local lib out
    lib=$(mktemp)
    sed '$d' install-deps.sh > "$lib"
    local loader="source '$lib'"

    out=$(bash -c "$loader
for pair in '11.0.3 8.2' '10.1.0 8.2' '8.2 8.2' '8.0 8.2' '7.2 8.2'; do
  set -- \$pair
  if version_at_least \$1 \$2; then echo \"\$1:yes\"; else echo \"\$1:no\"; fi
done" 2>/dev/null | tr '\n' ' ')
    assert_eq "$out" "11.0.3:yes 10.1.0:yes 8.2:yes 8.0:no 7.2:no " \
        "version_at_least compares numerically, not lexically (10.x > 8.x)"

    # The regex, not the network, is what regressed before - assert on it
    # directly so the test stays offline and deterministic.
    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(printf 'v10.2.4\nv11.0.0\nv11.0.3\nv11.1.0-rc1\nv11.0.0-rc2\n' \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)
    if [[ "$out" == "v11.0.3" ]]; then
        pass "stable-tag filter picks the newest bugfix release and skips RCs"
    else
        fail "stable-tag filter picks the newest bugfix release and skips RCs" "got '${out}'"
    fi

    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -q "v\[0-9\]\*\.\[0-9\]\*\.0" install-deps.sh; then
        fail "no regression to the x.y.0-only tag pattern"
    else
        pass "no regression to the x.y.0-only tag pattern"
    fi

    # apt has no 'qemu-img' package; qemu-utils provides it.
    TESTS_RUN=$((TESTS_RUN + 1))
    if grep -qE 'apt-get install.*[^-]qemu-img' install-deps.sh; then
        fail "does not ask apt for the non-existent 'qemu-img' package"
    else
        pass "does not ask apt for the non-existent 'qemu-img' package"
    fi

    # Both platforms must be handled everywhere the OS is branched on.
    TESTS_RUN=$((TESTS_RUN + 1))
    local macos_refs linux_refs
    macos_refs=$(grep -c 'macos' install-deps.sh)
    linux_refs=$(grep -cE 'apt-get|linux' install-deps.sh)
    if [[ "$macos_refs" -gt 0 && "$linux_refs" -gt 0 ]]; then
        pass "install-deps.sh branches for both macOS and Linux"
    else
        fail "install-deps.sh branches for both macOS and Linux" \
            "macos=${macos_refs} linux=${linux_refs}"
    fi

    rm -f "$lib"
}

# Each script must run on both platforms without an interactive terminal, and
# --help must never fail (packagers and CI rely on it).
test_help_and_noninteractive() {
    suite "help output and non-interactive safety" || return 0

    local script out rc
    for script in run-mac.sh iso-downloader.sh install-deps.sh mount-shared.sh; do
        TESTS_RUN=$((TESTS_RUN + 1))
        out=$(./"$script" --help </dev/null 2>&1)
        rc=$?
        if [[ $rc -eq 0 && -n "$out" ]]; then
            pass "$script --help exits 0 with output"
        else
            fail "$script --help exits 0 with output" "rc=${rc}"
        fi
    done

    # A menu reading EOF must quit cleanly rather than fall through with an
    # empty selection.
    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c 'source lib/common.sh; menu "pick" "A" "B" </dev/null' 2>/dev/null)
    if [[ "$out" == "QUIT" ]]; then
        pass "menu returns QUIT on EOF instead of an empty selection"
    else
        fail "menu returns QUIT on EOF instead of an empty selection" "got '${out}'"
    fi

    # Colour codes must degrade to plain text when stdout is not a terminal.
    TESTS_RUN=$((TESTS_RUN + 1))
    out=$(bash -c 'source lib/common.sh; echo "[${C_RED}]"' 2>/dev/null | cat)
    if [[ "$out" == "[]" ]]; then
        pass "colour codes are empty when not attached to a terminal"
    else
        fail "colour codes are empty when not attached to a terminal" "got '${out}'"
    fi
}

test_helpers() {
    suite "library helpers" || return 0

    local out
    # shellcheck disable=SC1091
    out=$(bash -c 'source lib/common.sh; shared_disk_path')
    assert_eq "$out" "shared/shared-disk.img" "shared_disk_path defaults correctly"

    out=$(bash -c 'source lib/common.sh; SHARED_DISK=custom.img shared_disk_path')
    assert_eq "$out" "custom.img" "shared_disk_path honours SHARED_DISK"

    out=$(bash -c 'source lib/common.sh; compute_md5 /dev/null')
    assert_eq "$out" "d41d8cd98f00b204e9800998ecf8427e" "compute_md5 matches the known empty-input digest"

    out=$(bash -c 'source lib/common.sh; disk_in_use /nonexistent-file; echo $?')
    assert_eq "$out" "1" "disk_in_use reports a missing file as free"
}

# ---------------------------------------------------------------------------

main() {
    command -v jq >/dev/null 2>&1 || { echo "jq is required to run the tests" >&2; exit 1; }
    make_stubs

    test_script_hygiene
    test_shellcheck
    test_gnu_bsd_portability
    test_helpers
    test_md5_fallbacks
    test_database_integrity
    test_m68k_args
    test_ppc_args
    test_display_options
    test_cross_platform_branches
    test_pram_boot_patch
    test_device_args_are_single_words
    test_arch_validation
    test_first_run_is_retryable
    test_shared_disk_locking
    test_shared_disk_override
    test_mount_shared_commands
    test_shared_disk_write_guard
    test_no_disk_before_validation
    test_explicit_iso_beats_default_installer
    test_download_extraction_failures
    test_downloader_guards
    test_shared_delivery_linux
    test_installer_logic
    test_help_and_noninteractive

    printf '\n'
    if [[ $TESTS_FAILED -eq 0 ]]; then
        printf '%s%d passed%s\n' "$G" "$TESTS_RUN" "$N"
        exit 0
    fi
    printf '%s%d of %d failed%s\n' "$R" "$TESTS_FAILED" "$TESTS_RUN" "$N"
    exit 1
}

main "$@"
