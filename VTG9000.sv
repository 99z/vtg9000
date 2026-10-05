// SPDX-License-Identifier: GPL-2.0-or-later
//
// VTG9000_MiSTer top-level glue. The native core path is deliberately direct:
// no framebuffer, gamma stage, scaler, or progressive/interlaced conversion.
`timescale 1ns/1ps

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE,
	SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS,
	SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE,
	DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL         = 0;
assign VGA_SCALER     = 0;
assign VGA_DISABLE    = 0;
assign HDMI_FREEZE    = 0;
assign HDMI_BLACKOUT  = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S   = 0;
assign AUDIO_L   = 0;
assign AUDIO_R   = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

assign VIDEO_ARX = 12'd4;
assign VIDEO_ARY = 12'd3;

`include "build_id.v"
localparam CONF_STR = {
	"VTG9000;;",
	"-;",
	"O[4:1],Pattern,8-Color Split,Flat Field,Coarse Crosshatch,32-Level Split Gray,Ramp,Alt Pixels,Variable Window,Circles,PLUGE,Graphics Multiburst,4x4 Checkerboard,Safe Area 5/10%,Focus,SMPTE Bars,EBU Bars;",
	"O[11:5],Level,0%,1%,2%,3%,4%,5%,6%,7%,8%,9%,10%,11%,12%,13%,14%,15%,16%,17%,18%,19%,20%,21%,22%,23%,24%,25%,26%,27%,28%,29%,30%,31%,32%,33%,34%,35%,36%,37%,38%,39%,40%,41%,42%,43%,44%,45%,46%,47%,48%,49%,50%,51%,52%,53%,54%,55%,56%,57%,58%,59%,60%,61%,62%,63%,64%,65%,66%,67%,68%,69%,70%,71%,72%,73%,74%,75%,76%,77%,78%,79%,80%,81%,82%,83%,84%,85%,86%,87%,88%,89%,90%,91%,92%,93%,94%,95%,96%,97%,98%,99%,100%;",
	"O[12],Invert / SMPTE Blue,Off,On;",
	"O[13],Raster Border,Off,On;",
	"O[14],Red Channel,On,Off;",
	"O[15],Green Channel,On,Off;",
	"O[16],Blue Channel,On,Off;",
	"O[17],Sync Output,RGBHV,RGBS;",
	"O[18],Scan Mode,480i (15 kHz),240p (15 kHz);",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Invert / SMPTE Blue,Raster Border,Level +10%,Level -10%;",
	"jn,A,B,X,Y;",
	"v,2;",
	"V,v", `BUILD_DATE
};

wire [127:0] status;
wire [1:0] buttons;
wire clk_pix;
wire [31:0] joystick_0;
wire [31:0] joystick_1;
wire [10:0] ps2_key;
wire [3:0] selected_pattern;
wire [6:0] selected_level;
wire selected_invert;
wire selected_border;
wire control_status_update;
reg scan_mode_d = 0;
reg new_vmode = 0;
wire [127:0] status_in = {
	status[127:14], selected_border, selected_invert,
	selected_level, selected_pattern, status[0]
};

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_pix),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),
	.forced_scandoubler(),
	.direct_video(),
	.new_vmode(new_vmode),
	.buttons(buttons),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.ps2_key(ps2_key),
	.status(status),
	.status_in(status_in),
	.status_set(control_status_update),
	.status_menumask(16'd0)
);

wire pll_locked;
pll pll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(clk_pix),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1] | ~pll_locked;
wire interlaced = ~status[18];
always @(posedge clk_pix) begin
	if (reset) begin
		scan_mode_d <= status[18];
		new_vmode <= 0;
	end else begin
		scan_mode_d <= status[18];
		if (scan_mode_d != status[18]) new_vmode <= ~new_vmode;
	end
end
wire video_reset = reset | (scan_mode_d != status[18]);
wire [7:0] red;
wire [7:0] green;
wire [7:0] blue;
wire hblank;
wire vblank;
wire hsync;
wire vsync;
wire de;
wire ce_pix;
wire field;

vtg_controls controls
(
	.clk(clk_pix),
	.reset(reset),
	.status_pattern(status[4:1]),
	.status_level(status[11:5]),
	.status_invert(status[12]),
	.status_border(status[13]),
	.ps2_key(ps2_key),
	.joystick_0(joystick_0[7:0]),
	.joystick_1(joystick_1[7:0]),
	.pattern(selected_pattern),
	.level(selected_level),
	.invert(selected_invert),
	.border(selected_border),
	.status_update(control_status_update)
);

vtg9000_core core
(
	.clk(clk_pix),
	.reset(video_reset),
	.interlaced(interlaced),
	.pattern(selected_pattern),
	.level_percent(selected_level),
	.invert(selected_invert),
	.raster_border(selected_border),
	.channel_enable({~status[14], ~status[15], ~status[16]}),
	.ce_pix(ce_pix),
	.hblank(hblank),
	.vblank(vblank),
	.hsync(hsync),
	.vsync(vsync),
	.de(de),
	.frame_start(),
	.field(field),
	.x(),
	.y(),
	.red(red),
	.green(green),
	.blue(blue)
);

wire csync = ~(hsync ^ vsync);

assign CLK_VIDEO = clk_pix;
assign CE_PIXEL  = ce_pix;
assign VGA_F1    = field;
assign VGA_DE    = de;
assign VGA_HS    = status[17] ? csync : hsync;
assign VGA_VS    = status[17] ? 1'b1 : vsync;
assign VGA_R     = red;
assign VGA_G     = green;
assign VGA_B     = blue;

reg [24:0] activity_counter;
always @(posedge clk_pix) begin
	if (reset) activity_counter <= 0;
	else activity_counter <= activity_counter + 1'd1;
end
assign LED_USER = activity_counter[24];

endmodule
