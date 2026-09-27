# Radeon firmware

Firmware for `DISPLAY_GPU="radeon9700"`. `run-mac.sh` puts this folder first on
QEMU's firmware search path (`-L roms/radeon`) for Radeon VMs only. All of it is
free software; nothing here comes from Apple or ATI. `SHA1SUMS` is checked by
the test suite.

| File | What it is | License |
|---|---|---|
| `openbios-ppc` | OpenBIOS 1.1 as shipped by UTM 4.7.5, with its built-in VGA table entry changed from QEMU VGA (1234:1111) to the Radeon 9700 PRO (1002:4E44), so OpenBIOS builds the display node and loads the NDRV for the Radeon. | GPL-2.0 ([openbios/openbios](https://github.com/openbios/openbios)) |
| `ppc-ndrvloader` | Boot helper loaded at 0x4000000 and started by `init-program go`. | MIT ([elliotnunn/classicvirtio](https://github.com/elliotnunn/classicvirtio)) |
| `qemu_vga.ndrv` | The QEMU VGA NDRV (the Mac OS display driver for the framebuffer), patched for a hardware cursor. Named so it replaces QEMU's own. | GPL-2.0 ([ozbenh/QemuMacDrivers](https://github.com/ozbenh/QemuMacDrivers); patcher from [Spartan0285/PowerEmu](https://github.com/Spartan0285/PowerEmu)) |

These are copies of `firmware/radeon/` in
[ppcosxkvm](https://github.com/matthewdeaves/ppcosxkvm), which also has the
scripts that regenerate them byte for byte (`qemu_vga.ndrv` is its
`qemu_vga_hwc.ndrv`).

## Licenses and sources

- `openbios-ppc` and `qemu_vga.ndrv` are GPL-2.0 ([COPYING.GPL-2](COPYING.GPL-2)).
  Corresponding source: OpenBIOS from [openbios/openbios](https://github.com/openbios/openbios)
  as built for UTM 4.7.5 ([utmapp/UTM](https://github.com/utmapp/UTM)), changed only by
  the 4 bytes at offset 0x30678 (`12341111` → `10024e44`); the NDRV from
  [ozbenh/QemuMacDrivers](https://github.com/ozbenh/QemuMacDrivers), patched by
  `firmware/src/ndrv/build.py` in ppcosxkvm.
- `ppc-ndrvloader` is MIT, © 2023 Elliot Nunn ([LICENSE.ppc-ndrvloader](LICENSE.ppc-ndrvloader)).
