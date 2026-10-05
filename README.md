# VTG9000 MiSTer

An open, clean-room MiSTer pattern-generator core inspired by the useful
behavior of the Extron VTG 400 DVI. The project separates deterministic digital
pattern/timing behavior from the electrical performance of the attached DAC.

This repository does not contain or execute Extron firmware.

## Current video modes

- default native mode: 720x480 interlaced, 525 lines per complete frame,
  15.734 kHz horizontal and 59.94 fields/s
- two exact 262.5-line fields with 240 complete active lines per field, a
  half-line field/vertical-sync offset, and parity exported through `VGA_F1`
- Direct Video transport: 27 MHz with each 13.5 MHz logical sample repeated
  twice, yielding a DAC-friendly 1440-sample super-resolution line
- selectable alternate: 720x240 progressive, 858x262 total at 13.5 MHz,
  15.734 kHz horizontal and 60.05 frames/s
- negative H/V sync in both modes
- no core framebuffer, scaler, gamma, filtering, or deinterlacer
- ordinary MiSTer HDMI framework output and Direct Video-compatible native RGB
- selectable RGBHV or RGBS
- 8-bit RGB with nearest-code 0-100% level control
- independent RGB channel disables, inversion, and raster border
- keyboard and controller navigation with OSD-synchronized pattern/level state
- 15 initial algorithmic patterns:
  8-color split bars, SMPTE bars with PLUGE, EBU full bars, flat field,
  crosshatch, grayscale, ramp, alternating pixels, window, circles,
  standalone PLUGE, multiburst, checkerboard, safe area, and focus patches
- simulator timing assertions and PPM frame generation

The pattern set is an initial implementation, not yet a claim of pixel-exact
VTG 400 equivalence. The color-bar variants and PLUGE geometry are based on the
VTG 400D/400 DVI manual. PLUGE uses a 16-235 digital reference range so -2%,
+2%, and +4% relative-to-black values remain representable; actual analog
below-black voltage depends on the output adapter and MiSTer video settings.

`Scan Mode` defaults to native 480i and can be changed to native 240p in the
MiSTer menu. With `vga_scaler=0`, MiSTer's analog output receives that native
mode. With `direct_video=1`, a compatible HDMI-to-analog DAC receives the same
native mode over HDMI. Ordinary HDMI output remains compatible with MiSTer's
scaler, which can deinterlace/scale the core to the configured 720p, 1080p, or
other display mode. Thus higher output resolutions remain supported without
pretending that they are new native calibration rasters.

All patterns are generated directly on the 720x480 logical sample grid.
Pixel-clock stress patterns describe that native grid; after HDMI scaling they
cannot make native-rate bandwidth claims about the scaled output.

## Source layout

- `VTG9000.sv` - MiSTer framework glue, OSD, and direct controls
- `rtl/` - portable raster and pattern logic
- `tb/` - Icarus/Verilator-compatible simulation tests
- `docs/` - firmware evidence, manifest, and extracted 113-rate catalog
- `tools/` - reproducible evidence extraction utilities
- `sys/` - unmodified upstream MiSTer framework

The framework is pinned from
`MiSTer-devel/Template_MiSTer@3ea1134cf05d62c2b1db30362277a823d739ced2`
(2026-08-26). Do not make core-specific changes under `sys/`.

## Install the simulation toolchain on Ubuntu 24.04

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake ninja-build iverilog verilator \
  gtkwave binutils jq nmap net-tools avahi-utils openssh-client rsync socat
```

Then run:

```bash
make test
make lint
make frames
make verify-frames
```

Generated PPMs appear under `build/frames/` and are suitable for pixel-level
hash comparison or visual inspection.

## Direct controls

The OSD and direct controls share the same settings:

The OSD-only `Scan Mode` option selects `480i (15 kHz)` or `240p (15 kHz)`.
Its zero/default state is 480i. Changing it resets only the raster timing and
notifies MiSTer's video framework that the native mode changed.

In 240p, each physical line samples the corresponding even row of the canonical
720x480 pattern grid. This preserves full-frame pattern proportions while
keeping the path direct and framebuffer-free.

| Keyboard | Controller | Action |
| --- | --- | --- |
| Left / Right | D-pad Left / Right | Previous / next pattern, with wraparound |
| Up / Down | D-pad Up / Down | Raise / lower level by 1% |
| Page Up / Page Down | Remappable Level +10% / -10% buttons | Raise / lower level by 10% |
| Home / End | - | Set level to 0% / 100% |
| I | Remappable Invert button | Toggle inversion or SMPTE blue-only mode |
| R | Remappable Raster Border button | Toggle the raster border |

Held directions repeat after 500 ms and then every 100 ms. Either of the first
two controllers can navigate. The four named controller actions default to
A/B/X/Y and can be rebound with MiSTer's normal per-core input mapping; D-pad
directions use the controller's standard directional mapping.

## Quartus build

MiSTer currently requires Quartus 17.0.2 for maintainable release builds. The
compiler is not bundled here. After installing it, build from a shell with:

```bash
quartus_sh --flow compile VTG9000
```

On a modern Linux host, the supplied container wrapper is preferred:

```bash
sudo apt-get install -y podman
./tools/quartus_container_build.sh
```

The first run downloads the Quartus 17.0.2 image and is several gigabytes.

The wrapper stages only compiler inputs in a temporary directory, runs the
container without networking, and copies the results to `build/quartus/`. It
does not expose `.local/`, firmware, or reference material to the image.

The most recent released build produced `build/quartus/VTG9000.rbf` with
Quartus 17.0.2 and positive setup/hold slack. See
`docs/build-and-deployment.md` for the reproducible records.

## Accuracy language

Simulation can verify raster totals, sync widths/polarities, pixel placement,
and 8-bit code values. It cannot verify DAC voltage, 75-ohm source impedance,
bandwidth, edge shape, channel matching, or jitter. Those claims require a
named adapter/revision and measurements into a proper 75-ohm load.

## Near-term roadmap

1. Validate the manual-corrected color bars and PLUGE on the target 480i CRT.
2. Align the remaining initial patterns to the manual's detailed diagrams.
3. Expand from the initial 15 choices toward the full manual pattern chart,
   keeping rate-specific variants explicit rather than adding a rate selector.
4. Add per-DAC characterization profiles before making analog accuracy claims.
