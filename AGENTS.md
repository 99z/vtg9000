# Project working rules

- Keep `sys/` byte-identical to the pinned upstream Template_MiSTer commit.
- Put core-specific HDL in `rtl/` and list it manually in `files.qip`.
- Preserve a native one-clock-per-pixel path without framebuffer, gamma,
  scaling, filtering, or color-space conversion in core logic.
- Treat digital raster/code correctness separately from analog DAC accuracy.
- Do not label an output path reference-grade without a named DAC profile and
  measured evidence.
- Require simulation timing checks before generating or deploying an RBF.
- Do not claim hardware validation until the exact RBF has run on a MiSTer and
  the observed display/output has been recorded.
- Use Quartus 17.0.2 for release builds, matching the MiSTer framework.
