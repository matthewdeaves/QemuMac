# CLAUDE.md

QEMU classic Mac VMs (q800, PPC mac99) and the Radeon 9700 build behind `qemu-tiger3d`.
The host<->guest handoff over the shared HFS disk is a primary workflow.

## Commands
`./run-mac.sh [--config <conf>] [--iso f] [--boot-from-cd]` or `--create-config <name>`;
`./install-deps.sh` (option 3 = Radeon fork into `./qemu-install`, writes BUILD_INFO);
`./mount-shared.sh [-u|-l]`; `./tests/run-tests.sh [filter]` must pass.
Current state and history: `docs/HANDOVER-qemumac.md`, `git log`.

## Rules (each came from a real break)
- macOS + Ubuntu, bash 3.2: no mapfile/readarray/`local -n`/`${v,,}`, `sed -i` without suffix,
  `readlink -f`, `stat -c`, `grep -P`, `date -d`, `find -printf`. Use `compute_md5`/`compute_sha256`.
- ShellCheck `-S warning` clean; inline `# shellcheck disable=` with a reason. New scripts go in
  `tests/shell-files.txt`. CI steps only call `tests/ci/` scripts.
- Test behaviour (tests stub qemu on PATH), never grep source. Every bug found gets a regression test.
- Create nothing before every failing check has run: no `HD_IMAGE` means "not installed", so a later
  `die()` strands a blank drive. `die()` in `$(...)` exits only the subshell: check the status.
  An explicit `--iso` beats `DEFAULT_INSTALLER`.
- Capture probe output before grepping (pipefail inverts `!`).
- Shared disk has one writer: `disk_in_use()` is 0 in use, 1 free, 2 unknown, never treat 2 as free;
  gate on `shared_disk_is_writable()`.
- Unique `MAC_ADDRESS` per VM. Keep multi-threaded TCG off (unstable).
- `QEMU_MIN_VERSION` makes args unconditional; probe only newer features. Raising it is the user's call.
- Radeon (`DISPLAY_GPU="radeon9700"`): probe `qemu_has_radeon`/`qemu_has_screamer`; `require_radeon`
  runs before `preflight_checks`; card pinned to slot 0x0E, added before other PCI devices. Tests set
  `QEMUMAC_QEMU_INSTALL_DIR` to an empty dir (a test once launched real VMs). Run `brew` with
  `</dev/null`, build with `/usr/bin` first on PATH, `--disable-nettle`.
- Never pass Cocoa-only display suboptions to SDL.
- Never delete `qemu-install/` or `vms/`.
