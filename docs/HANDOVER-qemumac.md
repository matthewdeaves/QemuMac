# Handover: qemumac fleet agent

You (the "qemumac" agent in `~/Documents/retro-agents`) own **QemuMac**, the
**qemu radeon-9700 fork**, and the **ppcosxkvm** fork. Never PR upstream
(qemu/qemu, linuxkid473/\*) — only matthewdeaves/\* repos. Never force-push
`radeon-9700` except for a release rebase. One VM at a time on the bench
disk; claim `qemu-tiger3d` through the fleet picker like real hardware.

## radeon-9700 branch state

- Repo: `github.com/matthewdeaves/qemu`, branch `radeon-9700`, on QEMU v11.1.1.
- Tip: `a824d07101` (README update). The prior tip, `b5d2ac4f4a`, is the sha
  to build into `qemu-install/` for fleet benches — build hosts should
  rebuild at whichever of these is current; `README.radeon-9700.md`
  describes the branch and how to rebase it onto a new release.
- Adds: ATI Radeon 9700 PRO for `mac99` (3D via Metal), Screamer audio,
  Cocoa fixes, PowerPC TCG speedups (host-FPU fast path, inline FPRF,
  lmw/stmw, lfs/stfs conversion). `git log --oneline v11.1.1..radeon-9700`
  lists every commit.
- Today's work (`1b80c30115..b5d2ac4f4a`): quiet-by-default logging
  (`PPCGPU_DIAG`, `PPCGPU_RATE`) and dead code removed; a linear-fog fix
  (was greying out Quake II); `R300_DRAWLOG` records fog state;
  static-analysis fixes (Metal leaks in the legacy draw path, logger format
  checks, clip planes via memcpy); cheaper per-draw Metal lookups; repeated
  vertex index transformed once per draw; inline lfs/stfs conversion;
  vertex program decoded once per draw (1.99x interpreter speed); 2D blits
  from system RAM a page at a time; textures rehashed only on written
  pages; a sampler eviction use-after-free fix.
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
   reproduced on `b5d2ac4f4a`. Blocked/watch — don't work it until
   reproduced.
2. [#2](https://github.com/matthewdeaves/qemu/issues/2) — under Quake II,
   the guest rewrites identical bytes into bound-texture VRAM every frame;
   find out why. (speed, after #5/#6)
3. [#3](https://github.com/matthewdeaves/qemu/issues/3) — vertex path
   (`draw_core`/`r300_pvs_run`) still 5-10% of the guest CPU thread.
   (speed, after #5/#6)
4. [#4](https://github.com/matthewdeaves/qemu/issues/4) — per-draw Metal
   encoding, CPU-side clears/resolves, full-frame display refresh.
   (speed, after #5/#6)
5. [#5](https://github.com/matthewdeaves/qemu/issues/5) — BQL held during
   scratch/fence poll sleep; reset race from an earlier Codex review.
   (correctness, do first)
6. [#6](https://github.com/matthewdeaves/qemu/issues/6) — Metal init
   error-path leaks; unchecked mallocs in `r300_draw.c`. (correctness, do
   first)
7. [QemuMac #15](https://github.com/matthewdeaves/QemuMac/issues/15) —
   rebuild `qemu-install` at the radeon-9700 tip for fleet benches.
   **Board: Done. GitHub issue: still open, not yet closed.** Build itself
   is finished and verified (see below) and the sha/hash were mailed to
   buildhost for build-host#122 (buildhost confirmed receipt and logged
   it). What's left: claim `qemu-tiger3d` (was busy with quakespasm/
   buildhost bench runs each time this was attempted this session), boot
   it with `qemu-vm.sh up`, confirm ssh on 2222 reaches the guest, post
   one evidence comment on the GitHub issue with the source sha, the
   `shasum -a 256` of `qemu-system-ppc`/`qemu-system-m68k` below, and the
   ssh proof, then close the issue and release the claim. Don't rebuild
   again first — the install already matches a824d07101.
8. [QemuMac #16](https://github.com/matthewdeaves/QemuMac/issues/16) — no
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

`qemu-install/` current build (this session, radeon-9700 tip
`a824d07101`, QEMU 11.1.1, built and verified by `install-deps.sh` option
3 — Radeon 9700 + Screamer both detected):

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
