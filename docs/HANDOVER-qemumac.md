# Handover: qemumac fleet agent

## 2026-09-28 session: qemu#17 three counters landed, qemu#18 closed (disconfirmed), A/B confounded

Picked up qemu#17 exactly where the prior session's handover (below) left
it: "confirm the hypothesis with a counter... before designing a fix."
Did that, three times over, and each round disconfirmed the previous
session's theory rather than confirming it:

1. **g_r300_stat_tex_hazard_full/raw** (9df5fd7): tags r300_texture_full/
   raw's `metal_range_busy_r200 -> metal_flush_r200` guard -- the flush
   qemu#18 was split out to redesign. Rebuilt qemu-install, claimed
   qemu-tiger3d, ran demo1 1024x768 (34.8fps, matches the 36fps
   baseline): **159 hits over 1,638,000 draws** (~1 in 10,300) -- not
   "nearly every draw", noise. **Closed qemu#18**: its premise doesn't
   survive the counter it asked for. Flagged the closure to the manager
   since Triage is normally their call to move things out of, not mine;
   manager confirmed it was right and recorded it Done.
2. **g_r300_stat_tex_full_upload(_bytes)** (25bae0f): qemu#17's own step 2
   asked whether the lightmap's sub-rectangle updates force a whole-
   texture re-upload. They do -- qemu#2's per-page hashing only narrows
   re-*hashing*, not re-uploading; any single dirty page still allocates
   a fresh MTLTexture and re-uploads every mip level. But the counter
   showed **148 uploads, 12,786 KB total, flat across the back half of a
   1.6M-draw run** -- a one-time level-load cost, not a per-frame one.
   Real inefficiency, doesn't explain the fps gap.
3. **g_r300_stat_conflict_depth/colour/tex** (49a20da): what actually
   tracks the profile's dominant r200_new_cb cost (32.5% inclusive) is
   the pre-existing g_r200_stat_conflicts counter -- ~40,200 over the
   same run, 27x the real flush count, each one ending the batch via
   r200_split() and forcing the next draw's r200_new_cb() exactly like a
   flush does. Tagged which of metal_draw_r300's three conflict checks
   fires: **688 depth / 19,821 colour-buffer / 19,685 texture-unit** --
   roughly even, not overwhelmingly texture-driven, so it isn't cleanly
   "the lightmap gets rendered-to then sampled" on its own.

**Gotcha, costly one**: `install-deps.sh` clones from `origin` (GitHub),
not your local `~/Documents/qemu` checkout -- an uncommitted-and-unpushed
instrumentation change gets silently dropped by the next rebuild, which
just reinstalls the current tip again. Burned one full build cycle this
session before noticing (commit + push *before* every install-deps.sh
run, not after).

**Also found, unrelated but real**: qemu-tiger3d was wedged on session
start (a leaked `qemu-system-ppc` from a prior session, "desktop not
answering", `qemu-vm.sh down`'s ssh-based shutdown loop hung past its own
3-minute budget). Fixed with the documented TERM-wait13s-KILL sequence,
never a bare KILL. Every subsequent down/up cycle this session was clean
and fast -- this really was just a leaked process, not a build issue.

**Couldn't get a real flashblend-era comparison.** The ticket's own
description says v2.15.1 (confirmed installed via `CFBundleVersion` over
ssh -- this doc's own "Games installed" line below is stale, still says
v2.15.0) turned on real per-surface dynamic lighting *unconditionally*;
flashblend isn't a runtime toggle in this binary. Verified empirically:
`+set gl_flashblend 1 +set gl_dynamic 0` vs `+set gl_flashblend 0 +set
gl_dynamic 1` on demo1 measured 35.3 vs 34.8 fps -- no real difference,
both hit the identical code path. A genuine A/B needs the actual
pre-v2.15.1 binary; didn't track one down (checked a few `~/oldmac`
scratch artefacts, couldn't confirm versions cheaply, didn't chase
further).

