// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

module vtg9000_core
(
	input  wire        clk,
	input  wire        reset,
	input  wire        interlaced,
	input  wire [3:0]  pattern,
	input  wire [6:0]  level_percent,
	input  wire        invert,
	input  wire        raster_border,
	input  wire [2:0]  channel_enable,
	output wire        ce_pix,
	output wire        hblank,
	output wire        vblank,
	output wire        hsync,
	output wire        vsync,
	output wire        de,
	output wire        frame_start,
	output wire        field,
	output wire [11:0] x,
	output wire [11:0] y,
	output wire [7:0]  red,
	output wire [7:0]  green,
	output wire [7:0]  blue
);

// A 27 MHz transport clock is used in both modes. Every 13.5 MHz logical
// sample is held for two clocks, yielding a DAC-friendly 1440 transport
// samples per line for both 480i and 240p.
reg sample_phase = 0;
always @(posedge clk) begin
	if (reset) sample_phase <= 0;
	else sample_phase <= ~sample_phase;
end
assign ce_pix = sample_phase;

vtg_raster raster
(
	.clk(clk),
	.reset(reset),
	.ce(ce_pix),
	.interlaced(interlaced),
	.x(x),
	.y(y),
	.field(field),
	.hblank(hblank),
	.vblank(vblank),
	.de(de),
	.hsync(hsync),
	.vsync(vsync),
	.frame_start(frame_start)
);

vtg_patterns patterns
(
	.x(x),
	.y(y),
	.active(de),
	.pattern(pattern),
	.level_percent(level_percent),
	.invert(invert),
	.raster_border(raster_border),
	.channel_enable(channel_enable),
	.red(red),
	.green(green),
	.blue(blue)
);

endmodule
