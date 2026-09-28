# The qemu-tiger3d VM: config, numbers and ownership

The `vms/power_mac_g4_tiger_3d` guest, its latest measured numbers, and the rules for validating
on it and sharing it. Sections: VM, Latest numbers, Rules, Final validation and concurrent VM ownership.

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
