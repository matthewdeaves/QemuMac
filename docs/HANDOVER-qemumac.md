# Handover: qemumac fleet agent

You (the "qemumac" agent in `~/Documents/retro-agents`) own **QemuMac**, the
**qemu radeon-9700 fork**, and the **ppcosxkvm** fork. Never PR upstream
(qemu/qemu, linuxkid473/\*) — only matthewdeaves/\* repos. Never force-push
`radeon-9700` except for a release rebase. One VM at a time on the bench
disk; claim `qemu-tiger3d` through the fleet picker like real hardware.

## Solo VM work, 2026-09-27

User authorized work across these forks, commits/pushes and closing fixed
issues. No team agents were started; Signal Box was left alone. Testing used
this workstation and the Tiger VM, not powered-off vintage Macs.

- `0daa4626bb`: normalize DXT upload bytes and sampled channels. Addresses
  RGB speckle and blue/red-swapped faces in Q3.
- `dab9f22c05`: one Metal binary archive per pipeline descriptor. The previous
  shared archive failed when libraries reused entry-point names. Offline cold
  and separate-process warm archive tests pass.
- `bee98d449e`: stop ZMASK clears using an earlier draw's larger height.
  Q3 clears 768 rows after drawing with a 769-row guard extent; the old code
  overwrote 4096 bytes of the next lightmap allocation. This caused the
  intermittent turquoise floors/walls on subsequent launches. The fix keeps
  texture compression enabled. Also unifies source-endian conversion across
  system-memory 2D upload paths, an independent consistency fix.
- `57502abdd7`: optional `coreaudio_underrun` trace event for playback diagnosis.
  This adds observability, not an audio timing fix.

The complete R300 test suite passed, including a neighbouring-lightmap boundary
regression, channel-order fixtures, Metal rendering and cold/warm archives.
Repeated compressed Q3 demo launches retained correct wall/floor colours after
the clear fix. Q1, Q2 and Half-Life have host framebuffer capture helpers with
bench claims, overlap checks, live SSH GUI sessions and normal engine exits.
Aleph One's VM deployment/bench profile uses classic OpenGL; the shader path
still falls back to guest software rendering. Port repos now pin shared-v14,
which corrects misleading "picture-correct baseline" wording in evidence.

Evidence is local at `~/oldmac/evidence/solo-vm-20260927/`; game screenshots and
assets are not committed. The previous installed PPC binary is retained there
as `qemu-system-ppc-before-fixes`. Temporary diagnostics in `/tmp/q3-colour-debug`
are not part of the shipped emulator.

Still open: guest GL screenshot readback (qemu#7/#8), Tiger Aleph One GLSL
fallback (qemu#10), and occasional Q3 audio glitches reported under host load.
Native and VM Q3 captures also differ in brightness; do not claim pixel-exact
parity or complete gamma emulation. Physical-machine tickets remain untested.

## radeon-9700 branch state

- Repo: `github.com/matthewdeaves/qemu`, branch `radeon-9700`, on QEMU v11.1.1.
- Tip and installed PPC binary: `57502abdd7` (2026-09-27). The clean
  `qemu-source` mirror has been fast-forwarded to that revision. The installed
  binary was built from the matching clean `~/Documents/qemu` checkout and
  copied atomically into `qemu-install/bin/qemu-system-ppc`; `--version` reports
  `v11.1.1-41-g57502abdd7`. SHA256:
  `dda6414d60cfb00923c8cac234235961f3c78c2208030c1fcc0f4e1916fe99d8`.
  The m68k binary was not rebuilt or relabelled. The permanent install is ready for normal
  startup. At 16:36 BST another session held `qemumac-qemu2-measure` and
  was running the VM through its Claude scratch `dev-install` symlink to
  `~/Documents/qemu/build/qemu-system-ppc`. Do not restart or release that
  session's claim. Both binary paths hashed identically when checked.
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
