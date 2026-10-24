# QemuMac

QEMU classic Mac VMs, q800 and PPC mac99, and the Radeon 9700 build behind `qemu-tiger3d`. The shared HFS disk carries host/guest handoffs.

## Traps
- Run failing preflight checks before creating a drive; a blank `HD_IMAGE` falsely means installed (see docs/VM-SAFETY.md).
- Shared-disk state 2 means unknown, never free; use `shared_disk_is_writable()` (see docs/VM-SAFETY.md).
- Isolate tests with an empty `QEMUMAC_QEMU_INSTALL_DIR`; a test once launched real VMs (see docs/TESTING.md).
- Never delete `qemu-install/` or `vms/` (see docs/VM-SAFETY.md).

## Where to look
- Docs → `docs/README.md`
- Build → `docs/build-test-bench.md`
- Deploy/install → `docs/build-test-bench.md`
- Smoke → `docs/TESTING.md`
- Bench → `docs/BENCH.md`
- Tests → `docs/TESTING.md`
- Release → `docs/RELEASE.md`
- Tickets → `docs/TICKETS.md`
- History → `docs/HANDOVER-qemumac.md`, `docs/archive/`
- VM → `docs/vm-tiger3d.md`
- Firmware → `roms/radeon/README.md`