**Manager asked for a per-install A/B** (1dfe1535 pre-counters vs 49a20da
with all three) to confirm the counters cost nothing idle. Built
1dfe1535 as a scratch install at `~/oldmac/qemu17-scratch/install-
1dfe1535` (worktree at `~/oldmac/qemu17-scratch/src-1dfe1535`, same
CONFIGURE_ARGS as install-deps.sh -- first configure attempt hit a
transient "Nonexistent build file 'pyvenv/meson.build'" meson error,
second attempt from the same fresh worktree just worked, never
root-caused). 5 rounds a side via bench-evidence.sh/bench-compare.sh
(`BENCH_ARTEFACT` pinned to a local copy of the guest's quake2+ref_gl.so
so the guest binary reads as unchanged across legs; `QEMUMAC_QEMU_
INSTALL_DIR` passed to bench-evidence.sh itself, not just `qemu-vm.sh
up` -- bench-evidence.sh reads it independently for its own stale-build
check). **Verdict: CONFOUNDED + HOST-OVERLOADED** (bench-compare.sh's own
words) -- old-mac-quake2's repo HEAD moved between legs (a concurrent
fleet session, not me) and workstation load hit the 60%-headroom gate
during the baseline leg. diff 1.15fps inside a 2.61 noise band regardless.
Posted for the record on qemu#17, not claimed as proof either way.

