# Native video modes and timing verification

The reference is [Videodr0me/Arcade-Asteroids_MiSTer](https://github.com/Videodr0me/Arcade-Asteroids_MiSTer/tree/0f1369fa18cd3522ff60b0471358134e4fb0bdfc),
commit `0f1369fa18cd3522ff60b0471358134e4fb0bdfc`, inspected on 2026-10-05.
Its `rtl/asteroids_video.sv` function `decode_video_mode` uses **inclusive
terminal counters**. VTG9000 uses counts, so the HD totals below add one to
the reference terminal values. The reference's 720p and 1080p active widths
are 916 and 1360, respectively; these are the actual core rasters, distinct
from the MiSTer scaler's output resolution. Both HD modes use negative sync.

VTG9000 matches those native HD dimensions and compatible 60/120 Hz timing
geometry. It retains its existing NTSC SD timing instead of adopting the
reference's game-cadence SD raster (884 samples, 264/529 lines in compatibility
mode). The reference's optional 61.52 Hz game cadence is not a new resolution.

| Menu mode | Active samples | Total samples | Transport MHz | CE divisor | Pixel MHz | Horizontal kHz | Refresh |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 15 kHz / 480i (default) | 720x480 | 858x525/frame | 27 | 2 | 13.5 | 15.734266 | 59.940060 fields/s, 29.970030 frames/s |
| 15 kHz / 240p | 720x240 | 858x262 | 27 | 2 | 13.5 | 15.734266 | 60.054449 frames/s |
| 480p | 720x480 | 858x525 | 27 | 1 | 27 | 31.468531 | 59.940060 frames/s |
| 720p | 916x720 | 1428x750 | 128.52 | 2 | 64.26 | 45 | 60 frames/s |
| 1080p | 1360x1080 | 1904x1125 | 128.52 | 1 | 128.52 | 67.5 | 60 frames/s |
| 720p 120 Hz | 916x720 | 1428x750 | 128.52 | 1 | 128.52 | 90 | 120 frames/s |

These clock frequencies are requested PLL values. Behavioral simulation tests
routing and uniform CE spacing; it does not establish synthesized PLL error,
post-fit timing closure, or measured physical clock accuracy. A new RBF requires
Quartus 17.0.2 compilation and timing review after simulation checks pass.

## Status and clock switching

`status[27:25]` selects 0=15 kHz, 1=480p, 2=720p, 3=1080p, 4=720p 120 Hz.
Values 5-7 fall back to 15 kHz. `status[18]` retains the existing 15 kHz format
selection, 0=480i and 1=240p, and is ignored by progressive selections. Thus
existing settings with zero high bits retain their scan mode. Direct-control
writeback preserves these bits and every unrelated status bit.

HPS, keyboard, controller repeat, and activity logic stay on the original
27 MHz PLL. A separate video PLL supplies a **direct PLL output** to the MiSTer
framework; a cascaded clock mux is rejected by Quartus for the framework's
HDMI/VGA clock-select inputs. The video PLL reconfigures between 27 MHz and
128.52 MHz through the pinned framework's unmodified `pll_cfg_hdmi` IP.

