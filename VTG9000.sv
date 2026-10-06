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
	"O[23:19],Pattern,8-Color Split,Flat Field,Coarse Crosshatch,32-Level Split Gray,Ramp,Alt Pixels,Variable Window,Circles,PLUGE,Graphics Multiburst,4x4 Checkerboard,Safe Area 5/10%,Focus,SMPTE Bars,EBU Bars,Medium Crosshatch,Fine Crosshatch,Monoscope;",
	"O[11:5],Level,0%,1%,2%,3%,4%,5%,6%,7%,8%,9%,10%,11%,12%,13%,14%,15%,16%,17%,18%,19%,20%,21%,22%,23%,24%,25%,26%,27%,28%,29%,30%,31%,32%,33%,34%,35%,36%,37%,38%,39%,40%,41%,42%,43%,44%,45%,46%,47%,48%,49%,50%,51%,52%,53%,54%,55%,56%,57%,58%,59%,60%,61%,62%,63%,64%,65%,66%,67%,68%,69%,70%,71%,72%,73%,74%,75%,76%,77%,78%,79%,80%,81%,82%,83%,84%,85%,86%,87%,88%,89%,90%,91%,92%,93%,94%,95%,96%,97%,98%,99%,100%;",
	"O[12],Invert / SMPTE Blue,Off,On;",
	"O[13],Raster Border,Off,On;",
	"O[14],Red Channel,On,Off;",
	"O[15],Green Channel,On,Off;",
	"O[16],Blue Channel,On,Off;",
	"O[24],Black Level,0 IRE,7.5 IRE;",
	"O[27:25],Resolution,15 kHz,480p,720p,1080p,720p 120 Hz;",
	"O[18],15 kHz Format,480i,240p;",
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
wire [4:0] selected_pattern;
wire [6:0] selected_level;
wire selected_invert;
wire selected_border;
wire control_status_update;
// Keep HPS and direct-control timing on the fixed 27 MHz clock.
wire clk_video;
wire hd_locked;
wire [2:0] requested_mode = (status[27:25] == 1) ? 3'd2 :
    (status[27:25] == 2) ? 3'd3 : (status[27:25] == 3) ? 3'd4 :
    (status[27:25] == 4) ? 3'd5 : {2'b00, status[18]};
reg [2:0] mode_sd = 0;
reg [6:0] restart_count = 127;
reg new_vmode = 0;
wire [127:0] status_in = {
	status[127:24], selected_pattern, status[18:14],
	selected_border, selected_invert, selected_level, status[4:0]
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
always @(posedge clk_pix) begin
    if (reset) begin
        mode_sd <= requested_mode;
        restart_count <= 127;
        new_vmode <= 0;
    end else if (mode_sd != requested_mode) begin
        mode_sd <= requested_mode;
        restart_count <= 127;
        new_vmode <= ~new_vmode;
    end else if (restart_count != 0) restart_count <= restart_count - 1'b1;
end
vtg_video_clock video_clock (.refclk(CLK_50M), .clk_sd(clk_pix), .reset(reset),
    .select_hd(mode_sd >= 3), .clk_video(clk_video), .locked(hd_locked));
// Asynchronously blank during source switching; release after four video edges.
wire restart_video = reset | (restart_count != 0) | ~hd_locked;
reg [3:0] video_reset_pipe = 4'b1111;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mode_meta = 0, mode_video = 0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [17:0] settings_meta = 0, settings_video = 0;
wire [17:0] settings_sd = {selected_pattern, selected_level, status[24],
    selected_invert, selected_border, status[16:14]};
always @(posedge clk_video or posedge restart_video) begin
    if (restart_video) video_reset_pipe <= 4'b1111;
    else video_reset_pipe <= {video_reset_pipe[2:0], 1'b0};
end
always @(posedge clk_video) begin
    mode_meta <= mode_sd;
    mode_video <= mode_meta;
    settings_meta <= settings_sd;
    settings_video <= settings_meta;
end
wire video_reset = video_reset_pipe[3];
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
	.status_pattern(status[23:19]),
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

vtg9000_core #(.PIPELINE_STAGES(32)) core
(
	.clk(clk_video),
	.reset(video_reset),
	.video_mode(mode_video),
	.pattern(settings_video[17:13]),
	.level_percent(settings_video[12:6]),
	.setup_75(settings_video[5]),
	.invert(settings_video[4]),
	.raster_border(settings_video[3]),
	.channel_enable({~settings_video[0], ~settings_video[1], ~settings_video[2]}),
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

assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = ce_pix;
assign VGA_F1    = field;
assign VGA_DE    = de & ~video_reset;
// Supply separate syncs; the MiSTer framework applies MiSTer.ini output settings.
assign VGA_HS    = hsync;
assign VGA_VS    = vsync;
assign VGA_R     = video_reset ? 8'd0 : red;
assign VGA_G     = video_reset ? 8'd0 : green;
assign VGA_B     = video_reset ? 8'd0 : blue;

reg [24:0] activity_counter;
always @(posedge clk_pix) begin
	if (reset) activity_counter <= 0;
	else activity_counter <= activity_counter + 1'd1;
end
assign LED_USER = activity_counter[24];

endmodule
