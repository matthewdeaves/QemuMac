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

`qemu-install/` current build (radeon-9700 tip `6f0f80cd`, QEMU 11.1.1,
built by `install-deps.sh` option 3, CI green on that commit; includes the
qemu#1 fix, qemu#24 GPU vertex programs and qemu#26 AltiVec on NEON; BUILD_INFO
records commit and sha):

```
qemu-system-ppc  sha256=4c39fd42994f68075d29e27a3172da82dac0838f9045a83b35fa2a6c103db0be
qemu-system-m68k sha256=ddc20f06fca6c1fab1529914508127982442c78b00b2c7dad63fcfc6b744ddb0
```

`install-deps.sh` replaces `qemu-source/` with a fresh shallow clone: to keep
local branches there, run it in a scratch clone of QemuMac and rsync its
`qemu-install/` over the real one (under a claim, VM down first).

## Latest numbers

Round qemu-ppc, 2026-09-29, `bench-compare` verdicts, 1024x768, vsync off,
load < 6, 5 VALID rounds a side (QemuMac#23 has the table and bundles):

- Quake III four: 103.9 fps (`70fed303`) -> 123.9 (`8317eb56`, qemu#24) ->
  133.6 (`6f0f80cd`, qemu#26; interleaved A/B against `8317eb56`, BETTER).
- QuakeSpasm demo1: 85.1 -> 90.1 -> 91.6. Quake II demo1: 79.7 -> 79.1 -> 80.8
  (no change). Half-Life timerefresh about 125-130 (no change). Aleph One
  60 (vsync-quantised, does not measure cost).
- Ring execution is 0.2% of the vCPU thread on Q3 (qemu#25 measured, not
  ported); the rest is TCG and TLB flushing.

Host load swings results widely: only interleaved A/B (restart the VM onto
each install in turn, same load) or a `bench-compare` verdict without
HOST-LOAD-DIFFERS is a result. VM fps is never release or floor evidence.

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
