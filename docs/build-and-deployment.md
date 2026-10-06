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

## Black-level, geometry, and sync release R4

Recorded 2026-10-05. This release adds selectable 0 IRE / 7.5 IRE digital
black pedestals, medium (16x12) and fine (32x24) crosshatches, and an original
procedural monoscope chart. It removes the core RGBHV/RGBS selector and always
supplies separate native H/V sync to the MiSTer framework, which applies
MiSTer.ini output settings. Raster timing, pixel enables, and `sys/` are unchanged.

An expanded arithmetic test exposed a pre-existing 12-bit product overflow in
the ramp. Widening the multiplication restores a monotonic black-to-white
ramp. PLUGE and SMPTE PLUGE now use the selected pedestal instead of the prior
fixed 16-235 range; 0 IRE clips below-black, while 7.5 IRE gives codes 14/19/24/29
for -2%/black/+2%/+4%. See `manual-pattern-basis.md` for the digital model and
its analog measurement boundary.

Before compilation, the complete `make test` suite, both Verilator lint passes,
top-level syntax check, `make verify-frames`, diff whitespace check, and
unchanged-`sys/` guard passed. All 36 canonical images were decoded and reviewed;
full-image pedestal arithmetic matched all 16 non-PLUGE patterns. The 12 old
patterns unaffected by the ramp/PLUGE/SMPTE changes retained their original
0 IRE hashes. The golden manifest now covers all 18 patterns in both modes.
Frame generation supports parallel make jobs and writes each completed frame
through a temporary file before renaming it.

Quartus Prime Lite 17.0.2 Build 602, using the existing staged-source Podman
wrapper, completed in 9 minutes 33 seconds with zero errors and 31 warnings:

- transport pixel clock: 27.000 MHz (37.037 ns), logical sample enable 13.5 MHz;
- worst setup slack: +0.451 ns overall, +6.345 ns video clock domain;
- worst hold slack: +0.253 ns;
- ALMs: 8,811 / 41,910 (21%);
- registers: 11,735;
- block memory: 384,447 / 5,662,720 bits (7%);
- DSP: 58 / 112 (52%);
- RBF size: 2,508,568 bytes; and
- RBF SHA-256:
  `6038c8b1d1fe8c48a0ca96478a4cfcdb47c52b4e0ef99a0fad8410fbb972116d`.

The 76 staged compiler input files were recorded and checked in
`build/quartus/source-inputs.sha256`. That manifest's SHA-256 is
`dda3b921f5780a6e0faabf45bfe010d61bf428369c6564da9045cdf61540f764`.

The user authorized interaction with the wiped MiSTer at `root@192.168.88.18`.
The release was uploaded under a temporary name, checksum-verified, renamed to:

```text
/media/fat/_Utility/VTG9000_20261005_r4.rbf
```

After `sync`, its remote checksum matched again. It was loaded through
`/dev/MiSTer_cmd`; `/tmp/CORENAME` reported `VTG9000`. The live configuration
had `vga_mode=subcarrier`, `composite_sync=1`, `vga_scaler=0`, `direct_video=0`,
and `forced_scandoubler=0`. MiSTer.ini was not modified.

This records digital simulation/image checks, FPGA timing closure, transfer,
and core loading. Display stability and analog IRE/DAC accuracy for this exact
RBF still need observed/measured evidence from the intended output path.


## Native resolutions release R5

Recorded 2026-10-05 America/New_York (build/load completed 2026-10-06 UTC).
This release adds native 480p59.94, 916x720p60, 1360x1080p60, and 916x720p120,
matching the Asteroids reference's HD raster dimensions and compatibility
cadence. It retains the existing NTSC 480i and 240p timings. See
[video-modes.md](video-modes.md) for the complete timing table and status mapping.

The video PLL is independently reconfigured between 27 MHz and 128.52 MHz;
HPS and controls stay at 27 MHz. The direct native stream has 32 aligned
transport clocks of latency: five geometry stages, three color stages, and
24 delivery registers. Constant grid/edge comparisons, parallel grayscale
band encoding, and explicit geometry arithmetic avoid long divider/multiplier
paths. There is no core framebuffer, scaling, filtering, gamma, or color-space
conversion. All sys/ files remain byte-identical to the pre-change pinned
framework inventory.

The release uses the existing framework's `MISTER_DOWNSCALE_NN` build option:
HDMI downscaling uses nearest-neighbor interpolation. HDMI upscaling remains
configurable, and the native VGA path is unaffected. This removes the
framework bilinear downscale path that failed timing at the faster input
clock. Physical combinational resynthesis is disabled; register duplication
and retiming remain enabled. Independent PLL domains use asynchronous clock
groups, and explicit mode/settings synchronizers constrain their subsequent
stages normally. No intra-video multicycle exception relaxes the 128.52 MHz
requirement. Failed diagnostic candidates were retained locally and never
deployed.

