# Quartus build and MiSTer deployment history

Recorded 2026-09-04 on Ubuntu 24.04.

## Build

- Builder: rootless Podman 4.9.3
- Image: `docker.io/theypsilon/quartus-lite-c5:17.0.2.docker0`
- Quartus: 17.0.2 Build 602 Lite Edition
- Target: Cyclone V `5CSEBA6U23I7`
- Full compilation: successful, zero errors
- Pixel PLL: 25.200 MHz from 50 MHz (`63 / 5 / 25`)
- Pixel clock period reported by TimeQuest: 39.682 ns
- Worst setup slack: +0.722 ns overall; +18.516 ns for the pixel clock
- Worst hold slack: +0.245 ns
- Logic utilization: 7,321 / 41,910 ALMs (17%)
- RBF size: 2,464,056 bytes
- RBF SHA-256:
  `26779ba3741e437dd863caf78e9f91eca501aa12c7d3e64c074b86dfb32a6770`

Quartus reported the upstream MiSTer framework's customary unused-port and
ignored-assignment warnings. All 12 discovered clocks were constrained. The
remaining unconstrained paths were unused/general framework I/O ports, not the
pixel clock domain.

Before compilation, the container wrapper copies only HDL/compiler inputs to a
temporary directory. The third-party image runs with networking disabled and
cannot see the project's `.local/` SSH key or the Extron reference files.

## Deployment

The first RBF was copied without overwriting any existing core:

```text
/media/fat/_Utility/VTG400_20260904.rbf
```

The SHA-256 was recomputed on the MiSTer and matched the local artifact. The
MiSTer root filesystem remained read-only after deployment. The core was not
automatically loaded; HDMI/OSD behavior remains pending physical observation.

## Dedicated SSH key

A project-only Ed25519 public key (`vtg400-mister-dev`) was added to the MiSTer
root account with explicit user approval. Before changing the read-only Linux
image, the original was copied to:

```text
/media/fat/linux/linux.img.pre-vtg400-key-20260904
```

Key-only login was verified, and `/dev/loop8` was remounted read-only after the
change. The private key remains ignored under `.local/` on the Ubuntu host.

## Manual-aligned revision 2

Revision 2 adds distinct graphics split bars, NTSC-style SMPTE bars with a
blue-only mode, PAL-style EBU bars, and a manual-aligned standalone PLUGE. It
also corrects the coarse crosshatch, split grayscale, circles, 4x4
checkerboard, safe-area, and focus-pattern geometry. The source raster remains
640x480p60; MiSTer's video configuration/scaler controls physical 480i or
higher-resolution output.

Before release, all 15 golden-frame hashes, the timing/assertion simulation,
pattern lint, top-level syntax lint, and the `sys/` framework guard passed.
Quartus 17.0.2 completed with zero errors and reported:

- exact 25.200 MHz pixel clock (39.682 ns)
- worst setup slack: +0.693 ns overall; +15.647 ns in the pixel domain
- worst hold slack: +0.246 ns
- logic utilization: 7,689 / 41,910 ALMs (18%)
- DSP utilization: 50 / 112 (45%)
- RBF size: 2,442,024 bytes
- RBF SHA-256:
  `238f3cfe293cde66fb29caf10fc66a1546c2826259ba5d61b3564341cf173e5c`

The revision was copied without overwriting the first core:

```text
/media/fat/_Utility/VTG400_20260904_r2.rbf
```

The SHA-256 was recomputed on the MiSTer after `sync` and matched the local
release artifact. This records successful transfer, not hardware validation;
loading the exact RBF and observing its output remain pending.

## VTG9000 controls release

Recorded 2026-09-05. The project, Quartus revision, top-level source, core
module, and generated RBF were renamed from VTG400 to VTG9000. Historical
VTG400 filenames above remain unchanged because those artifacts are retained
as rollback builds.

This release adds OSD-synchronized keyboard and controller controls:

- Left/Right or either controller D-pad: previous/next pattern with wraparound
- Up/Down or either controller D-pad: level +/-1%, clamped to 0-100%
- Page Up/Page Down: level +/-10%
- Home/End: level 0%/100%
- I: invert or SMPTE blue-only; R: raster border
- four remappable controller actions, defaulting to A/B/X/Y: invert, border,
  level +10%, and level -10%
- held directions: 500 ms initial delay, then 100 ms repeat

The pattern and control simulations, both lint passes, top-level syntax check,
all 15 golden-frame hashes, and the `sys/` framework guard passed. Quartus
17.0.2 completed with zero errors and reported:

