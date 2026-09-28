# Handover: qemumac fleet agent

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

## radeon-9700 branch state

- Repo: `github.com/matthewdeaves/qemu`, branch `radeon-9700`, on QEMU v11.1.1.
- **Tip and installed PPC binary (2026-09-28, current): `b60a6d9936`**
  (qemu#7's GART/AGP render-target redirect). The clean `qemu-source` mirror
  is fast-forwarded to match. `qemu-tiger3d` is running this build (verified
  live via `ps`, not just doctor). SHA256:
  `qemu-system-ppc  396f0396c13ac9d755dd4e21d00bc069092f0d048830423357d847f3ae7eca73`
  `qemu-system-m68k 4eff36d74719e85207251d09b98655cdf4ba5fe490739a7e590141d0ef5c9f6d`
  (m68k unchanged from the prior build, just re-copied). `docs/qemu-vm.md`
  (buildhost-owned) has this recorded too, as of `ef2e3fe`.
- Prior tip/install (2026-09-27, now superseded): `57502abdd7`,
  sha256 `dda6414d60cfb00923c8cac234235961f3c78c2208030c1fcc0f4e1916fe99d8`.
- Adds: ATI Radeon 9700 PRO for `mac99` (3D via Metal), Screamer audio,
  Cocoa fixes, PowerPC TCG speedups (host-FPU fast path, inline FPRF,
  lmw/stmw, lfs/stfs conversion). `git log --oneline v11.1.1..radeon-9700`
  lists every commit.
- Prior session (`1b80c30115..a824d07101`): quiet-by-default logging
  (`PPCGPU_DIAG`, `PPCGPU_RATE`) and dead code removed; a linear-fog fix
  (was greying out Quake II); `R300_DRAWLOG` records fog state;
  static-analysis fixes (Metal leaks in the legacy draw path, logger format
  checks, clip planes via memcpy); cheaper per-draw Metal lookups; repeated
  vertex index transformed once per draw; inline lfs/stfs conversion;
  vertex program decoded once per draw (1.99x interpreter speed); 2D blits
  from system RAM a page at a time; textures rehashed only on written
  pages; a sampler eviction use-after-free fix.
- Today's work (`a824d07101..7633ecb1eb`): metal_init() error paths and
  r300_draw.c's mallocs now release/NULL-check on failure (qemu#6);
  r200_scratch_read_wait() drops the BQL during its fence-poll sleep,
  guarded by a new `reset_gen` counter against a concurrent guest reset
  (qemu#5); a PPCGPU_DIAG `[TEXWATCH]` log characterised qemu#2's
  unchanged-byte texture rewrites (DXT1, whole mip chain — see issue for
  the full writeup); draw_core() skips building the vertex program on
  bypass draws and copies only the constants a program can read instead
  of always 256 (qemu#3, one of several ideas there — not yet
  re-profiled).
- ppcosxkvm's qemu submodule tracks `radeon-9700` and is at `b5d2ac4f4a`;
  bump it to the current tip when convenient.

### Scope (GRANTS 2026-09-27, board 8, sha 44f8234)

The user widened the takeover scope beyond VM tooling: improve the Radeon
emulation in the user's forks, **correctness first, then speed**. Approved
order: qemu#5, qemu#6 (correctness), then qemu#2, #3, #4 (speed). qemu#1
stays Blocked as a watch item until someone reproduces it — don't chase it
proactively.

**Ownership of `qemu-install/` is decided: you own it.** After a fix lands
on `radeon-9700`, the loop is: claim `qemu-tiger3d` through the picker,
rebuild (`install-deps.sh` option 3), release the claim, then mail
buildhost the source sha and `shasum -a 256` of `qemu-system-ppc` (not
md5 — the manager asked for sha256 specifically on QemuMac#15). Never
swap the install under someone else's claim.

### Open items (issues filed on matthewdeaves/qemu unless noted)

1. [#1](https://github.com/matthewdeaves/qemu/issues/1) — one hang seen
   once (`ppc-mac-gpu: IB lost`), on a throwaway debug build; not
   reproduced since. Blocked/watch — don't work it until reproduced.
2. [#2](https://github.com/matthewdeaves/qemu/issues/2) — **Board: Ready.**
   Root-caused with real evidence (PPCGPU_DIAG `[TEXWATCH]` log,
   dd9b359dc6; 500 samples from a Quake II demo1.dm2 run on
   qemu-tiger3d): every hit is a DXT1 (format 12) texture, the whole mip
   chain is touched (not a header page), several textures in the same
   VRAM heap show it together — consistent with the driver re-DMAing its
   AGP-side master copy into VRAM on every bind rather than tracking
   residency. Full writeup on the issue. Proposed next step (its own
   ticket, not started): a per-cache-entry confidence counter to skip
   re-hashing after N consecutive confirmed-unchanged binds.
3. [#3](https://github.com/matthewdeaves/qemu/issues/3) — **Board: In
   progress.** One sub-fix landed (7633ecb1eb): draw_core() skips
   building the vertex program on bypass draws, and copies only the
   constants a program can read (r300_pvs.c bounds every read by
   max_const) instead of always 256. Verified with tests/r300/run.sh;
   NOT yet re-profiled with qemu-profile.sh — qemu-tiger3d was contended
   by other sessions' bench runs all afternoon. Do that next, then decide
   whether the ticket's other ideas (batch vertices, reuse the per-draw
   order/xv/outs/list/prov/sw allocations) are still worth it.
4. [#4](https://github.com/matthewdeaves/qemu/issues/4) — untouched this
   session; needs qemu-profile.sh data before picking which of the three
   areas (Metal encoding, CPU clears/resolves, full-frame refresh) to
   act on first.
5. [#5](https://github.com/matthewdeaves/qemu/issues/5) — **Board:
   Review.** BQL-hold fixed (b1a126b294): r200_scratch_read_wait() drops
   the BQL for its sleep, guarded by a new `s->reset_gen` counter bumped
   in ppc_mac_gpu_reset() so a reset landing in the unlocked window is
   noticed rather than draining stale regs. The broader race (a Metal
   completion thread's fence callback racing the reset's memset with no
   BQL) was investigated and written up — real on paper, judged benign
   in practice, not fixed (no repro). Verified with tests + a full Quake
   II demo1 run (no hang/crash); did NOT specifically trigger a guest
   reset mid-render to exercise reset_gen — do that before moving to
   Done.
6. [#6](https://github.com/matthewdeaves/qemu/issues/6) — **Board: Done.**
   metal_init() error paths now release what was already created
   (device_owned tracks the zero-copy-vs-legacy split); r300_draw.c's
   malloc/calloc calls now NULL-check and free. Verified with tests +
   a full Quake II demo1 run.
7. [#7](https://github.com/matthewdeaves/qemu/issues/7) — **Board:
   Review.** Filed from old-mac-quake2#97, approved top priority.
   Manager's discriminating test run: Quake III's `screenshotJPEG`
   (also glReadPixels) is black too (min=max=mean=0); a QEMU monitor
   screendump (see run-mac.sh's new monitor socket, below) taken on the
   same still-running frame shows a real, correctly rendered Quake III
   menu (min=0 max=65535). Conclusion: emulator-side capture/readback
   bug, not engine-specific, and the display itself is fine — only the
   guest's own readback path is broken. Corroborated independently by
   alephone#46 (different engine, blank/white capture while world ticks
   advanced). Lead for next step, not yet fixed: aperture 1
   (`r300_ap1_read`) is the only CPU-visible VRAM view that flushes the
   renderer before a read and is what Apple's driver comment says it
   uses for *depth* glReadPixels; aperture 0 (`s->vram`) is plain RAM
   with no read trap at all. Whether color-buffer glReadPixels goes
   through aperture 0 or 1 is unconfirmed — `$R300_SURFWATCH` (already
   in ppc_mac_gpu.c) is the tool to instrument it. Possibly related:
   qemu#8 (quake3 session's screenshotJPEG stall), not reproduced in
   this session's own run, not confirmed same bug.
8. **NEW**: `run-mac.sh` now opens a unix-socket HMP monitor for every
   VM (`<vm dir>/monitor.sock`, always on, c4cd960) — requested ahead
   of #7 so the fleet can screendump a live VM independent of any
   guest-side capture path. Mailed to buildhost for build-host#123's
   `qemu-vm.sh screendump` wrapper.
8. [QemuMac #15](https://github.com/matthewdeaves/QemuMac/issues/15) —
   **Done, issue closed.** Evidence posted this session: source sha
   `a824d07101`, `shasum -a 256` of `qemu-system-ppc`/`qemu-system-m68k`
   (below), a live ssh boot under a `pick-bench-host.sh` claim. Mailed
   buildhost for build-host#122.
9. [QemuMac #16](https://github.com/matthewdeaves/QemuMac/issues/16) — no
   LICENSE file; waits on the user, not yours to act on.

## Build / test / profile / bench

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

# Profile (macOS `sample` of QEMU during a game; guest-CPU-thread top
# functions and Radeon share):
old-mac-quakespasm/scripts/qemu-profile.sh <quakespasm|quake2|ioquake3-bench> [seconds] [out]

# Bench (each Quake port):
<port>/scripts/bench.sh qemu-tiger3d <demo> 1024x768 1   # Q1/Q2: demo1, Q3: four
```

Debug switches cost fps and must be off for any bench: `R300_DRAWLOG`,
`PPCGPU_DIAG`, `PPCGPU_RATE`, `R300_DUMP`.

## VM: vms/power_mac_g4_tiger_3d

2 GB RAM, `SSH_PORT=2222`, `DISPLAY_GPU="radeon9700"`, Mac OS X 10.4.6.
Guest user `macvm`/`macvm`, passwordless sudo, auto-login, Remote Login on.
Reports `hw.model PowerMac3,1` (ports apply their "sawtooth" per-machine
config). Games installed: `/Applications/QuakeSpasm`, `/Applications/Quake2`
(v2.15.0), `/Applications/Quake3` (v0.6.20).

SSH: key `~/.ssh/qemumac_rsa` (RSA — Tiger has no ed25519). Alias
`qemu-tiger3d` (also `tiger3d`) needs `HostKeyAlgorithms +ssh-rsa`,
`PubkeyAcceptedAlgorithms +ssh-rsa`, and legacy `KexAlgorithms` — see
`~/.ssh/config`.

VM control: `old-mac-build-host/scripts/qemu-vm.sh up|down|status|doctor` —
this is now the canonical copy (build-host#120, adopted from
old-mac-quakespasm which owned it first); edit it there, never a port's
copy. Claim `qemu-tiger3d` first with
`old-mac-build-host/scripts/pick-bench-host.sh --acquire qemu-tiger3d
<label>` (status with `--status qemu-tiger3d`), release with
`--release qemu-tiger3d` when done.

`qemu-install/` current build (radeon-9700 tip `a824d07101`, QEMU 11.1.1,
built and verified by `install-deps.sh` option 3 — Radeon 9700 + Screamer
both detected; re-confirmed live today for QemuMac#15, four commits
behind the branch tip above, not yet urgent to rebuild):

```
qemu-system-ppc  sha256=9d2c8624cc2246a8468dbafcbd2b02f334f9886da2f7c0a5cfe21e481631e96b
qemu-system-m68k sha256=70c836fea234311d6a9f37db4b787891240bdb17cfaa11c1ac71182709ae9707
```

## Latest numbers

qemu `b5d2ac4f4a` (dev build), 1024x768, one run each, host moderately
loaded (load avg ~3), 2026-09-27, picture checked by eye:

- Quake 1 demo1: 74.1 fps (was ~49 fps at the start of the day, 4.8 before
  any of this work).
- Quake 2 demo1: 88.3 fps.
- Quake 3 four: 82.2 fps.

Host load swings results widely (Quake 3 measured 10-82 fps on similar
builds while other GPU/CPU work ran on the host). Judge changes by
`qemu-profile.sh` guest-CPU-thread shares, one run per measurement — VM fps
is never release or floor evidence.

## Rules

- Ownership and no-upstream-PR rules above apply to everything you touch.
- When the picture on the guest differs from real hardware, suspect the
  emulator first, not the game — two bugs so far (red water/lava from
  `COLOR_ENDIAN 0` handling, and Quake II's grey fog from inverted linear
  fog) looked like game bugs and weren't.
- Debug switches must be off, and the host-load caveat applies, for any
  measurement meant to be compared or cited (see above).

### Final validation and concurrent VM ownership

Q3 evidence runs at 1024x768 on the fixed binary measured 84.9, 67.0 and
87.7 fps. Artefact hashes match the v0.6.20 release DMG and requested
resolution/fullscreen settings match. The evidence tool returned VALID for all
three, but a concurrent QemuMac claim was discovered afterward, so treat these
as informal VM measurements, not an isolated performance comparison. Colour
regression evidence was captured separately before that ownership change.

The earlier manual claim was replaced by another session's claim; this session
did not release or terminate that claimant. Further continuous audio tests and
final cross-game playback must wait for exclusive VM ownership. Follow-ups:
qemu#13 (occasional audio glitches) and qemu#14 (gamma/brightness parity).
