// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

module vtg_patterns
(
	input  wire [11:0] x,
	input  wire [11:0] y,
	input  wire        active,
	input  wire [3:0]  pattern,
	input  wire [6:0]  level_percent,
	input  wire        invert,
	input  wire        raster_border,
	input  wire [2:0]  channel_enable,
	output reg  [7:0]  red,
	output reg  [7:0]  green,
	output reg  [7:0]  blue
);

localparam [3:0] PAT_SPLIT_BARS = 4'd0;
localparam [3:0] PAT_FLAT_FIELD = 4'd1;
localparam [3:0] PAT_CROSSHATCH = 4'd2;
localparam [3:0] PAT_GRAYSCALE  = 4'd3;
localparam [3:0] PAT_RAMP       = 4'd4;
localparam [3:0] PAT_ALT_PIXELS = 4'd5;
localparam [3:0] PAT_WINDOW     = 4'd6;
localparam [3:0] PAT_CIRCLES    = 4'd7;
localparam [3:0] PAT_PLUGE      = 4'd8;
localparam [3:0] PAT_MULTIBURST = 4'd9;
localparam [3:0] PAT_CHECKER    = 4'd10;
localparam [3:0] PAT_SAFE_AREA  = 4'd11;
localparam [3:0] PAT_FOCUS_DOTS = 4'd12;
localparam [3:0] PAT_SMPTE_BARS = 4'd13;
localparam [3:0] PAT_EBU_BARS   = 4'd14;

// Studio-range codes let PLUGE express values on both sides of a nominal
// digital black pedestal. This models the manual's relative levels; it does
// not claim that an attached analog DAC can produce the VTG's negative IRE.
localparam [7:0] PLUGE_MINUS_2 = 8'd12;
localparam [7:0] PLUGE_BLACK   = 8'd16;
localparam [7:0] PLUGE_PLUS_2  = 8'd20;
localparam [7:0] PLUGE_PLUS_4  = 8'd25;
localparam [7:0] PLUGE_25      = 8'd71;
localparam [7:0] PLUGE_50      = 8'd126;
localparam [7:0] PLUGE_75      = 8'd180;
localparam [7:0] PLUGE_95      = 8'd224;
localparam [7:0] PLUGE_100     = 8'd235;

reg [7:0] r;
reg [7:0] g;
reg [7:0] b;
reg [7:0] level_code;
integer dx;
integer dy;
integer distance_scaled;
reg [2:0] band;
reg [4:0] band_x;
integer gray_step;
reg checker_x_odd;
reg checker_y_odd;