Before this release was generated, simulation timing, native patterns,
29,027 aligned pipeline packets, lint/top syntax, and all 36 unchanged golden
image hashes passed. The complete seven-bench `make test` suite also passed
again on the final source. Grayscale checks now cover both rows at every
native column. The final images were independently rendered using Verilator.
An additional Verilator raster run passed after replacing variable-expression
force statements in a temporary testbench copy with explicit constant forces;
the repository's original Icarus bench passed unchanged. The legacy raster,
controls, and golden manifest match their pre-feature copies exactly.

Quartus Prime Lite **17.0.2 Build 602**, in the staged-source Podman wrapper,
completed the final build with zero errors and no timing critical warning.
The successful artifact and reports are in `build/quartus-r5-attempt10/`:

- video transport clock: 128.52 MHz (7.781 ns), analyzed at the fastest mode;
- worst setup slack: **+0.093 ns**, in the video domain;
- worst hold slack: +0.246 ns;
- worst recovery/removal slack: +4.231 / +0.989 ns;
- minimum pulse-width slack: +0.778 ns;
- ALMs: 9,397 / 41,910 (22%);
- registers: 14,206;
- block memory: 384,579 / 5,662,720 bits (7%);
- DSP blocks: 44 / 112 (39%);
- PLLs: 4 / 6;
- RBF size: **2,528,996 bytes**; and
- RBF SHA-256:
  `6f3b430de35c500edc88f422c1aeb5461a2073a9785fda4f8027cc3e87a410aa`.

`release-setup.rpt`, `release-hold.rpt`, `release-recovery.rpt`,
`release-removal.rpt`, `release-clocks.rpt`, and `release-unconstrained.rpt`
retain detailed post-fit evidence. There are zero illegal or unconstrained
clocks. The pinned framework still has four unconstrained input ports and
50 unconstrained output ports; this timing result covers the reported internal
paths and does not establish external DAC/adapter electrical timing accuracy.

The 80 compiler inputs in `source-inputs.sha256` were checked against the
current checkout. Quartus changed only the QSF `LAST_QUARTUS_VERSION` metadata
from Standard Edition to Lite Edition. `compiled-VTG9000.qsf` reconstructs the
exact compiler QSF and matches its manifest hash; `source-verification.txt`
records the check. The manifest SHA-256 is
`7a86b226212e87c494f27386078cd49251bf20c123bb70a9d30d9324498c42d7`.
The named local release is `build/releases/VTG9000_20261005_r5.rbf`.

Under the user's deployment authorization, the release was transferred to
`root@192.168.88.18` using a temporary filename, SHA-256 checked, renamed without
overwriting an existing revision, synced, and checked again at:

```text
/media/fat/_Utility/VTG9000_20261005_r5.rbf
```

It was loaded through `/dev/MiSTer_cmd`. `/tmp/CORENAME` reported `VTG9000` and
its modification time advanced to **2026-10-06 00:28:07 UTC**. The remote size
and SHA-256 matched the local artifact. R4 remains present with its original
checksum. MiSTer.ini remains unchanged with SHA-256
`60d0d6b5717e6d762ab9c22990172143e8849d79535b5069986fac71adee25b5`.
Its live output configuration remains `vga_mode=subcarrier`, `composite_sync=1`,
`vga_scaler=0`, `direct_video=0`, and `forced_scandoubler=0`.

Transfer and loading are confirmed. Display observation of this exact R5,
including 480i stability, 240p locking, HD mode switching and physical PLL
accuracy, remains pending the user's MiSTer test. Analog DAC/IRE accuracy and
equalizing/serration waveform compliance remain unmeasured.


## Repository publication and build-tool safeguards

After the R5 build, the newest RBF was selected for publication in
`releases/VTG9000_20261005_r5.rbf`, with `SHA256SUMS`, the original STA summary,
and a reconstructed pre-compile source manifest. Its binary hash is unchanged
from the file loaded on MiSTer. The source-manifest reconstruction reverses
only the verified QSF compiler-version metadata rewrite described above.

Generated build outputs and Python caches were removed from Git tracking;
local files and the MiSTer rollback revision were preserved. Local/private
paths are ignored. This cleanup does not remove older artifacts from Git
history or claim a new FPGA build.

The wrapper now refuses all existing output directories, records source hashes
before compilation separately from post-compile hashes, retains the compiled
QSF, and returns failure for negative or missing/malformed timing results.
Nine build-tool regression checks passed. The checker accepted R5's actual
summary and rejected the preceding candidate's -0.185 ns setup result.
These tooling changes do not alter the R5 HDL or its RBF; the FPGA was not
rebuilt for repository publication.
