# VTG9000 R5

[Download VTG9000_20261005_r5.rbf](https://github.com/99z/vtg9000/raw/refs/heads/main/releases/VTG9000_20261005_r5.rbf)

R5 is the newest published build. It supports 480i, 240p, 480p, 916x720p60/120,
and 1360x1080p60, with 18 patterns and selectable digital black pedestal.
Copy it to `/media/fat/_Utility/` and select it from MiSTer's menu.

- Build: Quartus Prime Lite 17.0.2 Build 602, 2026-10-05 local date.
- Size: 2,528,996 bytes.
- SHA-256: `6f3b430de35c500edc88f422c1aeb5461a2073a9785fda4f8027cc3e87a410aa`.
- Worst reported setup/hold slack: +0.093 / +0.246 ns.
- Seven HDL simulation benches and 36 golden-frame checks passed.
- HDMI downscaling uses nearest-neighbor; the native VGA path remains direct.
- Transfer and loading on MiSTer were confirmed. Display/analog validation is pending.

Verify the downloaded binary from this directory:

```sh
sha256sum -c SHA256SUMS
```

The accompanying `.sta.summary` is the original compiler timing summary.
The `-source-inputs.sha256` file reconstructs the pre-compile source snapshot
from the original compiler manifest, reversing only Quartus's
`LAST_QUARTUS_VERSION` metadata rewrite in the QSF. Tcl is recorded at its
staged root path; its repository location is `tools/quartus_timing_reports.tcl`.
Detailed timing, source verification, and deployment evidence are in
[the build record](../docs/build-and-deployment.md).

This directory publishes only the latest RBF. Earlier build artifacts are
excluded from the current repository tree; recorded history remains in the docs.
