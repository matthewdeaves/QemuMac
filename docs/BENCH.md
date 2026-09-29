# Profile and benchmark the emulator

## Commands

```bash
# Profile (macOS `sample` of QEMU during a game; guest-CPU-thread top
# functions and Radeon share):
old-mac-quakespasm/scripts/qemu-profile.sh <quakespasm|quake2|ioquake3-bench> [seconds] [out]

# Bench (each Quake port):
<port>/scripts/bench.sh qemu-tiger3d <demo> 1024x768 1   # Q1/Q2: demo1, Q3: four
```

Debug switches `R300_DRAWLOG`, `PPCGPU_DIAG`, `PPCGPU_RATE` and `R300_DUMP` cost FPS and must be off for benchmarks.
See `docs/vm-tiger3d.md` for host-load and validation limits.