- exact 25.200 MHz pixel clock (39.682 ns)
- worst setup slack: +0.659 ns overall; +18.739 ns in the pixel domain
- worst hold slack: +0.247 ns
- logic utilization: 7,983 / 41,910 ALMs (19%)
- registers: 11,537
- block memory: 384,493 / 5,662,720 bits (7%)
- DSP utilization: 50 / 112 (45%)
- RBF size: 2,453,624 bytes
- RBF SHA-256:
  `5fc41bed1c065798e6498f148896c4028a72566cfdc6d7f131bfbd1843fdc1e7`

The new release was copied without overwriting either VTG400 build:

```text
/media/fat/_Utility/VTG9000_20260905.rbf
```

The SHA-256 was recomputed on the MiSTer after `sync` and matched the local
release artifact. Hardware observation of the exact RBF remains pending.

## Native 480i/480p release

Recorded 2026-09-05. This release replaces the original 640x480p-only raster
with native 720x480 timing and adds an OSD `Scan Mode` selector. Its default is
480i; the alternate is 480p. The core does not condition that choice on
MiSTer's `direct_video` flag because the SuperStation One's internal analog DAC
also receives native core timing when `vga_scaler=0`.

The 480i path uses a 27 MHz transport clock, a 13.5 MHz logical sample enable,
alternating 262/263-line fields, a half-line vertical-sync offset, 240 active
lines per field, and `VGA_F1` field parity. Direct Video therefore receives a
1440-sample super-resolution line. The 480p path uses every 27 MHz clock with
858x525 totals. Both modes have a 59.94 Hz field/frame cadence as applicable.
MiSTer's scaler remains responsible for higher-resolution HDMI output.

The timing and pattern simulation, controls simulation, both lint passes,
top-level syntax check, all 15 updated 720x480 golden-frame hashes, and the
`sys/` framework guard passed. Quartus 17.0.2 completed with zero errors and
reported:

- exact 27.000 MHz pixel transport clock (`54 / 5 / 20`)
- worst setup slack: +0.411 ns overall; +10.018 ns in the video clock domain
- worst hold slack: +0.253 ns
- logic utilization: 8,075 / 41,910 ALMs (19%)
- registers: 11,666
- block memory: 384,447 / 5,662,720 bits (7%)
- DSP utilization: 56 / 112 (50%)
- RBF size: 2,453,968 bytes
- RBF SHA-256:
  `aab275a69449cc38a40d71ffefcdebb9f327e02875644cd3c67d4645bd045b34`

The release was copied without overwriting the previous working build:

```text
/media/fat/_Utility/VTG9000_20260905_r2.rbf
```

After `sync`, the size and SHA-256 were recomputed on the MiSTer and matched
the local artifact. This verifies the transfer, not yet the HDMI or CRT output;
hardware observation of this exact RBF remains pending.

## 15 kHz CRT timing correction

Recorded 2026-09-05 after testing the preceding release on a 15 kHz CRT. The
observed 480i picture locked horizontally but moved vertically between fields.
The menu's alleged 240p alternative did not lock because that release actually
generated 31.469 kHz 480p.

This revision replaces the approximate whole-line interlace with a continuous
858x525 raster. Field 1 occupies exactly 262.5 lines; `VGA_F1` and the second
vertical-sync interval change at sample 429 of line 262; field 2 occupies the
remaining 262.5 lines. Both fields contain 240 complete active lines. The
alternate mode is now genuine 858x262 240p at the same 13.5 MHz logical sample
rate. Both modes use the 27 MHz transport clock with each logical sample held
for two clocks.

At deployment time, the MiSTer settings were read but not changed:

```text
vga_mode=subcarrier
composite_sync=0
vga_scaler=0
direct_video=0
forced_scandoubler=0
video_mode=0
vsync_adjust=0
```

The timing/pattern and controls simulations, both lint passes, top-level syntax
check, all 15 canonical 720x480 golden-frame hashes, and the `sys/` framework
guard passed. Quartus 17.0.2 completed with zero errors and reported:

- exact 27.000 MHz pixel transport clock (`54 / 5 / 20`)
- worst setup slack: +0.500 ns overall; +8.582 ns in the video clock domain
- worst hold slack: +0.258 ns
- logic utilization: 8,097 / 41,910 ALMs (19%)
- registers: 11,719
- block memory: 384,447 / 5,662,720 bits (7%)
- DSP utilization: 56 / 112 (50%)
- RBF size: 2,455,416 bytes
- RBF SHA-256:
  `98917e1c08894add1c0484e95d3e34d2e2fc61826f65fe845c1d2dc38081c3e1`

The release was copied without overwriting either earlier VTG9000 build:

```text
/media/fat/_Utility/VTG9000_20260905_r3.rbf
```

After `sync`, the size and SHA-256 were recomputed on the MiSTer and matched the
local artifact. The exact RBF was then loaded through `/dev/MiSTer_cmd`, and
MiSTer's runtime identified the active core as `VTG9000`. Visual confirmation
of corrected 480i and 240p behavior on the CRT remains pending.