The controller writes M, its 32-bit fractional numerator K, C0, then START,
respecting Avalon waitrequest. It holds video reset until the transaction has
settled, the IP is ready, and PLL lock is synchronized. SD uses
50*(13+0.5)/25 = 27 MHz; HD uses
50*(12+3659312136/2^32)/5 ≈ 128.52 MHz. The two VCO frequencies are 675 and
642.6 MHz, respectively. Register encoding follows [Intel/Altera AN 661](https://docs.altera.com/r/docs/683640/current/an-661-implementing-fractional-pll-reconfiguration-with-altera-pll-and-altera-pll-reconfig-ip-cores/fractional-pll-dynamic-reconfiguration-registers-and-settings).
The PLL initializes at the fastest frequency for conservative timing analysis.

A mode change blanks RGB/DE for at least 127 system clocks and holds reset
through PLL reconfiguration, followed by four video clocks. The mode crosses
through two registers while reset is held; pattern settings also cross through
two registers. Only the first CDC stages have false timing paths. `new_vmode`
toggles for changes to the effective native mode. Changes to an inactive
15 kHz format do not restart HD. A new request during a PLL transaction is
applied after the current transaction completes, without exposing its
intermediate clock to active video. Simulation includes backpressure, complete
register transactions, and rapid requests. Physical PLL lock/accuracy still
requires the user's hardware test.

## Direct native patterns

Patterns are evaluated from native raster coordinates, with geometry boundaries
computed for 720x480, 916x720, or 1360x1080. The generator shares its arithmetic between sizes. The release path uses
32 transport clocks of aligned streaming latency: five explicit geometry
stages, three color stages (algorithm, inversion, pedestal/channel masks), and
24 delivery registers. RGB, CE, coordinates, sync, blanking and field parity
remain aligned; startup packets are suppressed until the pipeline is filled.
This retains one native logical sample per CE without a framebuffer. Coarse
and fine grids use constant native-coordinate boundaries, and HD ramps use
exact fixed-point slopes instead of variable dividers. The combinational
variant remains available to the canonical renderer and reference benches. There is no stored image, framebuffer, scaler, filter, gamma,
colour conversion, or progressive-to-interlaced converter. Alternating pixels,
focus gratings, and multiburst periods remain expressed in **native samples**.
Circles use size-dependent ellipse coefficients for a displayed 4:3 image;
HD ramps span black to white across the full native width. The existing SD
artwork and its canonical renderer remain covered by the unchanged 36 golden
hashes. 240p continues to address even rows of the SD procedural geometry.

Native 480p requires a compatible 31 kHz display; native HD modes require a
compatible display/adapter. MiSTer's configured scaler can provide ordinary
HDMI output separately. `VGA_SCALER` stays zero, and core selection does not
change MiSTer.ini. The existing 4:3 aspect request is retained at every size.
The release enables the pinned framework's `MISTER_DOWNSCALE_NN` option:
HDMI downscaling uses nearest-neighbor instead of bilinear interpolation to
meet the faster input-clock requirement. HDMI upscaling filters remain
configurable. This option does not affect the native VGA path.

## 480i digital timing

The existing `rtl/vtg_raster.sv` is unchanged. Its raster is continuous over
858x525 samples, with no horizontal reset at the second field boundary:

- field 0 occupies samples [0, 225225); field 1 occupies [225225, 450450);
- the second field starts at raster line 262, sample 429;
- both fields last exactly 262.5 lines (225225 logical samples);
- negative HSync covers [736, 798) each line: 62 samples, about 4.593 us;
- each negative VSync interval lasts 2574 samples (3H, about 190.667 us);
- VSync starts at 0 and 225225 samples, so its second edge is shifted by H/2;
- each field has 240 complete active lines of 720 samples;
- first-field active lines are [18, 258), second-field lines [281, 521);
- active row addresses are even 0..478 followed by odd 1..479; and
- `VGA_F1` changes at the exact half-line field boundary, during blanking.

`tb/tb_vtg9000_core.sv` checks every logical sample across two complete 480i
frames, including DE, row address, parity, VSync phase, HSync duration, field
sample counts, frame wrap, and transport CE division. The progressive mode
bench checks two consecutive frames for all four new selections, including
sync windows, totals, active sample counts, blanking, and CE pause behavior.
The top-level bench checks all selections, clock routing, CE division, video
blanking during switching, mode notification, and status preservation.

These are separate native H/V timing checks. The pinned MiSTer framework owns
composite-sync generation and any YC conversion. Equalizing/serration waveform
compliance, physical CRT stability, output-voltage accuracy, and DAC profiles
have not been established by these simulations. R5 was subsequently built
with Quartus 17.0.2, closed timing, checksum-verified and loaded on the MiSTer.
The exact artifact and deployment evidence are in docs/build-and-deployment.md.
Display observation of that R5 remains pending the user's hardware test.

## Source verification record — 2026-10-05

- `make test`: all seven benches passed, including two consecutive frames of each
  progressive selection and two complete 480i frames with exact HSync porch
  positions, half-line VSync/parity, blanking, and field sample counts.
- `make lint` and `make lint-top`: passed without warnings.
- Streaming verification compared 29,027 aligned color/timing packets to the
  combinational reference, including every native mode, all 18 patterns,
  controls in flight, both interlace phases, and sampled chart geometry.
- `make -j8 verify-frames`: all 36 canonical images matched the existing hashes.
  An independent Verilator render of the final source also matched all 36.
- `git diff --check -- . ':(exclude)build/**'`: passed.
- Every sys/ file matched the pre-change SHA-256 inventory; git reports no sys/
  changes. The legacy raster, direct-control RTL, and golden hash file also
  matched their pre-change copies exactly.

The checkout's existing edits were retained. Generated simulation binaries and
frames may appear in Git status because this repository tracks build outputs.
Quartus compilation, HD timing closure, deployment, and display/DAC evidence
for a new RBF are recorded separately in docs/build-and-deployment.md.
