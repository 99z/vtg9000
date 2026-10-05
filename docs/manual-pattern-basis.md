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

The core now supplies native 480i/240p timing while MiSTer owns any further
HDMI scaling, so all three are exposed as explicit menu choices in either
native scan mode. The `Invert /
SMPTE Blue` option behaves as blue-only mode on SMPTE and as ordinary inversion
on patterns that support inversion.

## Standalone PLUGE

The manual defines:

- nominal black surround
- left reference bars at -2%, +4%, and +2%
- right reference bars at +2%, +4%, and -2%
- center boxes at 25%, 50%, 75%, and 100%
- a 95% box inset inside the 100% box

An unsigned full-range RGB path cannot encode a value below code zero. This
implementation therefore treats code 16 as nominal black and code 235 as 100%,
yielding these nearest 8-bit codes:

| Relative level | Code |
| ---: | ---: |
| -2% | 12 |
| black | 16 |
| +2% | 20 |
| +4% | 25 |
| 25% | 71 |
| 50% | 126 |
| 75% | 180 |
| 95% | 224 |
| 100% | 235 |

This preserves the digital ordering required for brightness and contrast
adjustment. Producing or measuring a negative analog voltage remains a property
of the selected MiSTer output adapter and signal path.

## Output-rate boundary

The RTL selects native 720x480i59.94 or 720x240p60.05, with 480i as the default.
MiSTer's configuration/scaler owns higher-resolution HDMI output. Frequency and
alternating-pixel patterns are defined on the native 13.5 MHz logical sample
grid and cannot make native-rate bandwidth claims after scaler resampling.
