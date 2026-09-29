# VM and shared-disk safety

## Preflight before writes
Run every failing check before creating anything. A present `HD_IMAGE` means installed, so creating a blank image before a later `die()` strands a drive. `die()` inside `$(...)` exits only the subshell: check its status. An explicit `--iso` takes precedence over `DEFAULT_INSTALLER`.

## Shared disk and VM identity
The shared disk permits one writer. `disk_in_use()` returns 0 for in use, 1 for free, 2 for unknown. Unknown is not free: gate writes on `shared_disk_is_writable()`.
Assign a unique `MAC_ADDRESS` to each VM. Multi-threaded TCG is unstable and stays off. Never delete `qemu-install/` or `vms/`.

## QEMU feature gates
`QEMU_MIN_VERSION` permits unconditional arguments; probe only newer features. Raising the minimum needs the user's decision.
For `DISPLAY_GPU="radeon9700"`, probe `qemu_has_radeon` and `qemu_has_screamer`. Run `require_radeon` before `preflight_checks`. Add the card at slot 0x0E before other PCI devices. Never send Cocoa-only display suboptions to SDL.