**Gotcha, caught by the manager, not by me**: ran the gl_flashblend/
gl_dynamic A/B and two plain demo1 legs directly via `cd
old-mac-quake2 && ./scripts/bench.sh` in a loop -- old-mac-quake2 is a
peer's repo, never mine to leave output in. Checked afterward: `git
status`/`git diff` in that tree came back fully clean, so nothing was
actually left behind this time (lucky, not by design), but don't repeat
the pattern -- bench-evidence.sh's own BENCH_OUT_DIR plumbing is the
correct path in, straight from the top of a bench task, not just once a
peer flags the loop.

**qemu#17 left In Progress**, not Done -- no fix landed, and the
counters' Pass bar ("profile posted, plus a better verdict or a written
floor reason") isn't met by disconfirming two hypotheses. Next session's
first steps, from the qemu#17 thread:
1. Time `r200_new_cb` directly (it's just `[commandQueue commandBuffer]`
   plus an optional `encodeWaitForEvent:` -- trivially cheap code, so its
   32.5% inclusive share most likely means it's *blocking* on Metal
   command-queue back-pressure from ~40k small batches, not doing real
   work. Not verified this session.
2. If confirmed, candidate fixes are raising the queue's in-flight depth
   or reducing conflict-triggered splits -- either needs its own design
   pass + regression test, same shape as qemu#18's original (now closed)
   charter.
3. A real flashblend-era binary would still be useful for confirming
   whether the ~50/50 conflict split is real-dlight-specific.

`qemu-tiger3d` claim released, VM left on `radeon-9700` tip `49a20da`
(all three counters, zero measured behavioural regression --
tests/r300/run.sh passed after every commit). Scratch worktree/install
at `~/oldmac/qemu17-scratch/` left in place, matching the QemuMac#20/21
precedent of reusable scratch installs -- not cleaned up.

## 2026-09-28 session: QemuMac#20 closed, QemuMac#21 in progress (handed off)

Picked up QemuMac#20 (validate b60a6d9936: A/B vs e47f3a1387, 5-game pass, Q2
screenshot). All four "Do" steps done, both Pass criteria met, closed:

- **Step 1**: bench-compare A/B, e47f3a1387 (scratch) vs b60a6d9936
  (installed), quake2 demo1 1024x768, 5 interleaved rounds/side, qemu-tiger3d.
  First attempt INVALID both sides (stale local `ref_gl.so` reference --
  refresh it from the guest every time before benching, it gets redeployed
  without warning). Reran clean: **NO-DIFFERENCE**, diff 17.55 fps well
  inside noise band 28.85, load 1m/5m ~2/~3 throughout. Baseline flagged
  VSYNC-QUANTISED (~58fps cap) -- neither side's number is a release figure.
  Confirms code reading: the GART copy-out only fires on a redirected
  (screenshot-style) target, not ordinary VRAM-backed draws.
- **Step 3**: one VALID bundle per game on b60a6d9936, load 2.1-2.3
  throughout, all comfortably above the 25fps floor: quakespasm 88.5,
  quake3 (four, 1024x768) 69.3, halflife (c0a0) 52.8/122.6/121.0, alephone
  31.1-60.7, quake2 (demo1, pre-v2.15.1 binary) 45.0. Only did a live pixel
  frame check for quake2 (via `vm-frame-check.sh`, clean); the other four
  got no pixel check, just VALID-hash + sane fps -- QemuMac#21 now asks for
  those too.
- **Step 4**: Quake II's own in-game `screenshot` command (qemu#7's second,
  distinct mechanism from screenshot.sh/check-frames.sh, which #97 already
  fixed separately) -- confirmed **no longer black** on b60a6d9936. Needed
  900 warm-up `wait` frames in the cfg to land on real gameplay rather than
  the loading screen (same fix shape as #97's own 300->900 bump). **Gotcha
  hit**: launching the guest binary via `nohup ... &` inside an ssh command
  loses its WindowServer session and crashes on `bootstrap_register` --
  background the *ssh invocation itself* instead (`ssh host bash <<'EOF' &`,
  matching `vm-frame-check.sh`'s own pattern), never `nohup` inside the
  remote shell.
- **Step 5** (qemu#5's own requested rerun, c7096bfafd vs e47f3a1387):
  INCONCLUSIVE on `bench-compare.sh`'s own identical-samples technicality,
  even after 7 rounds/side -- root cause confirmed from the raw engine log,
  not a stale read: demo1's own timedemo report is 1-decimal fps and
  run-to-run variance here was under 1fps, so only ~14 distinct achievable
  values exist across the spread -- collisions are near-guaranteed
  regardless of round count. Substance was clean throughout: diff -0.2 to
  -0.25fps, comfortably inside the 0.34-0.40 noise band on every recount.
  Worth flagging to buildhost: build-host#113's check can't distinguish
  this from an actual stale read.

**Mid-session incident**: a live in-game-screenshot test hung (my own bug --
deleted the test cfg via a `timeout`-not-found/`|| true` mask, then
relaunched without recreating it, so the guest sat idle on demo1 forever).
Manager caught it at 22+ minutes via the picker's process visibility. TERM'd
the guest process, waited ~13s, KILL'd (never a bare KILL), cleaned up
`/tmp` cruft the picker's release-time check flagged, released the claim.
Also: don't call a port's own `screenshot.sh` without setting `SHOT_DIR`
somewhere under `~/oldmac` -- the default lands PNGs in that port's own
`docs/screenshots/`, which is their tree, not scratch.

**QemuMac#21 opened by the manager** off QemuMac#20's own numbers: quake2
went 94.9 (#19, c7096bfafd) -> 45.0 (#20, b60a6d9936) on the **same** binary,
plus lower lows on quake3/alephone. Hypothesis A (the GART copy-out costing
something on ordinary frames) vs B (noise -- single one-shot samples, and
b60a6d9936 already showed huge candidate variance in step 1, 39.9-76+ fps).
Code review before spending VM time: the copy-out block is only reachable
when `r300_to_vram()` fails for the primary colour buffer (i.e. a
redirected/AGP target) -- an ordinary draw never reaches it, and the other
changed line (`vram_alloc_size` passed to `draw_r300`) is only used in O(1)
bounds comparisons, not per-size work. That makes A look unlikely from the
code, but doesn't prove it, so added a live counter instead of guessing:
`PPCGPU_RATE` now reports GART copy-outs/s alongside draws/s (`1dfe153571`
on `radeon-9700`, pushed, `tests/r300/run.sh` passes). **Not done, first
thing next session**:
1. Rebuild `qemu-install/` from `radeon-9700` tip (`1dfe153571`) under a
   `qemu-tiger3d` claim, mail buildhost the new sha256s.
2. The actual discriminating test: vsync-off (`+set gl_swapinterval 0`,
   confirmed in `effective.txt`) A/B, c7096bfafd vs the new b60a6d9936+
   build, quake2 demo1, 5 interleaved rounds/side, load < 4, with
   `PPCGPU_RATE` captured (env `R300_...` or whatever trace-enable var this
   build uses -- check `TRACE_ON` callers) during at least one round per
   side to read the copy-out rate directly.
3. Frame checks for quakespasm/quake3/halflife/alephone via
   `vm-frame-check.sh` (port each one needs its own copy, or generalise --
   quake2's is the only one that exists today), `SHOT_DIR` under `~/oldmac`.
4. Scratch installs for e47f3a1387 and c7096bfafd already exist at
   `~/oldmac/qemu20-scratch/install-{e47f3a1387,c7096bfafd}` -- reusable,
   no rebuild needed for those two sides.

**Update, same session (continued past the point above):** finished
QemuMac#21 rather than leaving it mid-flight. Rebuilt `qemu-install/` from
the counter commit (`1dfe1535`), sha256s mailed to buildhost and recorded
in `docs/qemu-vm.md` (`c36203b`). Three independent checks, all agreeing:

1. **Live counter, ordinary gameplay** (`PPCGPU_RATE=1`, demo1 timedemo, no
   screenshot/capture): every per-second sample read **0 GART copy-outs/s**
   alongside tens of thousands of ordinary draws/s.
2. **vsync-off A/B**: turned out vsync was already off throughout (`bench.sh`
   always sets `gl_swapinterval 0`, confirmed in every `effective.txt` all
   session). c7096bfafd vs the new counter build, quake2 demo1, 5 rounds/side,
   load ~2/~3: INCONCLUSIVE on the same 1-decimal-precision identical-samples
   technicality as step 5, but diff +0.375fps inside an 0.88 noise band --
   candidate marginally *faster*, not slower.
3. **Frame checks**, all four games, host-side screendump mid-gameplay, all
   clean/no corruption: quakespasm (demo1 timedemo), quake3 (own
   `screenshot.sh`, 8 frames), half-life (map c0a0 -- needed ~25s past
   launch to clear the loading splash, 8s wasn't enough), aleph one
   (Marathon 2 L00 film, classic GL -- the film arg needs the full
   `Demos/L00.filA` path, not the bare name).

**Verdict: hypothesis B.** The 94.9->45.0 fps figure was a single one-shot
sample landing inside b60a6d9936's own already-documented wide variance on
the *old* v2.15.0 quake2 binary (QemuMac#20 step 1's own A/B showed
39.9-100+ fps swings on that exact binary/build combo) -- not a regression
from the copy-out. No fix needed; the counter stays as permanent,
zero-cost-when-idle instrumentation. QemuMac#21 closed.

**Gotcha hit**: launching a guest game via `nohup cmd &` *inside* an ssh
remote shell loses its WindowServer session (`bootstrap_register` failure,
crashes before rendering). Background the *ssh invocation itself* instead
(`ssh host bash <<'EOF' &` from the calling shell), matching
`vm-frame-check.sh`'s own pattern -- this bit both the Quake II
in-game-screenshot work (QemuMac#20 step 4, caused the hang incident) and
very nearly the alephone frame check here.

Board after that point: QemuMac#20 and QemuMac#21 both closed/Done.
qemu#1/#11/#13/#14 still Blocked/watch-only, untouched.

**Update, same session again (context hard ceiling hit mid-task):** manager
approved qemu#17 next (Quake II real-dlight path, 36fps vs ~90fps
flashblend -- the gap QemuMac#21 established as real, on the v2.15.1
binary). Started it: claimed qemu-tiger3d, ran `qemu-profile.sh quake2`
(15s) alongside `bench.sh qemu-tiger3d demo1 1024x768` (32.9fps this run,
load ~2). Profile breakdown (vCPU thread, inclusive):

```
63.7%  ppc_mac_gpu_mmio_write -> process_ring_buffer -> process_pm4 -> execute_ib
  46.3%  r300_render
    32.6%  metal_draw_r300
      32.5%  r200_new_cb        (almost ALL of metal_draw_r300's cost)
    8.3%  r300_draw_build
    6.4%  r300_texture_full     (the lightmap/CPU-converted-texture path)
    6.4%  metal_flush_r200      (called directly from r300_render)
    3.3%  draw_core
```

**Root-cause hypothesis (code reading only, not yet confirmed with a
counter):** `r300_texture_full()` (`hw/display/ppc_mac_gpu_metal.m:7348`,
the path used for the lightmap texture) does `if (!td->host_data &&
metal_range_busy_r200(st, lo, hi, false)) { metal_flush_r200(st); }` before
even checking the texture cache -- a genuine read-after-write hazard guard,
but real-dlight rebuilds the lightmap then reads it back the *same frame*,
likely the same batch, so this probably fires on nearly every draw that
samples it. `r200_new_cb` dominating `metal_draw_r300` connects: both its
call sites only fire when `g_r200_cb` is `NULL`, which an eager
`metal_flush_r200` causes on (probably) every draw. flashblend never
rebuilds-then-reads a texture same-frame, consistent with it never hitting
this cost. **Not empirically confirmed** -- no counter run yet distinguishing
this flush call site from any other, unlike QemuMac#21's discipline.

**Not attempted, and shouldn't be without its own design pass** (same shape
as qemu#9): this touches CPU/GPU texture-data-race correctness, not just
speed, and needs a repro/regression test before any fix lands. Filed
**qemu#18** (Triage) to track the actual fix design. `qemu#17` itself
stays In progress -- next session's first steps:
1. Confirm the hypothesis with a counter (tag `metal_flush_r200`'s call
   sites, or `PPCGPU_DIAG` around `r300_texture_full`'s flush branch) --
   don't skip this and go straight to a fix.
2. If confirmed, work qemu#18's design questions, then fix forward with a
   bench-compare A/B per change (5 rounds, vsync off -- already the
   default, see QemuMac#21) against the reference v2.15.1 DMG build.
3. `qemu#17`'s own Pass bar: a profile breakdown posted (done, this
   handover) and at least one change with a BETTER verdict, or a written
   reason the path is near the floor.

Claim on `qemu-tiger3d` released; the VM should still be on the production
`qemu-install` (1dfe1535, QemuMac#21's counter build) -- no install dir
override was active when this session stopped, but re-run `qemu-vm.sh
status` to confirm rather than trust this note, since it wasn't
double-checked before the context ceiling cut this session off.

Nothing else left approved for qemumac as of this handover -- check the
board fresh next session rather than assuming more is queued.


You (the "qemumac" agent in `~/Documents/retro-agents`) own **QemuMac**, the
**qemu radeon-9700 fork**, and the **ppcosxkvm** fork. Never PR upstream
(qemu/qemu, linuxkid473/\*) — only matthewdeaves/\* repos. Never force-push
`radeon-9700` except for a release rebase. One VM at a time on the bench
disk; claim `qemu-tiger3d` through the fleet picker like real hardware.

## 2026-09-28 session: qemu#7/#4/#15 closed, queue empty

Picked up from the 2026-09-28-0114 checkpoint (context ceiling wrap-up).
That session's outstanding step -- record commit+sha256 on qemu#7/#11,
restart the VM onto it, mail buildhost -- was still undone; did all of it
first this session, then worked the rest of the approved queue.

- **qemu#7 (screenshot readback black) -- closed, not just installed.**
  Posted commit `b60a6d9936` + sha256 (below) on qemu#7 and qemu#11, claimed
  qemu-tiger3d, `qemu-vm.sh up` (doctor all green, `ps` confirmed
  `qemu-install/bin/qemu-system-ppc` is the running binary), then actually
  **re-ran the ticket's own repro** (ioquake3 `screenshotJPEG` via
  `autoshot.cfg`, demo four) rather than trusting the earlier NO-DIFFERENCE
  bench + regression pass alone: `shot0003.jpg` came back a real Q3 menu
  frame (min=0 max=255 mean=32.49), not black. Closed on the strength of
  that direct re-test. Mailed buildhost; they folded it into
  `docs/qemu-vm.md` (`ef2e3fe`) within the same session.
- **qemu#4 (per-draw Metal encoding / CPU clears/resolves / full-frame
  refresh) -- closed, no code change.** Re-profiled at b60a6d9936
  (`qemu-profile.sh quake2 12` alongside `bench.sh ... demo1`, one run,
  host fleet-contended so the 35.4 fps figure isn't citable but the
  **shares** are, per the project's own profiling rule). All three
  originally-named costs are now small-to-invisible: `metal_draw_r300`
  ~1.1% inclusive (was ~5% before qemu#2/#3 landed), `r300_zmask_clear` /
  `r300_cmask_clear` / `r200_clear_depth_buffer` zero samples, display
  refresh (`-[QemuCocoaView drawRect:]`) ~0.64% of main-thread samples.
  The actual dominant cost now is generic PM4/ring-buffer dispatch
  (`ppc_mac_gpu_process_pm4`/`execute_ib` chain, 20.4% inclusive) plus
  `r300_render`/`r300_draw_build` (9.3%/8.4%) -- not any of the three
  things this ticket named. Closed with that data; a PM4-dispatch-overhead
  ticket, if wanted, should be its own fresh ticket with its own profile.
- **qemu#15 (magenta dlight cast) -- closed, not reproducible.** The
  ticket's own discriminating test (`gl_dynamic 1 gl_flashblend 0 map
  base1`, screendump) re-run directly on b60a6d9936: spawn frame and a
  frame with an active muzzle-flash dlight (fired the blaster via monitor
  `sendkey ctrl` three times) both render with completely normal colours --
  no purple/magenta anywhere in world, viewmodel or HUD. Bug was first
  seen on 3ee0d25a81; the install has since moved through qemu#2/#3/#5/#6/#7,
  several of which touched `r300_render`/`r300_to_vram`, so one of those
  likely fixed it incidentally. Closed without chasing hypothesis A vs B.

**Board after this session: Measuring/Ready/In progress empty for
QemuMac/qemu/ppcosxkvm.** Only the four Blocked watch items remain
(qemu#1, #11, #13, #14) -- none reproduced or actionable this session,
left alone per standing guidance. Nothing new filed to Triage.

**Gotcha hit and fixed inline, worth remembering:** `qemu-profile.sh` and
`bench.sh` both contend for the `qemu-tiger3d` picker claim if run as the
docs suggest (`profile.sh & bench.sh`) while something else already holds
it -- with today's fleet-wide contention on this one VM, that raced. Fix:
acquire the claim yourself first (`pick-bench-host.sh --acquire
qemu-tiger3d <label>`), then export `RETRO_BENCH_LOCK=qemu-tiger3d` before
invoking `bench.sh`/`screenshot.sh` directly (not through their own
re-exec) -- that env var is exactly the "claimed further up the chain"
bypass both scripts already support. Also: don't name a shell variable
`PPID` for a captured `$!` -- it's a bash read-only special variable, and
the assignment fails silently in a way that looks like an unrelated
"busy" error if you're staring at a stale log file instead of the actual
exit code.

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
