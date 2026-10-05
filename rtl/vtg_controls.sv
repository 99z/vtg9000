// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

module vtg_controls #(
	parameter integer REPEAT_DELAY_CYCLES = 12_600_000,
	parameter integer REPEAT_RATE_CYCLES  = 2_520_000
)(
	input  wire         clk,
	input  wire         reset,
	input  wire [3:0]   status_pattern,
	input  wire [6:0]   status_level,
	input  wire         status_invert,
	input  wire         status_border,
	input  wire [10:0]  ps2_key,
	input  wire [7:0]   joystick_0,
	input  wire [7:0]   joystick_1,
	output reg  [3:0]   pattern,
	output reg  [6:0]   level,
	output reg          invert,
	output reg          border,
	output reg          status_update
);

localparam [1:0] DIR_NONE = 2'd0;
localparam [1:0] DIR_NEG  = 2'd1;
localparam [1:0] DIR_POS  = 2'd2;

reg [3:0] seen_pattern;
reg [6:0] seen_level;
reg       seen_invert;
reg       seen_border;

reg ps2_toggle_d;
reg key_left;
reg key_right;
reg key_down;
reg key_up;

reg [7:4] joystick_buttons_d;
reg [1:0] horizontal_d;
reg [1:0] vertical_d;
integer horizontal_repeat;
integer vertical_repeat;

wire [7:0] joystick = joystick_0 | joystick_1;
wire keyboard_event = ps2_key[10] != ps2_toggle_d;
wire keyboard_press = ps2_key[9];
wire [7:0] keyboard_code = ps2_key[7:0];

wire left_held  = key_left  | joystick[1];
wire right_held = key_right | joystick[0];
wire down_held  = key_down  | joystick[2];
wire up_held    = key_up    | joystick[3];

wire [1:0] horizontal = (left_held == right_held) ? DIR_NONE :
	left_held ? DIR_NEG : DIR_POS;
wire [1:0] vertical = (down_held == up_held) ? DIR_NONE :
	down_held ? DIR_NEG : DIR_POS;

function automatic [6:0] add_ten(input [6:0] value);
	begin
		add_ten = (value >= 7'd90) ? 7'd100 : value + 7'd10;
	end
endfunction

function automatic [6:0] subtract_ten(input [6:0] value);
	begin
		subtract_ten = (value <= 7'd10) ? 7'd0 : value - 7'd10;
	end
endfunction

always @(posedge clk) begin
	ps2_toggle_d <= ps2_key[10];
	joystick_buttons_d <= joystick[7:4];
	status_update <= 1'b0;

	if (reset) begin
		pattern <= status_pattern;
		level <= status_level;
		invert <= status_invert;
		border <= status_border;
		seen_pattern <= status_pattern;
		seen_level <= status_level;
		seen_invert <= status_invert;
		seen_border <= status_border;
		ps2_toggle_d <= ps2_key[10];
		key_left <= 1'b0;
		key_right <= 1'b0;
		key_down <= 1'b0;
		key_up <= 1'b0;
		joystick_buttons_d <= joystick[7:4];
		horizontal_d <= DIR_NONE;
		vertical_d <= DIR_NONE;
		horizontal_repeat <= 0;
		vertical_repeat <= 0;
	end else begin
		// Follow changes made in the OSD. Key/controller changes are sent back
		// through status_set, so the OSD and direct controls converge on one state.
		if (status_pattern != seen_pattern) begin
			pattern <= status_pattern;
			seen_pattern <= status_pattern;
		end
		if (status_level != seen_level) begin
			level <= status_level;
			seen_level <= status_level;
		end
		if (status_invert != seen_invert) begin
			invert <= status_invert;
			seen_invert <= status_invert;
		end
		if (status_border != seen_border) begin
			border <= status_border;
			seen_border <= status_border;
		end

		// PS/2 Set 2: arrows (and keypad directions) become held controls.
		if (keyboard_event) begin
			case (keyboard_code)
				8'h6b: key_left  <= keyboard_press;
				8'h74: key_right <= keyboard_press;
				8'h72: key_down  <= keyboard_press;
				8'h75: key_up    <= keyboard_press;
				default: begin end
			endcase

			if (keyboard_press) begin
				case (keyboard_code)
					8'h7d: begin level <= add_ten(level);      status_update <= 1'b1; end // Page Up
					8'h7a: begin level <= subtract_ten(level); status_update <= 1'b1; end // Page Down
					8'h6c: begin level <= 7'd0;                status_update <= 1'b1; end // Home
					8'h69: begin level <= 7'd100;              status_update <= 1'b1; end // End
					8'h43: if (!ps2_key[8]) begin invert <= ~invert; status_update <= 1'b1; end // I
					8'h2d: if (!ps2_key[8]) begin border <= ~border; status_update <= 1'b1; end // R
					default: begin end
				endcase
			end
		end

		// D-pad/arrow horizontal navigation wraps through all 15 patterns.
		if (horizontal == DIR_NONE) begin
			horizontal_d <= DIR_NONE;
			horizontal_repeat <= 0;
		end else if (horizontal != horizontal_d) begin
			horizontal_d <= horizontal;
			horizontal_repeat <= REPEAT_DELAY_CYCLES;
			if (horizontal == DIR_NEG)
				pattern <= (pattern == 4'd0) ? 4'd14 : pattern - 1'd1;
			else
				pattern <= (pattern == 4'd14) ? 4'd0 : pattern + 1'd1;
			status_update <= 1'b1;
		end else if (horizontal_repeat == 0) begin
			horizontal_repeat <= REPEAT_RATE_CYCLES;
			if (horizontal == DIR_NEG)
				pattern <= (pattern == 4'd0) ? 4'd14 : pattern - 1'd1;
			else
				pattern <= (pattern == 4'd14) ? 4'd0 : pattern + 1'd1;
			status_update <= 1'b1;
		end else begin
			horizontal_repeat <= horizontal_repeat - 1;
		end

		// Up raises level and down lowers it, with clamping at 0% and 100%.
		if (vertical == DIR_NONE) begin
			vertical_d <= DIR_NONE;
			vertical_repeat <= 0;
		end else if (vertical != vertical_d) begin
			vertical_d <= vertical;
			vertical_repeat <= REPEAT_DELAY_CYCLES;
			if ((vertical == DIR_POS) && (level < 7'd100)) level <= level + 1'd1;
			if ((vertical == DIR_NEG) && (level > 7'd0))   level <= level - 1'd1;
			status_update <= 1'b1;
		end else if (vertical_repeat == 0) begin
			vertical_repeat <= REPEAT_RATE_CYCLES;
			if ((vertical == DIR_POS) && (level < 7'd100)) level <= level + 1'd1;
			if ((vertical == DIR_NEG) && (level > 7'd0))   level <= level - 1'd1;
			status_update <= 1'b1;
		end else begin
			vertical_repeat <= vertical_repeat - 1;
		end

		// Four named controller actions can be remapped in MiSTer's input menu.
		if (joystick[4] && !joystick_buttons_d[4]) begin invert <= ~invert; status_update <= 1'b1; end
		if (joystick[5] && !joystick_buttons_d[5]) begin border <= ~border; status_update <= 1'b1; end
		if (joystick[6] && !joystick_buttons_d[6]) begin level <= add_ten(level); status_update <= 1'b1; end
		if (joystick[7] && !joystick_buttons_d[7]) begin level <= subtract_ten(level); status_update <= 1'b1; end
	end
end

endmodule
