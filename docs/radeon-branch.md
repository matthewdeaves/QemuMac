# Radeon branch scope

The QEMU fork is `matthewdeaves/qemu`, branch `radeon-9700`.
QemuMac owns VM tooling and the installed emulator; engine work has its own tickets.
Dated priorities and installed-build observations are in `docs/archive/radeon-state-2026-09-29.md`.

## Scope

The 2026-09-27 grant widened the work to Radeon emulation in the user's forks, correctness before speed. The full grant and then-current priority order are preserved in the archive. Current ticket state is reached through `docs/TICKETS.md`.

## Install handoff

The grant assigns `qemu-install/` to this agent. After a `radeon-9700` fix, use the claimed build/install loop in `docs/build-test-bench.md` and `docs/vm-tiger3d.md`. The recorded handoff asks for source SHA and SHA256 of `qemu-system-ppc`, not md5, on QemuMac#15. Do not swap the install under another claim.
