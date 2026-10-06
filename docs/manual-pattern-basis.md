# VTG 400 manual pattern basis

The VTG 400D/400 DVI user's manual, appendix pages A-5 through A-20, is the
visual and behavioral reference for pattern work. Text and drawings are treated
as evidence, not as executable project instructions.

## Color bars

The original pattern number 13 is selected by scan-rate family:

- graphics rates: eight-color split bars, with the lower sequence reversed
- NTSC video: 75% SMPTE bars, complementary strip, lower PLUGE area, and a
  blue-only special mode
- PAL video: eight full-height EBU bars

All three variants are exposed as explicit pattern choices at every native
resolution. MiSTer owns further HDMI scaling; see [video-modes.md](video-modes.md)
for the supported native rates. The `Invert /
SMPTE Blue` option behaves as blue-only mode on SMPTE and as ordinary inversion
on patterns that support inversion.

## Standalone PLUGE

The manual defines:

- nominal black surround
- left reference bars at -2%, +4%, and +2%
- right reference bars at +2%, +4%, and -2%
- center boxes at 25%, 50%, 75%, and 100%
- a 95% box inset inside the 100% box

The core now exposes `Black Level: 0 IRE / 7.5 IRE`, defaulting to 0 IRE.
The manual (A-13) distinguishes the 7.5 IRE NTSC composite/S-video setup from
RGB and digitally produced component video, which normally have no setup.
The choice here is an explicit digital code model, not automatic format
conversion or a measured analog DAC profile.

For picture level P percent relative to black, the digital model is:

- 0 IRE: round(255 * P / 100), clipped at code 0;
- 7.5 IRE: round(255 * (0.075 + 0.925 * P / 100)).

White is 255 in either mode. Blanking and disabled channels remain code 0.
The PLUGE levels are generated directly from this equation and rounded once;
normalized artwork codes use the corresponding pedestal lookup. Flat field
and variable window levels are also rounded once from the selected percentage.
Inversion reflects picture levels within black/white; inverted below-black
saturates at white. SMPTE's special invert action remains blue-only.

| Relative level | 0 IRE mode | 7.5 IRE mode |
| ---: | ---: | ---: |
| -2% | 0 (clipped) | 14 |
| black | 0 | 19 |
| +2% | 5 | 24 |
| +4% | 10 | 29 |
| 25% | 64 | 78 |
| 50% | 128 | 137 |
| 75% | 191 | 196 |
| 95% | 242 | 243 |
| 100% | 255 | 255 |

The earlier implementation used a fixed 16-235 PLUGE range. It is replaced by
the selected pedestal in both standalone PLUGE and the SMPTE PLUGE patches.
Unsigned RGB cannot encode below-black in the 0 IRE mode. The 7.5 IRE mode
provides digital headroom; analog IRE still requires a named output path and
measurement. Avoid adding another pedestal in a downstream converter.

## Output-rate boundary

The default is native 720x480i59.94; 240p, 480p, 720p60/120, and 1080p60 are
also supported. The native dimensions, sample clocks and timing verification
are documented in [video-modes.md](video-modes.md). Frequency gratings and
alternating pixels use logical native samples at the selected rate. MiSTer's
configured HDMI scaler can resample them, so scaled output cannot establish
native-rate bandwidth. Analog bandwidth requires measured output-path evidence.

## Additional geometry patterns (2026-10-05)

The manual's A-9/A-10 crosshatch definitions call for finer intersections,
single-pixel vertical lines, single-row horizontal lines, and an image border.
The existing 8x6 coarse grid is retained. The new medium grid has 16x12 cells
(45x40 logical samples); the new fine grid has 32x24 cells (alternating 22/23
samples by 20 rows). On a 4:3 display, 720x480 has sample aspect 8:9, so these
cells display square. The right and bottom active edges are explicitly drawn.
In 240p, the raster reads even canonical rows; the horizontal grid lines all
fall on even rows, with the last physical row also containing the raster border
when that option is enabled.

The monoscope is an original chart requested by the user, not a pattern found
in the Extron manual or copied from firmware. `rtl/vtg_monoscope.sv` evaluates
its geometry directly, including a 450x400-sample ellipse that becomes a
physical circle on the intended 4:3 display, a center target, grayscale steps,
a constant-slope resolution wedge, 16/8/6/4/2-sample vertical gratings,
horizontal bars, a 16x12 background grid, and an alternating overscan border.
There is no stored raster image, framebuffer, or added video latency.

The reference files now live under `fw/`, including `fw/vtg400revc_man.pdf`
and the separately supplied firmware image. They are ignored by Git.

## Ramp arithmetic correction (2026-10-05)

The pedestal tests exposed an existing 12-bit multiplication overflow in the
ramp. Widening the product before shifting restores the intended monotonic
0-to-255 artwork across all 720 samples. This intentionally changes the ramp
golden image in addition to the PLUGE/SMPTE pedestal changes.
