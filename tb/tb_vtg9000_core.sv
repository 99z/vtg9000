`timescale 1ns/1ps

module tb_vtg9000_core;
	reg clk = 0;
	reg reset = 1;
	reg interlaced = 0;
	reg [3:0] pattern = 0;
	reg [6:0] level_percent = 50;
	reg invert = 0;
	reg raster_border = 0;
	reg [2:0] channel_enable = 3'b111;
	wire ce_pix;
	wire hblank;
	wire vblank;
	wire hsync;
	wire vsync;
	wire de;
	wire frame_start;
	wire field;
	wire [11:0] x;
	wire [11:0] y;
	wire [7:0] red;
	wire [7:0] green;
	wire [7:0] blue;

	always #5 clk = ~clk;

	vtg9000_core dut (
		.clk(clk),
		.reset(reset),
		.interlaced(interlaced),
		.pattern(pattern),
		.level_percent(level_percent),
		.invert(invert),
		.raster_border(raster_border),
		.channel_enable(channel_enable),
		.ce_pix(ce_pix),
		.hblank(hblank),
		.vblank(vblank),
		.hsync(hsync),
		.vsync(vsync),
		.de(de),
		.frame_start(frame_start),
		.field(field),
		.x(x),
		.y(y),
		.red(red),
		.green(green),
		.blue(blue)
	);

	task expect_rgb(input [7:0] er, input [7:0] eg, input [7:0] eb, input [255:0] label_text);
		begin
			#1;
			if ((red !== er) || (green !== eg) || (blue !== eb)) begin
				$fatal(1, "%0s: expected %02x%02x%02x, got %02x%02x%02x", label_text, er, eg, eb, red, green, blue);
			end
		end
	endtask

	task wait_for_ce;
		begin
			while (!ce_pix) begin
				@(posedge clk);
				#1;
			end
		end
	endtask

	integer n;
	integer expected_x;
	integer expected_y;
	integer expected_v;
	integer expected_field;
	integer low_hsync_count;
	integer low_vsync_pixels;
	integer active_pixels;
	integer field0_samples;
	integer field1_samples;
	integer expected_level;
	reg expected_active;
	reg expected_vsync;
	reg [11:0] forced_v_count;

	initial begin
		// 720x240p60.05: 858x262 at a 13.5 MHz logical sample rate.
		repeat (2) @(posedge clk);
		reset = 0;
		#1;
		wait_for_ce();
		if (!frame_start) $fatal(1, "240p did not begin at the frame origin");
		low_hsync_count = 0;
		low_vsync_pixels = 0;
		active_pixels = 0;
		for (n = 0; n < 858 * 262; n = n + 1) begin
			expected_x = n % 858;
			expected_v = n / 858;
			expected_active = (expected_v >= 18) && (expected_v < 258);
			expected_y = expected_active ? (expected_v - 18) * 2 : 0;
			if ((x !== expected_x[11:0]) || (y !== expected_y[11:0]))
				$fatal(1, "240p counter mismatch at sample %0d: got (%0d,%0d)", n, x, y);
			if (field) $fatal(1, "240p unexpectedly asserted field parity");
			if (de !== ((expected_x < 720) && expected_active))
				$fatal(1, "240p DE mismatch at raster (%0d,%0d)", x, expected_v);
			if (de) active_pixels = active_pixels + 1;
			if (!hsync) low_hsync_count = low_hsync_count + 1;
			if (!vsync) low_vsync_pixels = low_vsync_pixels + 1;

			@(posedge clk);
			#1;
			if (ce_pix) $fatal(1, "240p logical sample was not held for two clocks");
			@(posedge clk);
			#1;
			if (!ce_pix) $fatal(1, "240p CE_PIXEL did not repeat every other clock");
		end

		if (!frame_start || (x != 0) || (y != 0))
			$fatal(1, "240p frame did not wrap to origin");
		if (low_hsync_count != 62 * 262)
			$fatal(1, "240p HSync width mismatch: %0d samples", low_hsync_count);
		if (low_vsync_pixels != 3 * 858)
			$fatal(1, "240p VSync width mismatch: %0d samples", low_vsync_pixels);
		if (active_pixels != 720 * 240)
			$fatal(1, "240p active sample mismatch: %0d", active_pixels);

		// 720x480i59.94: exact 262.5-line fields in one 858x525 frame.
		reset = 1;
		interlaced = 1;
		repeat (2) @(posedge clk);
		reset = 0;
		#1;
		wait_for_ce();
		if (!frame_start) $fatal(1, "480i did not begin on field 0");
		low_hsync_count = 0;
		low_vsync_pixels = 0;
		active_pixels = 0;
		field0_samples = 0;
		field1_samples = 0;
		for (n = 0; n < 858 * 525; n = n + 1) begin
			expected_x = n % 858;
			expected_v = n / 858;
			expected_field = (expected_v > 262) ||
				((expected_v == 262) && (expected_x >= 429));
			expected_active =
				((expected_v >= 18) && (expected_v < 258)) ||
				((expected_v >= 281) && (expected_v < 521));
			if ((expected_v >= 18) && (expected_v < 258))
				expected_y = (expected_v - 18) * 2;
			else if ((expected_v >= 281) && (expected_v < 521))
				expected_y = ((expected_v - 281) * 2) + 1;
			else expected_y = 0;
			expected_vsync = (expected_v < 3) ||
				((expected_v == 262) && (expected_x >= 429)) ||
				((expected_v > 262) && (expected_v < 265)) ||
				((expected_v == 265) && (expected_x < 429));

			if ((x !== expected_x[11:0]) || (y !== expected_y[11:0]) ||
			    (field !== expected_field[0]))
				$fatal(1, "480i mismatch at sample %0d: got x=%0d y=%0d f=%0d", n, x, y, field);
			if (de !== ((expected_x < 720) && expected_active))
				$fatal(1, "480i DE mismatch at raster (%0d,%0d)", x, expected_v);
			if (vsync !== ~expected_vsync)
				$fatal(1, "480i VSync phase mismatch at raster (%0d,%0d)", x, expected_v);
			if (de) active_pixels = active_pixels + 1;
			if (!hsync) low_hsync_count = low_hsync_count + 1;
			if (!vsync) low_vsync_pixels = low_vsync_pixels + 1;
			if (field) field1_samples = field1_samples + 1;
			else field0_samples = field0_samples + 1;

			@(posedge clk);
			#1;
			if (ce_pix) $fatal(1, "480i logical sample was not repeated for two clocks");
			@(posedge clk);
			#1;
			if (!ce_pix) $fatal(1, "480i CE_PIXEL did not repeat every other clock");
		end

		if (!frame_start || (x != 0) || (y != 0) || field)
			$fatal(1, "480i complete frame did not wrap to field 0");
		if (low_hsync_count != 62 * 525)
			$fatal(1, "480i HSync width mismatch: %0d samples", low_hsync_count);
		if (low_vsync_pixels != 3 * 858 * 2)
			$fatal(1, "480i VSync width mismatch: %0d samples", low_vsync_pixels);
		if (active_pixels != 720 * 480)
			$fatal(1, "480i active sample mismatch: %0d", active_pixels);
		if ((field0_samples != 858 * 262 + 429) ||
		    (field1_samples != 858 * 262 + 429))
			$fatal(1, "480i fields were not exactly 262.5 lines: %0d/%0d", field0_samples, field1_samples);

		// Pattern checks use the 240p raster's canonical even-row addressing.
		reset = 1;
		interlaced = 0;
		repeat (2) @(posedge clk);
		reset = 0;
		#1;
		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd18;
		force dut.raster.v_count = forced_v_count;
		pattern = 0;
		expect_rgb(8'hff, 8'hff, 8'hff, "first color bar");

		force dut.raster.h_count = 12'd100;
		expect_rgb(8'hff, 8'hff, 8'h00, "second color bar");

		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd168; // canonical pattern row 300
		expect_rgb(8'h00, 8'h00, 8'h00, "split bars reversed lower-left");

		force dut.raster.h_count = 12'd100;
		expect_rgb(8'h00, 8'h00, 8'hff, "split bars lower blue");

		pattern = 13;
		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd18; // canonical pattern row 0
		expect_rgb(8'd191, 8'd191, 8'd191, "SMPTE 75-percent gray");

		force dut.raster.h_count = 12'd150;
		expect_rgb(8'd191, 8'd191, 8'd0, "SMPTE yellow");

		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd183; // canonical pattern row 330
		expect_rgb(8'd0, 8'd0, 8'd191, "SMPTE complementary blue");

		force dut.raster.h_count = 12'd540;
		forced_v_count = 12'd218; // canonical pattern row 400
		expect_rgb(8'd12, 8'd12, 8'd12, "SMPTE below-black patch");

		force dut.raster.h_count = 12'd640;
		expect_rgb(8'd25, 8'd25, 8'd25, "SMPTE above-black patch");

		force dut.raster.h_count = 12'd650;
		forced_v_count = 12'd18; // canonical pattern row 0
		invert = 1;
		expect_rgb(8'd0, 8'd0, 8'd191, "SMPTE blue-only mode");
		force dut.raster.h_count = 12'd150;
		expect_rgb(8'd0, 8'd0, 8'd0, "SMPTE blue-only suppresses yellow");
		invert = 0;

		pattern = 14;
		force dut.raster.h_count = 12'd100;
		forced_v_count = 12'd218; // canonical pattern row 400
		expect_rgb(8'hff, 8'hff, 8'h00, "EBU full-height yellow");

		pattern = 8;
		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd18; // canonical pattern row 0
		expect_rgb(8'd16, 8'd16, 8'd16, "PLUGE nominal black background");

		force dut.raster.h_count = 12'd80;
		forced_v_count = 12'd68; // canonical pattern row 100
		expect_rgb(8'd12, 8'd12, 8'd12, "PLUGE left minus-two bar");
		force dut.raster.h_count = 12'd130;
		expect_rgb(8'd25, 8'd25, 8'd25, "PLUGE left plus-four bar");
		force dut.raster.h_count = 12'd190;
		expect_rgb(8'd20, 8'd20, 8'd20, "PLUGE left plus-two bar");

		force dut.raster.h_count = 12'd340;
		forced_v_count = 12'd63; // canonical pattern row 90
		expect_rgb(8'd235, 8'd235, 8'd235, "PLUGE 100-percent center box");
		forced_v_count = 12'd78; // canonical pattern row 120
		expect_rgb(8'd224, 8'd224, 8'd224, "PLUGE 95-percent inset");
		forced_v_count = 12'd118; // canonical pattern row 200
		expect_rgb(8'd180, 8'd180, 8'd180, "PLUGE 75-percent center box");
		forced_v_count = 12'd158; // canonical pattern row 280
		expect_rgb(8'd126, 8'd126, 8'd126, "PLUGE 50-percent center box");
		forced_v_count = 12'd198; // canonical pattern row 360
		expect_rgb(8'd71, 8'd71, 8'd71, "PLUGE 25-percent center box");

		pattern = 2;
		force dut.raster.h_count = 12'd90;
		forced_v_count = 12'd23; // canonical pattern row 10
		expect_rgb(8'hff, 8'hff, 8'hff, "coarse crosshatch grid line");
		force dut.raster.h_count = 12'd91;
		expect_rgb(8'h00, 8'h00, 8'h00, "coarse crosshatch cell interior");

		pattern = 3;
		force dut.raster.h_count = 12'd0;
		forced_v_count = 12'd68; // canonical pattern row 100
		expect_rgb(8'hff, 8'hff, 8'hff, "split grayscale upper white");
		force dut.raster.h_count = 12'd719;
		expect_rgb(8'h00, 8'h00, 8'h00, "split grayscale upper black");
		forced_v_count = 12'd168; // canonical pattern row 300
		expect_rgb(8'hff, 8'hff, 8'hff, "split grayscale lower reversed white");

		pattern = 7;
		force dut.raster.h_count = 12'd585;
		forced_v_count = 12'd138; // canonical pattern row 240
		expect_rgb(8'hff, 8'hff, 8'hff, "circles center ring");
		force dut.raster.h_count = 12'd81;
		forced_v_count = 12'd38; // canonical pattern row 40
		expect_rgb(8'hff, 8'hff, 8'hff, "circles corner ring");

		pattern = 10;
		force dut.raster.h_count = 12'd10;
		forced_v_count = 12'd23; // canonical pattern row 10
		expect_rgb(8'hff, 8'hff, 8'hff, "checker upper-left white");
		force dut.raster.h_count = 12'd220;
		expect_rgb(8'h00, 8'h00, 8'h00, "checker second tile black");
		forced_v_count = 12'd83; // canonical pattern row 130
		expect_rgb(8'hff, 8'hff, 8'hff, "checker diagonal white");

		pattern = 11;
		force dut.raster.h_count = 12'd36;
		forced_v_count = 12'd68; // canonical pattern row 100
		expect_rgb(8'hff, 8'hff, 8'hff, "safe-area five-percent edge");
		force dut.raster.h_count = 12'd360;
		expect_rgb(8'hff, 8'hff, 8'hff, "safe-area center crosshair");

		pattern = 12;
		force dut.raster.h_count = 12'd100;
		forced_v_count = 12'd68; // canonical pattern row 100
		expect_rgb(8'd128, 8'd128, 8'd128, "focus gray surround");
		force dut.raster.h_count = 12'd18;
		forced_v_count = 12'd26; // canonical pattern row 16
		expect_rgb(8'hff, 8'hff, 8'hff, "focus patch white line");
		forced_v_count = 12'd27; // canonical pattern row 18
		expect_rgb(8'h00, 8'h00, 8'h00, "focus patch black line");

		pattern = 1;
		force dut.raster.h_count = 12'd100;
		forced_v_count = 12'd68; // canonical pattern row 100
		for (n = 0; n <= 100; n = n + 1) begin
			level_percent = n[6:0];
			expected_level = (n * 255 + 50) / 100;
			#1;
			if ((red !== expected_level[7:0]) ||
			    (green !== expected_level[7:0]) ||
			    (blue !== expected_level[7:0]))
				$fatal(1, "level mapping mismatch at %0d percent", n);
		end

		level_percent = 100;
		channel_enable = 3'b100;
		expect_rgb(8'hff, 8'h00, 8'h00, "red-only channel mask");

		channel_enable = 3'b111;
		invert = 1;
		expect_rgb(8'h00, 8'h00, 8'h00, "flat-field inversion");

		release dut.raster.h_count;
		release dut.raster.v_count;
		$display("PASS: 720x240p/480i timing, exact field phase, and pattern checks");
		$finish;
	end
endmodule
