# Build, test, profile and bench the Radeon emulator

Build and install commands for `qemu-install/`, plus VM launch and shared-disk entry points.
Offline tests are in `docs/TESTING.md`; profiling and benchmark commands in `docs/BENCH.md`.
Sections: Commands, VM commands, Build environment.

## Commands

```bash
# Build (macOS): install-deps.sh option 3 builds radeon-9700 tip into
# qemu-install/ from qemu-source/.
./install-deps.sh

# Fast incremental build during dev, in the fork's checkout (~/Documents/qemu):
cd ~/Documents/qemu/build && PATH="/usr/bin:$PATH" ninja qemu-system-ppc   # Apple tools first: a Retro68 Rez elsewhere breaks the build

# Offline 3D tests (macOS, needs Metal), in the fork's checkout:
sh ~/Documents/qemu/tests/r300/run.sh

# Run a dev build against the VM (QEMUMAC_QEMU_INSTALL_DIR points at a dir
# with bin/qemu-system-ppc, bin/qemu-img symlinked to the qemu build dir):
QEMUMAC_QEMU_INSTALL_DIR=/path/to/dev-install ./run-mac.sh --config vms/power_mac_g4_tiger_3d/power_mac_g4_tiger_3d.conf
# (qemu-vm.sh up passes the same variable through)

# CI:
tests/ci/macos-radeon-build.sh

```

Profile and benchmark procedure: `docs/BENCH.md`.

## VM commands

`./run-mac.sh [--config <conf>] [--iso f] [--boot-from-cd]` launches a guest; `--create-config <name>` creates its configuration.
`./mount-shared.sh [-u|-l]` manages the shared disk. Offline tests: `./tests/run-tests.sh [filter]`.

## Build environment

Run `brew` with `</dev/null`, put `/usr/bin` first on PATH for builds, and use `--disable-nettle`. `install-deps.sh` option 3 builds the Radeon fork into `./qemu-install` and writes `BUILD_INFO`.
