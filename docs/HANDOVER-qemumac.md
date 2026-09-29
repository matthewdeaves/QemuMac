# Handover: qemumac fleet agent

Current session state only (the newest entry below). Older entries are in
`docs/archive/`. Reference docs: `radeon-branch.md` (branch, scope, open items),
`build-test-bench.md` (commands), `vm-tiger3d.md` (VM, numbers, ownership rules).

## 2026-09-29 session: round qemu-ppc done except the user's look

State: radeon-9700 tip `6f0f80cd` is installed and running on qemu-tiger3d
(`qemu-system-ppc` sha256 `4c39fd42...`), CI green. Closed this session:
qemu#24 (GPU vertex programs, Q3 +20 fps), qemu#26 (AltiVec on NEON, Q3 +9 fps
interleaved), qemu#25 (ring is 0.2% of the vCPU: not ported). qemu#1 was already
closed. QemuMac#23 has the baseline, final table and the 1-hour soak (0 IB lost,
0 deferrals, 0 dead ssh); item 4, the user's live look, is the only thing open.

Open follow-ups: qemu#27 (CI step for tests/ppc-vmx on local branch `qemu26-ci`;
needs `gh auth refresh -s workflow`, user). build-host#153 (launch-game "no pid
within 90s" flake; shared-v29 reports why and retries). alephone was mailed that its
round leaves Aleph One running. Aleph One needs a vsync-off run from its port to
measure cost. qemu#13/#14 stay Blocked.

How the A/B was done (reuse it):
- Build an install without losing `qemu-source`'s local branches: clone QemuMac to a
  scratch dir, `printf '3\n1\n' | ./install-deps.sh` there (edit `RADEON_QEMU_BRANCH` in
  `lib/common.sh` to test an unpushed branch), then under a claim `qemu-vm.sh down`,
  `rsync -a <scratch>/qemu-install/ qemu-install/`, `qemu-vm.sh up`.
- One-sided runs get HOST-LOAD-DIFFERS. Interleave A B A B, restarting the VM onto each
  install, and pass all bundles per side to `bench-compare.sh`.
- `bench-evidence` adapters are synchronous and capture no frame: take host-side
  `qemu-vm.sh screendump` mid-run; Half-Life's timerefresh draws no frames, launch it live.
- Scratch under ~/oldmac/qemu26-scratch (drivers `run-baseline.sh`, `abab.sh`, `soak.sh`);
  delete once QemuMac#23 closes.
