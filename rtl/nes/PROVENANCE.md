# rtl/nes: NES_MiSTer

- Upstream: https://github.com/MiSTer-devel/NES_MiSTer
- Commit: `49a0a662e244469ca77b2155746a066df704ffae`
- Licence: GPL-3.0 (`COPYING` in the upstream root; file headers say "GPL Licensed").
- Taken: everything under upstream `rtl/` except the PLL, which is at `rtl/pll.v`,
  `rtl/pll.qip` and `rtl/pll/` here, unchanged. Upstream `NES.sv` became `PlayChoice10.sv`,
  `NES.sdc` became `PlayChoice10.sdc`.

## Local changes

| File | Change |
|---|---|
| `video.sv` | `.mif` path `rtl/tao.mif` to `rtl/nes/tao.mif`; input `rgb_ppu`: an emphasis bit forces its channel to 0xFF on every colour, as MAME's RGB PPUs. `video_upstream_reference.sv` is the upstream file. |
| `nes.v` | PlayChoice-10 BIOS control: inputs `pc10_cpu_reset` (T65 `res_n` only), `pc10_cpu_halt` (gates T65's enable), `pc10_ppu_reset` (ORed into the PPU's reset), `pc10_cart_reset` (ORed into the mapper's reset), output `pc10_ppu_nmi` (the PPU's NMI, for INT DETECT). `nes_upstream_reference.v` is the upstream file. |
| `mappers/MMC2.sv` | MMC2 (mapper 9) gets 8 KB of RAM at $6000-$7FFF when the header's battery bit is set, as MMC4 has, for PlayChoice-10 Punch-Out!! (upstream issue 390). `MMC2_upstream_reference.sv` is the upstream file. |
| `PlayChoice10.sv` (from `NES.sv`) | header, core name in CONF_STR, `.mif` path `rtl/nes/loopy_NSF.mif` |
| `PlayChoice10.sdc` (from `NES.sdc`) | none |
