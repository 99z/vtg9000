# MiSTer hardware baseline

Recorded before the first VTG400 RBF deployment.

Current connection (user update, 2026-10-05): the MiSTer is on the network;
use `ssh root@192.168.88.18`. The connection details below are historical.

- Connection: dedicated Ethernet cable to the Ubuntu host
- Host-side connection: NetworkManager shared mode, `10.42.0.1/24`
- MiSTer DHCP address during inventory: `10.42.0.157` (not assumed stable)
- Kernel: `Linux 5.15.1-MiSTer`, build dated 2026-07-16, ARMv7
- MiSTer binary size: 1,059,560 bytes
- MiSTer binary MD5: `9d5f18d3a087985597c89177386bb586`
- FAT storage: 59 GiB total, 5.5 GiB used, 54 GiB available
- Intended test-core directory: `/media/fat/_Utility`

Relevant settings observed in `/media/fat/MiSTer.ini`:

```ini
composite_sync=1
vga_scaler=0
hdmi_limited=0
direct_video=0
video_mode=0
vsync_adjust=0
```

`direct_video=0` is correct for the initial ordinary-HDMI display test. It must
only be enabled after powering down and attaching a compatible HDMI-to-analog
Direct Video adapter. The global `composite_sync=1` setting primarily affects
the analog path. The original core also exposed an RGBHV/RGBS selector; that
selector was removed on 2026-10-05, leaving sync formatting to MiSTer.ini.

The connected SuperStation One also has an internal analog DAC. With the
observed `vga_scaler=0`, that path receives the core's native timing even while
`direct_video=0`; Direct Video is only needed for the separate HDMI-to-analog
DAC path. Accordingly, the core's scan mode is not conditional on the
`direct_video` flag.

No core files or MiSTer configuration had been changed when this baseline was
recorded. Subsequent authorized changes are recorded in
`build-and-deployment.md`.
