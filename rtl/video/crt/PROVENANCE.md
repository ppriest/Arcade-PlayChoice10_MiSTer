# rtl/video/crt — provenance

Author: Umberto Parisi (rmonic79). GPL-3.0-or-later.

`crt_adjust.sv` is copied unchanged from `Arcade-KonamiGX_MiSTer` at `6624be2` (`rtl/video/crt/`),
which copied it from `Arcade-Psikyo_MiSTer` `8e39bb6`, which vendored it from
`rmonic79/Arcade-Raiden_MiSTer`, `rtl/Raiden/crt_adjust.sv`.

## Local changes

Marked `LOCAL FIX` in the file (Psikyo's): `hoff_s`'s `?:` kept signed, or a negative
H-Position is zero-extended and blanks the picture.

The glue, `rtl/video/pc10_crt_chain.sv`, is GX's `gx_crt_chain.sv` with the pixel at a fixed
4 clocks.
