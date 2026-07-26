# CLAUDE.md

Guidance for Claude Code working in this repository.

## Purpose

QEMU-based classic Macintosh emulation for 68k (Quadra 800) and PowerPC (PowerMac G4).
Beyond running old software, the project exists to support **classic Mac development**:
build on the host, move the artifact onto the shared HFS disk, run it under real Mac OS.
Treat the host↔guest handoff as a primary workflow, not a side feature.

## Non-negotiables

- **Everything must work on macOS and Ubuntu/Debian.** Both are in CI.
- **bash 3.2 compatible.** macOS ships bash 3.2 as `/bin/bash`. No `mapfile`,
  `readarray`, `local -n`, or `${var,,}`.
- **GNU vs BSD userland.** No `sed -i` without a suffix, `readlink -f`, `stat -c`,
  `grep -P`, `date -d`, `find -printf`. Use `compute_md5`, never `md5sum`/`md5` directly.
- **Prove changes with tests, not greps.** `./tests/run-tests.sh` must pass.
- **ShellCheck clean at `-S warning` with no blanket excludes.** Intentional patterns
  carry an inline `# shellcheck disable=` at the exact line, with a reason. Note a
  directive must precede a whole compound command — putting one before `done` is a
  parse error.
- **No logic inside CI YAML.** A workflow step is a one-liner that installs
  packages or calls a script in `tests/ci/`. Anything longer lives in a real
  script: `run:` blocks are invisible to ShellCheck, unreadable in a diff, and
  can only be run inside Actions. Add new scripts to `tests/shell-files.txt` —
  it is the single source of truth for ShellCheck, the bash 3.2 parse check and
  the hook, and the suite fails if a script on disk is missing from it.
- **When something is found broken, add a regression test for it.**

## Commands

```bash
./run-mac.sh                                   # interactive launcher
./run-mac.sh --config <conf> [--iso <file>] [--boot-from-cd]
./run-mac.sh --create-config <name>            # new VM, interactive
./iso-downloader.sh                            # download OS/software/ROMs
./mount-shared.sh [-u|-l]                      # host access to the shared disk
./install-deps.sh                              # QEMU + dependencies
./tests/run-tests.sh [filter]                  # test suite
```

## Architecture

`run-mac.sh` is the core: it sources a VM config, runs preflight checks, builds an
architecture-specific QEMU argument vector, and `exec`s QEMU. `lib/common.sh` holds
shared helpers (output, downloads, menus, database access, shared-disk locking).

**m68k (q800):** `-bios roms/800.ROM` (auto-downloaded), SCSI devices, boot device
chosen by patching a RefNum into the PRAM file at offset 120. The framebuffer only
accepts fixed modes — 640x480 and 800x600 at depths 1/2/4/8/24, 1152x870 at 1/2/4/8.

**PPC (mac99):** no ROM needed (OpenBIOS is built in), IDE devices, USB keyboard and
mouse, boot order via `bootindex`. `DISPLAY_RES` sets only the initial mode; the guest
can change it at runtime.

Storage uses `cache=writeback,aio=threads,detect-zeroes=on`. CPU models are `m68040`
and `7400_v2.9`. Multi-threaded TCG is avoided — it is unstable for these targets.

## Invariants worth preserving

- **Nothing is created before every check that can fail has run.** The absence of
  `HD_IMAGE` is what marks a VM as "not yet installed", so *any* `die()` after the disk
  exists strands it: the next run skips the installer and boots a blank drive (flashing
  question mark) forever. That covers downloads, the ROM, and `require_file` on the ISO.
  Helpers must not report success without leaving the file they promised — an unchecked
  `unzip`/`mv` in `download_and_place_file` is the same bug wearing a different hat.
- **An explicit `--iso` beats `DEFAULT_INSTALLER`.** The first-run path overwrites
  `CD_ISO_FILE`, so it must not run when the user named an ISO on the command line.
- **`disk_in_use()` and the shared disk are gated by `shared_disk_is_writable()`.**
  Use it rather than re-testing by hand; `if disk_in_use ...` silently reads the
  "cannot tell" status 2 as free.
- **`die()` inside a command substitution only exits the subshell.** Check the status of
  `x=$(some_function)` explicitly.
- **Probe pipelines must capture before grepping.** `set -o pipefail` turns a probe's
  intentional non-zero exit into a pipeline failure, which `!` then inverts into a
  wrong answer.
- **Shared disk: one writer.** `disk_in_use()` gates both `run-mac.sh` and
  `mount-shared.sh`. It returns 0 in use, 1 free, 2 unknown — never treat 2 as free.
- **Every VM needs a unique `MAC_ADDRESS`**, or guests collide on the network.
- **`QEMU_MIN_VERSION` (lib/common.sh) is what lets arguments be unconditional.**
  `run-mac.sh` enforces it before building any command line, so anything present at
  the floor — `zoom-to-fit`, the q800 `audiodev` — is passed without a probe. Probe
  only for features *newer* than the floor, like `zoom-interpolation` (9.0). Raising
  the floor is a user-facing decision: it excludes people rather than upgrading them.
- **`menu()` returns the sentinels `QUIT`/`BACK`/`NONE`**, not the option label, and
  runs its `select` with stdout redirected to stderr (bash emits a stray newline on EOF).

## Display configuration

Config variables: `DISPLAY_RES`, `DISPLAY_ZOOM`, `DISPLAY_SMOOTH`, `DISPLAY_FULLSCREEN`.

On macOS, Cocoa renders one guest pixel per physical pixel, so a high guest resolution
looks small on a Retina display. `DISPLAY_ZOOM` (default on) adds `zoom-to-fit=on` so
the window is resizable and the guest scales to fill it. SDL on Linux is already
resizable, so the flag is inert there — never pass Cocoa-only suboptions to SDL.

## Testing

`tests/run-tests.sh` stubs `qemu-system-*` on `PATH` so it prints its argv, then runs the
real scripts and asserts on the resulting command line. Add behavioural tests for new
work. Do not reintroduce grep-against-source assertions — the previous CI did that and
broke on every reword while catching no real bugs.

The stub honours `QEMU_STUB_REJECT` (simulate a QEMU lacking a display suboption) and
`QEMU_STUB_VERSION` (pose as a specific QEMU release).