always @* begin
	case (level_percent)
		7'd0: level_code = 8'd0;
		7'd1: level_code = 8'd3;
		7'd2: level_code = 8'd5;
		7'd3: level_code = 8'd8;
		7'd4: level_code = 8'd10;
		7'd5: level_code = 8'd13;
		7'd6: level_code = 8'd15;
		7'd7: level_code = 8'd18;
		7'd8: level_code = 8'd20;
		7'd9: level_code = 8'd23;
		7'd10: level_code = 8'd26;
		7'd11: level_code = 8'd28;
		7'd12: level_code = 8'd31;
		7'd13: level_code = 8'd33;
		7'd14: level_code = 8'd36;
		7'd15: level_code = 8'd38;
		7'd16: level_code = 8'd41;
		7'd17: level_code = 8'd43;
		7'd18: level_code = 8'd46;
		7'd19: level_code = 8'd48;
		7'd20: level_code = 8'd51;
		7'd21: level_code = 8'd54;
		7'd22: level_code = 8'd56;
		7'd23: level_code = 8'd59;
		7'd24: level_code = 8'd61;
		7'd25: level_code = 8'd64;
		7'd26: level_code = 8'd66;
		7'd27: level_code = 8'd69;
		7'd28: level_code = 8'd71;
		7'd29: level_code = 8'd74;
		7'd30: level_code = 8'd77;
		7'd31: level_code = 8'd79;
		7'd32: level_code = 8'd82;
		7'd33: level_code = 8'd84;
		7'd34: level_code = 8'd87;
		7'd35: level_code = 8'd89;
		7'd36: level_code = 8'd92;
		7'd37: level_code = 8'd94;
		7'd38: level_code = 8'd97;
		7'd39: level_code = 8'd99;
		7'd40: level_code = 8'd102;
		7'd41: level_code = 8'd105;
		7'd42: level_code = 8'd107;
		7'd43: level_code = 8'd110;
		7'd44: level_code = 8'd112;
		7'd45: level_code = 8'd115;
		7'd46: level_code = 8'd117;
		7'd47: level_code = 8'd120;
		7'd48: level_code = 8'd122;
		7'd49: level_code = 8'd125;
		7'd50: level_code = 8'd128;
		7'd51: level_code = 8'd130;
		7'd52: level_code = 8'd133;
		7'd53: level_code = 8'd135;
		7'd54: level_code = 8'd138;
		7'd55: level_code = 8'd140;
		7'd56: level_code = 8'd143;
		7'd57: level_code = 8'd145;
		7'd58: level_code = 8'd148;
		7'd59: level_code = 8'd150;
		7'd60: level_code = 8'd153;
		7'd61: level_code = 8'd156;
		7'd62: level_code = 8'd158;
		7'd63: level_code = 8'd161;
		7'd64: level_code = 8'd163;
		7'd65: level_code = 8'd166;
		7'd66: level_code = 8'd168;
		7'd67: level_code = 8'd171;
		7'd68: level_code = 8'd173;
		7'd69: level_code = 8'd176;
		7'd70: level_code = 8'd179;
		7'd71: level_code = 8'd181;
		7'd72: level_code = 8'd184;
		7'd73: level_code = 8'd186;
		7'd74: level_code = 8'd189;
		7'd75: level_code = 8'd191;
		7'd76: level_code = 8'd194;
		7'd77: level_code = 8'd196;
		7'd78: level_code = 8'd199;
		7'd79: level_code = 8'd201;
		7'd80: level_code = 8'd204;
		7'd81: level_code = 8'd207;
		7'd82: level_code = 8'd209;
		7'd83: level_code = 8'd212;
		7'd84: level_code = 8'd214;
		7'd85: level_code = 8'd217;
		7'd86: level_code = 8'd219;
		7'd87: level_code = 8'd222;
		7'd88: level_code = 8'd224;
		7'd89: level_code = 8'd227;
		7'd90: level_code = 8'd230;
		7'd91: level_code = 8'd232;
		7'd92: level_code = 8'd235;
		7'd93: level_code = 8'd237;
		7'd94: level_code = 8'd240;
		7'd95: level_code = 8'd242;
		7'd96: level_code = 8'd245;
		7'd97: level_code = 8'd247;
		7'd98: level_code = 8'd250;
		7'd99: level_code = 8'd252;
		default: level_code = 8'd255;
	endcase
	r = 0;
	g = 0;
	b = 0;
	dx = 0;
	dy = 0;
	distance_scaled = 0;
	band = 0;
	band_x = 0;
	gray_step = 0;
	checker_x_odd = 0;
	checker_y_odd = 0;

	if (active) begin
		case (pattern)
			PAT_SPLIT_BARS: begin
				// Manual pattern 13 for graphics rates: the lower half reverses
				// the eight-color sequence used by the upper half.
				if (y < 240) begin
					if (x < 90)       begin r = 8'd255; g = 8'd255; b = 8'd255; end
					else if (x < 180) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
					else if (x < 270) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
					else if (x < 360) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
					else if (x < 450) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
					else if (x < 540) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
					else if (x < 630) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
					else              begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
				end else begin
					if (x < 90)       begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < 180) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
					else if (x < 270) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
					else if (x < 360) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
					else if (x < 450) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
					else if (x < 540) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
					else if (x < 630) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
					else              begin r = 8'd255; g = 8'd255; b = 8'd255; end
				end
			end

			PAT_FLAT_FIELD: begin
				r = level_code;
				g = level_code;
				b = level_code;
			end

			PAT_CROSSHATCH: begin
				// Coarse square-cell grid: eight columns by six rows.
				if (((x % 90) == 0) || ((y % 80) == 0) ||
				    (x == 719) || (y == 479)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_GRAYSCALE: begin
				// Thirty-two displayed patches: 16 steps per row, with the
				// direction reversed in the lower half as shown in the manual.
				gray_step = {20'd0, x} / 45;
				if (y < 240) r = 8'(255 - (gray_step * 17));
				else         r = 8'(gray_step * 17);
				g = r;
				b = r;
			end

			PAT_RAMP: begin
				r = 8'((x * 7'd91) >> 8);
				g = r;
				b = r;
			end

			PAT_ALT_PIXELS: begin
				if (~x[0]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
			end

			PAT_WINDOW: begin
				if ((x >= 180) && (x < 540) && (y >= 120) && (y < 360)) begin
					r = level_code; g = level_code; b = level_code;
				end
			end

			PAT_CIRCLES: begin
				dx = {20'd0, x};
				dy = {20'd0, y};
				dx = dx - 360;
				dy = dy - 240;
				distance_scaled = ((dx * dx) * 64) + ((dy * dy) * 81);
				if ((distance_scaled >= 3223800) && (distance_scaled <= 3256200)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end

				dx = {20'd0, x} - 45;
				dy = {20'd0, y} - 40;
				distance_scaled = ((dx * dx) * 64) + ((dy * dy) * 81);
				if ((distance_scaled >= 75330) && (distance_scaled <= 90882)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = {20'd0, x} - 674;
				distance_scaled = ((dx * dx) * 64) + ((dy * dy) * 81);
				if ((distance_scaled >= 75330) && (distance_scaled <= 90882)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = {20'd0, x} - 45;
				dy = {20'd0, y} - 439;
				distance_scaled = ((dx * dx) * 64) + ((dy * dy) * 81);
				if ((distance_scaled >= 75330) && (distance_scaled <= 90882)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = {20'd0, x} - 674;
				distance_scaled = ((dx * dx) * 64) + ((dy * dy) * 81);
				if ((distance_scaled >= 75330) && (distance_scaled <= 90882)) begin r = 8'hff; g = 8'hff; b = 8'hff; end

				if ((x == 359) || (x == 360) || (y == 239) || (y == 240)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_PLUGE: begin
				r = PLUGE_BLACK;
				g = PLUGE_BLACK;
				b = PLUGE_BLACK;

				// Three bars per side: left -2/+4/+2%, right +2/+4/-2%.
				if ((y >= 80) && (y < 400)) begin
					if (((x >= 72)  && (x < 108)) ||
					    ((x >= 612) && (x < 648))) begin r = PLUGE_MINUS_2; g = PLUGE_MINUS_2; b = PLUGE_MINUS_2; end
					if (((x >= 126) && (x < 162)) ||
					    ((x >= 558) && (x < 594))) begin r = PLUGE_PLUS_4;  g = PLUGE_PLUS_4;  b = PLUGE_PLUS_4;  end
					if (((x >= 180) && (x < 216)) ||
					    ((x >= 504) && (x < 540))) begin r = PLUGE_PLUS_2;  g = PLUGE_PLUS_2;  b = PLUGE_PLUS_2;  end

					// Center contrast stack, bottom to top: 25/50/75/100%,
					// with a 95% patch inset into the 100% region.
					if ((x >= 281) && (x < 439)) begin
						if (y < 160)      begin r = PLUGE_100; g = PLUGE_100; b = PLUGE_100; end
						else if (y < 240) begin r = PLUGE_75;  g = PLUGE_75;  b = PLUGE_75;  end
						else if (y < 320) begin r = PLUGE_50;  g = PLUGE_50;  b = PLUGE_50;  end
						else               begin r = PLUGE_25;  g = PLUGE_25;  b = PLUGE_25;  end
					end
					if ((x >= 315) && (x < 405) && (y >= 105) && (y < 135)) begin
						r = PLUGE_95; g = PLUGE_95; b = PLUGE_95;
					end
				end
			end

			PAT_MULTIBURST: begin
				if (x < 120) begin band = 0; band_x = x[4:0]; end
				else if (x < 240) begin band = 1; band_x = x[4:0] - 5'd24; end
				else if (x < 360) begin band = 2; band_x = x[4:0] - 5'd16; end
				else if (x < 480) begin band = 3; band_x = x[4:0] - 5'd8; end
				else if (x < 600) begin band = 4; band_x = x[4:0]; end
				else begin band = 5; band_x = x[4:0] - 5'd24; end
				case (band)
					0: if (~band_x[4]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
					1: if (~band_x[3]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
					2: if (~band_x[2]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
					3: if (~band_x[1]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
					4: if (~band_x[0]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
					5: if ( band_x[0]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				endcase
			end

			PAT_CHECKER: begin
				checker_x_odd = ((x >= 180) && (x < 360)) || (x >= 540);
				checker_y_odd = ((y >= 120) && (y < 240)) || (y >= 360);
				if (checker_x_odd == checker_y_odd) begin r = 8'hff; g = 8'hff; b = 8'hff; end
			end

			PAT_SAFE_AREA: begin
				if ((x == 36) || (x == 683) || (y == 24) || (y == 455) ||
				    (x == 72) || (x == 647) || (y == 48) || (y == 431) ||
				    (x == 359) || (x == 360) || (y == 239) || (y == 240)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_FOCUS_DOTS: begin
				r = 8'd128; g = 8'd128; b = 8'd128;
				if (((x >= 18)  && (x < 90)  && (y >= 16)  && (y < 64))  ||
				    ((x >= 630) && (x < 702) && (y >= 16)  && (y < 64))  ||
				    ((x >= 324) && (x < 396) && (y >= 216) && (y < 264)) ||
				    ((x >= 18)  && (x < 90)  && (y >= 416) && (y < 464)) ||
				    ((x >= 630) && (x < 702) && (y >= 416) && (y < 464))) begin
					// Alternating vertical-pixel and lower-frequency horizontal
					// regions should average to the 50% gray surround.
					if (x[4] ^ y[4]) begin
						if (~x[0]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
						else       begin r = 8'h00; g = 8'h00; b = 8'h00; end
					end else begin
						if (~y[1]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
						else       begin r = 8'h00; g = 8'h00; b = 8'h00; end
					end
				end
			end

			PAT_SMPTE_BARS: begin
				// 75% SMPTE bars with the complementary strip and a compact
				// PLUGE sequence in the lower-right section.
				if (y < 320) begin
					if (x < 102)      begin r = 8'd191; g = 8'd191; b = 8'd191; end
					else if (x < 206) begin r = 8'd191; g = 8'd191; b = 8'd0;   end
					else if (x < 308) begin r = 8'd0;   g = 8'd191; b = 8'd191; end
					else if (x < 412) begin r = 8'd0;   g = 8'd191; b = 8'd0;   end
					else if (x < 514) begin r = 8'd191; g = 8'd0;   b = 8'd191; end
					else if (x < 618) begin r = 8'd191; g = 8'd0;   b = 8'd0;   end
					else              begin r = 8'd0;   g = 8'd0;   b = 8'd191; end
				end else if (y < 360) begin
					if (x < 102)      begin r = 8'd0;   g = 8'd0;   b = 8'd191; end
					else if (x < 206) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < 308) begin r = 8'd191; g = 8'd0;   b = 8'd191; end
					else if (x < 412) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < 514) begin r = 8'd0;   g = 8'd191; b = 8'd191; end
					else if (x < 618) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else              begin r = 8'd191; g = 8'd191; b = 8'd191; end
				end else begin
					if (x < 128)      begin r = 8'd0;   g = 8'd30;  b = 8'd68;  end
					else if (x < 258) begin r = 8'd255; g = 8'd255; b = 8'd255; end
					else if (x < 386) begin r = 8'd67;  g = 8'd0;   b = 8'd93;  end
					else if (x < 514) begin r = PLUGE_BLACK;   g = PLUGE_BLACK;   b = PLUGE_BLACK;   end
					else if (x < 566) begin r = PLUGE_MINUS_2; g = PLUGE_MINUS_2; b = PLUGE_MINUS_2; end
					else if (x < 618) begin r = PLUGE_BLACK;   g = PLUGE_BLACK;   b = PLUGE_BLACK;   end
					else if (x < 669) begin r = PLUGE_PLUS_4;  g = PLUGE_PLUS_4;  b = PLUGE_PLUS_4;  end
					else              begin r = PLUGE_BLACK;   g = PLUGE_BLACK;   b = PLUGE_BLACK;   end
				end
			end

			PAT_EBU_BARS: begin
				if (x < 90)       begin r = 8'd255; g = 8'd255; b = 8'd255; end
				else if (x < 180) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
				else if (x < 270) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
				else if (x < 360) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
				else if (x < 450) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
				else if (x < 540) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
				else if (x < 630) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
				else              begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
			end

			default: begin
				r = 8'hff;
				g = 8'h00;
				b = 8'hff;
			end
		endcase

		if (raster_border && ((x < 2) || (x >= 718) || (y < 2) || (y >= 478))) begin
			r = 8'hff;
			g = 8'hff;
			b = 8'hff;
		end

		if (invert && (pattern == PAT_SMPTE_BARS)) begin
			// The VTG's special function for SMPTE bars is blue-only mode.
			r = 8'd0;
			g = 8'd0;
		end else if (invert) begin
			r = ~r;
			g = ~g;
			b = ~b;
		end
	end

	red   = channel_enable[2] ? r : 8'd0;
	green = channel_enable[1] ? g : 8'd0;
	blue  = channel_enable[0] ? b : 8'd0;
end

endmodule
