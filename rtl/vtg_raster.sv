// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

// Native 720-sample, 15 kHz raster timing at a 13.5 MHz logical sample rate.
//
// 480i is represented as one continuous 858x525 frame. Field 1 starts at
// (line 0, sample 0); field 2 starts exactly 262.5 lines later at
// (line 262, sample 429). Horizontal sync therefore remains continuous while
// the second vertical-sync interval and VGA_F1 transition are displaced by
// half a line. Each field contains 240 complete active lines.
//
// The non-interlaced alternative is genuine 858x262 240p. Its 240 raster
// lines address the even rows of the canonical 720x480 pattern grid so the
// same pattern geometry is retained without a framebuffer.
module vtg_raster #(
	parameter [11:0] H_ACTIVE = 12'd720,
	parameter [11:0] H_FRONT  = 12'd16,
	parameter [11:0] H_SYNC   = 12'd62,
	parameter [11:0] H_BACK   = 12'd60,
	parameter [11:0] I_TOTAL  = 12'd525,
	parameter [11:0] I_FIELD2_LINE = 12'd262,
	parameter [11:0] I_FIELD1_ACTIVE_START = 12'd18,
	parameter [11:0] I_FIELD2_ACTIVE_START = 12'd281,
	parameter [11:0] P_TOTAL  = 12'd262,
	parameter [11:0] P_ACTIVE_START = 12'd18,
	parameter [11:0] ACTIVE_LINES = 12'd240,
	parameter [11:0] VSYNC_LINES = 12'd3,
	parameter bit HSYNC_POSITIVE = 1'b0,
	parameter bit VSYNC_POSITIVE = 1'b0
)(
	input  wire        clk,
	input  wire        reset,
	input  wire        ce,
	input  wire        interlaced,
	output wire [11:0] x,
	output wire [11:0] y,
	output wire        field,
	output wire        hblank,
	output wire        vblank,
	output wire        de,
	output wire        hsync,
	output wire        vsync,
	output wire        frame_start
);

localparam [11:0] H_TOTAL = H_ACTIVE + H_FRONT + H_SYNC + H_BACK;
localparam [11:0] H_SYNC_START = H_ACTIVE + H_FRONT;
localparam [11:0] H_SYNC_END   = H_SYNC_START + H_SYNC;
localparam [11:0] HALF_LINE = H_TOTAL >> 1;
localparam [11:0] I_FIELD1_ACTIVE_END = I_FIELD1_ACTIVE_START + ACTIVE_LINES;
localparam [11:0] I_FIELD2_ACTIVE_END = I_FIELD2_ACTIVE_START + ACTIVE_LINES;
localparam [11:0] P_ACTIVE_END = P_ACTIVE_START + ACTIVE_LINES;

reg [11:0] h_count = 0;
reg [11:0] v_count = 0;

wire [11:0] active_v_total = interlaced ? I_TOTAL : P_TOTAL;

always @(posedge clk) begin
	if (reset) begin
		h_count <= 0;
		v_count <= 0;
	end else if (ce) begin
		if (h_count == H_TOTAL - 12'd1) begin
			h_count <= 0;
			if (v_count == active_v_total - 12'd1) v_count <= 0;
			else v_count <= v_count + 1'd1;
		end else begin
			h_count <= h_count + 1'd1;
		end
	end
end

wire hsync_window = (h_count >= H_SYNC_START) && (h_count < H_SYNC_END);

// The second field occupies [262.5H, 525H). Keeping the transition in the
// vertical blanking interval gives the scaler the same field phase as the CRT.
wire interlaced_field2 =
	(v_count > I_FIELD2_LINE) ||
	((v_count == I_FIELD2_LINE) && (h_count >= HALF_LINE));

wire interlaced_active1 =
	(v_count >= I_FIELD1_ACTIVE_START) &&
	(v_count < I_FIELD1_ACTIVE_END);
wire interlaced_active2 =
	(v_count >= I_FIELD2_ACTIVE_START) &&
	(v_count < I_FIELD2_ACTIVE_END);
wire progressive_active =
	(v_count >= P_ACTIVE_START) && (v_count < P_ACTIVE_END);
wire active_v = interlaced
	? (interlaced_active1 || interlaced_active2)
	: progressive_active;

// Field 1 VSync is 3H at the frame origin. Field 2 is the same duration but
// begins at the half-line field boundary.
wire interlaced_vsync1 = v_count < VSYNC_LINES;
wire interlaced_vsync2 =
	((v_count == I_FIELD2_LINE) && (h_count >= HALF_LINE)) ||
	((v_count > I_FIELD2_LINE) &&
	 (v_count < I_FIELD2_LINE + VSYNC_LINES)) ||
	((v_count == I_FIELD2_LINE + VSYNC_LINES) && (h_count < HALF_LINE));
wire progressive_vsync = v_count < VSYNC_LINES;
wire vsync_window = interlaced
	? (interlaced_vsync1 || interlaced_vsync2)
	: progressive_vsync;

wire [11:0] field1_line = v_count - I_FIELD1_ACTIVE_START;
wire [11:0] field2_line = v_count - I_FIELD2_ACTIVE_START;
wire [11:0] progressive_line = v_count - P_ACTIVE_START;

assign x = h_count;
assign y = interlaced
	? (interlaced_active1 ? (field1_line << 1) :
	   interlaced_active2 ? ((field2_line << 1) | 12'd1) : 12'd0)
	: (progressive_active ? (progressive_line << 1) : 12'd0);
assign field = interlaced && interlaced_field2;
assign hblank = h_count >= H_ACTIVE;
assign vblank = ~active_v;
assign de = ~(hblank | vblank);
assign hsync = HSYNC_POSITIVE ? hsync_window : ~hsync_window;
assign vsync = VSYNC_POSITIVE ? vsync_window : ~vsync_window;
assign frame_start = ce && (h_count == 0) && (v_count == 0);

endmodule
