# radeon-9700 branch state and open items

Where the qemu fork's `radeon-9700` branch stands, what the agent may change, and the open
tickets. Read the section you need; `grep -n '^## \|^### ' docs/radeon-branch.md` lists them.
Sections: branch state, Scope, Open items.

## Branch state

- Repo: `github.com/matthewdeaves/qemu`, branch `radeon-9700`, on QEMU v11.1.1.
- **Tip and installed PPC binary (2026-09-29, current): `6f0f80cd`**
  (qemu#26 AltiVec on NEON, on top of qemu#24 GPU vertex programs and the
  qemu#1 fix `70fed303`), CI green. `qemu-tiger3d` runs this build.
  SHA256 of `qemu-system-ppc`:
  `4c39fd42994f68075d29e27a3172da82dac0838f9045a83b35fa2a6c103db0be`;
  `qemu-install/BUILD_INFO` records commit and sha. Numbers: `vm-tiger3d.md`.
- Round qemu-ppc closed: qemu#1 (fixed), #24, #26 landed; #25 (ring thread)
  measured at 0.2% of the vCPU thread and not ported (WIP on branch
  `qemu25-wip`); qemu#27 wires `tests/ppc-vmx` into CI and needs the gh token's
  `workflow` scope (user). Open: QemuMac#23 item 4 (the user's live look).
- Superseded tips: `b60a6d9936` (2026-09-28), `57502abdd7` (2026-09-27).
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
