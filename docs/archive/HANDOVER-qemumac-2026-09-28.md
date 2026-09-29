# Handover: qemumac fleet agent

Current session state only (the newest entry below). Older entries are in
`docs/archive/`. Reference docs: `radeon-branch.md` (branch, scope, open items),
`build-test-bench.md` (commands), `vm-tiger3d.md` (VM, numbers, ownership rules).

## 2026-09-28 session: QemuMac#23 item 2 baseline -- artefacts staged, blocked on peer claim

Picked up the qemu-ppc round queue at its first item: QemuMac#23 item 2, a
5-game VALID bench-evidence baseline (quakespasm, quake2, quake3, halflife,
alephone) on the current install (item 1 already confirmed satisfied by the
prior session -- radeon-9700 tip `70fed3035f`, `qemu-system-ppc` sha256
`88f6350c95717ebf1c26bd53973b8cd6893da6e47f4293570dd080381ed3e34c`).

**Live incident, resolved, not an emulator bug.** Booting `qemu-tiger3d` for
the first bench attempt, the user reported the VM flickering. Diagnosed live:
HMP screendumps (bypass the guest, read the emulated framebuffer directly)
showed a static frozen frame, not flicker; ssh to the guest was fully dead
("connection timed out during banner exchange"); `vm.loadavg` read `32 / 144
/ 110` on this 10-core box (bench gate is 6.0). Root cause: the user's own
Xcode/swiftpm-testing-helper process was using ~6 cores (598% CPU) --
unrelated personal job, not mine to touch, same shape as a previously
documented contention incident. Not a QemuMac/qemu regression. Load has
since decayed; ssh answers again; no VM corruption. Evidence (log +
screendumps from during the incident) saved to
`~/oldmac/qemu1-scratch/flicker-20260928/` in case it's useful context for
qemu#1 later, though the "IB lost" counter stayed at 0 throughout -- this
does not look like a qemu#1 repro, just contention.

**Bench artefact prep, done.** For each of the 5 games, extracted the binary
(and quake2's `ref_gl.so`) from the latest promoted release DMG and
hash-verified it byte-identical against what's actually deployed on
`qemu-tiger3d` (via `ssh qemu-tiger3d cat <path> | shasum -a 256`, same
method `bench-evidence.sh` itself uses) -- these are required as
`BENCH_ARTEFACT`/`EXTRA_ARTEFACT_LOCAL` per `docs/bench-evidence.md` (must
come from a release DMG or build output, never pulled fresh from the host
under test, build-host#134). All matched except alephone:

- quakespasm: `~/oldmac/quakespasm/quakespasm-v1.15.23-ref` -- matches v1.15.23 DMG.
- quake2: `~/oldmac/quake2/quake2-v2.15.1-ref` + `ref_gl-v2.15.1-ref.so` -- matches v2.15.1 DMG.
- quake3: `~/oldmac/quake3/ioquake3-v0.6.21-ref` -- matches v0.6.21 DMG.
- halflife: `~/oldmac/halflife/xash3d-v1.9.23-ref.bin` -- matches v1.9.23 DMG.
- **alephone: mismatch.** The guest's deployed binary (mtime 2026-09-27
  23:52) does NOT match the latest release DMG (`v1.2.1`, published
  2026-09-25). It does match `dist/staging-dmg/.../Aleph One` in the
  alephone repo instead -- a newer build deployed after the last tagged
  release, not yet released. Used that as the reference
  (`~/oldmac/alephone/aleph-one-staging-ref`) so the baseline isn't blocked,
  but flagging this for alephone's own session: worth its own ticket
  (deployed-but-unreleased build) unless there's a reason it's deliberate.

**Blocked, not run yet.** `qemu-tiger3d` is claimed by a peer (old-mac-quake2,
`qemu-recovery-107`, hit the same ssh-stalled reading from the load spike
independently) -- held idle 15+ min at last check. Sent them a heads-up
(fleet mail + SendMessage) that ssh answers fine now in case it changes their
recovery call, but did not touch their claim. Workstation 5-minute load was
also still ~13 (decaying from the spike, still over the 6.0 gate) at last
check. Both need to clear before the actual `bench-evidence.sh` runs.

**Next session:** check `pick-bench-host.sh --status qemu-tiger3d` and
`vm.loadavg`; once both clear, run (from each port's own repo root):
```
BENCH_ADAPTER="$(pwd)/scripts/bench-adapter.sh" BENCH_ARTEFACT=<ref above> \
  scripts/shared.sh bench-evidence.sh qemu-tiger3d qemuppc-baseline-20260928
```
for all 5 games, then post the table (game, fps, bundle path, emulator
commit) to QemuMac#23, noting the alephone artefact caveat above. No claim
or lock held by this session at checkpoint; qemu#23/qemu#1/qemu#24/qemu#25/
qemu#26 untouched this session (all still per their last-recorded state).

**Update before checkpoint:** old-mac-quake2 replied -- they'd already run
the ssh-stalled recovery (`qemu-vm.sh down`/`up`) before my heads-up landed;
doctor is fully green and quake2 v2.15.1 is freshly redeployed+smoked there
(was found missing on the guest, likely from a re-provision). They're
finishing their own #107 bench proof and waiting on the same load gate;
claim releases in a few minutes. My staged quake2 reference artefact
(v2.15.1) already matches what they just redeployed, so nothing to redo.
