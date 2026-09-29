# QemuMac tests

## Offline checks
Run `./tests/run-tests.sh [filter]`. Tests stub QEMU on PATH and check behaviour, not source text. Every discovered bug needs a regression test.
Set `QEMUMAC_QEMU_INSTALL_DIR` to an empty directory in tests: a test once launched real VMs. Platform conventions: `docs/SHELL.md`.

## CI
ShellCheck must be clean at `-S warning`; an inline `# shellcheck disable=` needs a reason. List new scripts in `tests/shell-files.txt`; CI steps call scripts under `tests/ci/`.
The Radeon build check is `tests/ci/macos-radeon-build.sh`. Offline R300 tests in the QEMU fork are described in `docs/build-test-bench.md`.

## Live smoke
VM launch and shared-disk commands are in `docs/build-test-bench.md`. Read `docs/VM-SAFETY.md` before a live run; `docs/vm-tiger3d.md` describes the fleet guest and its validation limits.
