# Firmware evidence carried into the MiSTer implementation

This project is a clean behavioral reimplementation. It does not execute or
redistribute the Extron firmware. The original image is used as compatibility
evidence and must be supplied separately by a user who is entitled to possess
it.

## Revalidated directly on this host

- The analyzed firmware is identified by the SHA-256 in
  `firmware-manifest.json`.
- Its printable data contains the complete 34-name pattern catalog, including
  Circles, Safe Area, PLUGE, grayscale, ramps, split color bars, variable
  windows, flat fields, checkerboard, alternating pixels, frequency sweep,
  multiburst, multipulse, transient response, CTF, and hum bar.
- It contains explicit 0% through 100% labels in one-percent steps.
- It contains RGBHV, RGBS, RGsB, and RsGsBs sync-format labels; individual
  red, green, and blue channel-enable controls; raster border; sequencing;
  scope-trigger placement; calibration controls; and hardware-test strings.
- A contiguous firmware table yields exactly 113 displayed rate records. The
  extraction is reproducible with `tools/extract_firmware_catalog.py`.
- The release notes were extracted and visually checked on all 11 pages. They
  establish firmware version 2.05, model-specific update warnings, timing and
  polarity corrections, 1.04-era additions, and the documented persistence of
  a few known pattern-specific issues.

## Historical findings not yet independently rederived here

The imported session reports that the controller is HCS08, that the package
also contains FPGA content, and that the update protocol is an unauthenticated
RS-232 upload using `ESC Upload CR`, `Go`, raw 512-byte writes, and `Upl`.
Those details are useful background but are not requirements for the clean
MiSTer pattern engine. They remain marked historical until revalidated from
the installer/device on this host.

## Important limitation of the catalog

The firmware catalog exposes active dimensions and displayed horizontal and
vertical rates. Those fields are not complete modelines: pixel clock, porch
widths, sync widths, interlace details, and polarity still require standards
reconstruction or hardware measurement. The historical first bring-up build
used 640x480p60 with an 800x525 negative-sync raster at 25.200 MHz. The current
core instead implements 720x480i and 720x240p 15 kHz timing independently of
that incomplete catalog evidence.
