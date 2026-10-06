# Development notes

Start with [AGENTS.md](../AGENTS.md) and [HANDOFF.md](../HANDOFF.md). The latter
records the implementation and exact release state; it is not a substitute
for inspecting the current checkout.

## Source map

| Location | Purpose |
| --- | --- |
| `VTG9000.sv` | MiSTer top level, OSD/status mapping, clocks and controls |
| `rtl/vtg9000_core.sv` | Native raster/pattern composition and aligned pixel pipeline |
| `rtl/vtg_raster.sv` | 480i half-line fields and 240p timing |
| `rtl/vtg_progressive.sv` | Native progressive timing |
| `rtl/vtg_video_clock.sv` | Video PLL reconfiguration |
| `rtl/vtg_geometry_pipe.sv` | Explicit geometry arithmetic stages |
| `rtl/vtg_patterns.sv`, `rtl/vtg_monoscope.sv` | Procedural patterns and digital levels |
| `rtl/vtg_controls.sv` | Keyboard/controller state and OSD synchronization |
| `files.qip` | Manually maintained HDL source list |
| `tb/`, `Makefile` | Simulation, lint, canonical renders and golden hashes |
| `tools/` | Build, evidence and documentation utilities |
| `sys/` | Unmodified pinned MiSTer framework |

The framework is pinned to
`MiSTer-devel/Template_MiSTer@3ea1134cf05d62c2b1db30362277a823d739ced2`.
Core-specific changes belong outside `sys/`. The native path evaluates patterns
at the selected raster coordinates; the MiSTer framework owns HDMI scaling and
output conversion. See [video-modes.md](video-modes.md) for the timing table,
clock/reset design, status mapping and pipeline alignment.

## Verification

Install `build-essential`, `iverilog`, and `verilator`, then run:

```sh
make test
make lint
make lint-top
make -j8 verify-frames
make check-build-tools
git diff --check -- . ':(exclude)build/**'
git diff --exit-code -- sys
```

Seven benches cover native timing, pattern codes/geometry, controls, switching,
PLL transactions, and RGB/timing pipeline alignment. The raster bench checks
two complete 480i frames with exact half-line field phases. The canonical
renderer produces 36 images: 18 patterns in both pedestal modes. These test
digital behavior; analog accuracy and display stability require separate
observation or measurement of a named output path.

Generated PPMs are under `build/frames/`. Build outputs and Python caches are
ignored and were removed from Git tracking while preserving local files.
The `releases/` directory publishes the newest RBF, checksum and build evidence.
Preserve local artifacts; `make clean` removes the local build directory,
including locally retained Quartus outputs and release copies.

## Quartus and release records

Use Quartus 17.0.2. The container wrapper needs Podman and downloads its compiler
image on first use. Give each invocation a new output directory:

```sh
QUARTUS_OUTPUT_DIR="$PWD/build/quartus-local" ./tools/quartus_container_build.sh
```

The wrapper refuses to replace any existing output directory, including its
default `build/quartus/`. It stages compiler inputs only and runs compilation
without container networking. `source-inputs.sha256` captures inputs before
Quartus rewrites metadata; `compiler-inputs.sha256` and
`compiled-VTG9000.qsf` retain the post-compile state. Python 3 is required for
the timing gate. The wrapper returns failure if any reported setup, hold,
recovery, removal or pulse-width slack is negative, or required summary data
is missing/malformed. Diagnostics are retained on failures. Inspect the detailed
clock/unconstrained reports too; external I/O accuracy remains separate.

`make check-build-tools` exercises these guards using temporary fixtures and a
mock Podman command. It does not invoke Quartus or generate an FPGA bitstream.

With an installed Quartus 17.0.2 toolchain, the equivalent compile is
`quartus_sh --flow compile VTG9000`, followed by
`quartus_sta -t tools/quartus_timing_reports.tcl`. Outputs go to `output_files/`.

Record build and deployment evidence in
[build-and-deployment.md](build-and-deployment.md). Use unique release names
and preserve earlier binaries; a deployment record must distinguish checksum
verification/core loading from observed hardware behavior.

## README artwork

`docs/images/banner.svg` is editable vector artwork. The two pattern previews
are exported from golden-verified canonical simulator frames, not photographed
or captured MiSTer output. To regenerate them after an intentional, verified
pattern change:

```sh
make -j8 verify-frames
python3 -m pip install Pillow
python3 tools/readme_assets.py
```

The exporter checks the selected PPM hashes before conversion. It presents the
720x480 SD sample grid at 4:3 display aspect using nearest-neighbor row expansion;
use the original PPMs for pixel analysis. Inspect the PNG and SVG after changes.

For manual-derived pattern behavior and digital-versus-analog limits, read
[manual-pattern-basis.md](manual-pattern-basis.md). Firmware findings belong in
[firmware-evidence.md](firmware-evidence.md); prospective work belongs in
[roadmap.md](roadmap.md).
