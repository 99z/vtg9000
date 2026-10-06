# Future work

These are prospective tasks, not implemented features or validation claims.
The current implementation and exact release state are in [HANDOFF.md](../HANDOFF.md)
and [build-and-deployment.md](build-and-deployment.md).

1. Record display observations of the exact R5 on the intended MiSTer output:
   default 480i stability, 240p locking, and the new progressive modes. Preserve
   the RBF hash, adapter/display details and video or a detailed description.
2. Compare color bars, PLUGE and remaining geometry with the VTG 400 manual and,
   where available, lossless captures of real hardware. Keep intentional pixel
   changes explicit and review their golden images.
3. Expand the 18 implemented patterns toward the manual's full catalog. Expose
   rate-specific variants deliberately rather than inventing a generic rate
   selector. Extracted firmware labels are evidence, not implemented behavior.
4. Characterize named DAC/output profiles with measurements into a proper
   75-ohm load before making analog voltage, bandwidth, jitter or accuracy
   claims. Digital simulation cannot establish those properties.

If 480i still moves vertically, investigate the complete sync/output path,
including equalizing/serration behavior, without silently changing global
MiSTer.ini settings. A firmware-running emulator would be a separate project,
not a shortcut to running the original FPGA bitstream on MiSTer.
