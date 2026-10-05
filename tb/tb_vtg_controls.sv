`timescale 1ns/1ps

module tb_vtg_controls;
	reg clk = 0;
	reg reset = 1;
	reg [3:0] status_pattern = 4'd2;
	reg [6:0] status_level = 7'd50;
	reg status_invert = 0;
	reg status_border = 0;
	reg [10:0] ps2_key = 0;
	reg [7:0] joystick_0 = 0;
	reg [7:0] joystick_1 = 0;
	wire [3:0] pattern;
	wire [6:0] level;
	wire invert;
	wire border;
	wire status_update;

	always #5 clk = ~clk;

	vtg_controls #(
		.REPEAT_DELAY_CYCLES(3),
		.REPEAT_RATE_CYCLES(2)
	) dut (
		.clk(clk),
		.reset(reset),
		.status_pattern(status_pattern),
		.status_level(status_level),
		.status_invert(status_invert),
		.status_border(status_border),
		.ps2_key(ps2_key),
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.pattern(pattern),
		.level(level),
		.invert(invert),
		.border(border),
		.status_update(status_update)
	);

	task tick;
		begin
			@(posedge clk);
			#1;
		end
	endtask

	task key_event(input pressed, input extended_key, input [7:0] code);
		begin
			ps2_key = {~ps2_key[10], pressed, extended_key, code};
			tick();
		end
	endtask

	task expect_controls(
		input [3:0] expected_pattern,
		input [6:0] expected_level,
		input expected_invert,
		input expected_border,
		input [255:0] label_text
	);
		begin
			if ((pattern !== expected_pattern) || (level !== expected_level) ||
			    (invert !== expected_invert) || (border !== expected_border)) begin
				$fatal(1, "%0s: got pattern=%0d level=%0d invert=%0d border=%0d",
					label_text, pattern, level, invert, border);
			end
		end
	endtask

	initial begin
		repeat (2) tick();
		reset = 0;
		tick();
		expect_controls(4'd2, 7'd50, 0, 0, "initial OSD state");

		// Keyboard right changes on the initial press and wraps at the end.
		key_event(1, 1, 8'h74);
		tick();
		expect_controls(4'd3, 7'd50, 0, 0, "keyboard next pattern");
		if (!status_update) $fatal(1, "keyboard navigation did not request OSD sync");
		key_event(0, 1, 8'h74);
		tick();

		status_pattern = 4'd0;
		tick();
		joystick_0[1] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd50, 0, 0, "controller previous-pattern wrap");
		joystick_0[1] = 1'b0;
		tick();

		// Either controller may navigate. Up raises level and repeats while held.
		joystick_1[3] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd51, 0, 0, "controller level increment");
		repeat (3) tick();
		expect_controls(4'd14, 7'd51, 0, 0, "level repeat delay");
		tick();
		expect_controls(4'd14, 7'd52, 0, 0, "held level repeat");
		joystick_1[3] = 1'b0;
		tick();

		status_level = 7'd100;
		tick();
		joystick_0[3] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd100, 0, 0, "level upper clamp");
		joystick_0[3] = 1'b0;
		tick();
		joystick_0[2] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd99, 0, 0, "controller level decrement");
		joystick_0[2] = 1'b0;
		tick();

		// Keyboard coarse steps and endpoint shortcuts.
		status_level = 7'd95;
		tick();
		key_event(1, 1, 8'h7d);
		expect_controls(4'd14, 7'd100, 0, 0, "Page Up saturated coarse step");
		key_event(0, 1, 8'h7d);
		key_event(1, 1, 8'h6c);
		expect_controls(4'd14, 7'd0, 0, 0, "Home zero-percent shortcut");
		key_event(0, 1, 8'h6c);
		key_event(1, 1, 8'h69);
		expect_controls(4'd14, 7'd100, 0, 0, "End 100-percent shortcut");
		key_event(0, 1, 8'h69);
		key_event(1, 1, 8'h7a);
		expect_controls(4'd14, 7'd90, 0, 0, "Page Down coarse step");
		key_event(0, 1, 8'h7a);

		// I/R and the first two named controller buttons toggle useful modes.
		key_event(1, 0, 8'h43);
		expect_controls(4'd14, 7'd90, 1, 0, "keyboard invert toggle");
		key_event(0, 0, 8'h43);
		key_event(1, 0, 8'h2d);
		expect_controls(4'd14, 7'd90, 1, 1, "keyboard raster toggle");
		key_event(0, 0, 8'h2d);
		joystick_0[4] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd90, 0, 1, "controller invert toggle");
		joystick_0[4] = 1'b0;
		tick();
		joystick_0[5] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd90, 0, 0, "controller raster toggle");
		joystick_0[5] = 1'b0;
		tick();

		joystick_0[6] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd100, 0, 0, "controller coarse increase");
		joystick_0[6] = 1'b0;
		tick();
		joystick_0[7] = 1'b1;
		tick();
		expect_controls(4'd14, 7'd90, 0, 0, "controller coarse decrease");
		joystick_0[7] = 1'b0;
		tick();

		// A later OSD change remains authoritative.
		status_pattern = 4'd8;
		status_level = 7'd25;
		status_invert = 1'b1;
		status_border = 1'b1;
		tick();
		expect_controls(4'd8, 7'd25, 1, 1, "OSD resynchronization");

		$display("PASS: keyboard/controller navigation and OSD synchronization");
		$finish;
	end
endmodule
