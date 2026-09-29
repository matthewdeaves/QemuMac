# Tiger VM performance evidence

Recorded qemu-ppc numbers and concurrent-claim validation limits.
Guest configuration and runtime rules remain in `docs/vm-tiger3d.md`.
These dated results describe their artifacts and do not certify an installed build today.

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
