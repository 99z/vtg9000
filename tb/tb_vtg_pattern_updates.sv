`timescale 1ns/1ps

module tb_vtg_pattern_updates;
	reg [11:0] x = 100, y = 100;
	reg active = 1, setup_75 = 0, invert = 0, raster_border = 0;
	reg [4:0] pattern = 1;
	reg [6:0] level_percent = 0;
	reg [2:0] channel_enable = 3'b111;
	wire [7:0] red, green, blue;
	integer mode, level, expected, ix, iy, p, k;
	reg vertical_line;
	vtg_patterns dut (.clk(1'b0), .geo_circle_white(1'b0), .geo_mono_inner(1'b0), .geo_mono_ring(1'b0),
        .geo_wedge_inside(1'b0), .geo_wedge_grating(1'b0), .native_size(2'd0), .*);

	task gray_at(input integer px, input integer py, input integer code);
		begin
			x = 12'(px); y = 12'(py); #1;
			if ((red !== 8'(code)) || (green !== 8'(code)) || (blue !== 8'(code)))
				$fatal(1, "pattern %0d setup %0d at (%0d,%0d): expected %0d, got %0d/%0d/%0d",
					pattern, setup_75, px, py, code, red, green, blue);
		end
	endtask

	initial begin
		for (mode = 0; mode < 2; mode = mode + 1) begin
			setup_75 = (mode != 0);
			// Independent arithmetic oracle for every menu level in both modes.
			pattern = 1;
			for (level = 0; level <= 100; level = level + 1) begin
				level_percent = 7'(level);
				expected = mode ? (76500 + 9435 * level + 2000) / 4000 : (255 * level + 50) / 100;
				gray_at(100, 100, expected);
			end
			level_percent = 0;
			gray_at(100, 100, mode ? 19 : 0);
			invert = 1;
			gray_at(100, 100, 255);
			level_percent = 100;
			gray_at(100, 100, mode ? 19 : 0);
			invert = 0;
			channel_enable = 3'b100; #1;
			if ((red !== 255) || (green !== 0) || (blue !== 0)) $fatal(1, "channel disable changed with setup");
			channel_enable = 3'b111;
			// Exercise every normalized code through the ramp, including inversion,
			// against the pedestal equation rather than a copy of the lookup table.
			pattern = 4;
			for (ix = 0; ix < 720; ix = ix + 1) begin
				expected = (ix * 91) >> 8;
				gray_at(ix, 100, mode ? (765 + 37 * expected + 20) / 40 : expected);
				invert = 1;
				expected = 255 - expected;
				gray_at(ix, 100, mode ? (765 + 37 * expected + 20) / 40 : expected);
				invert = 0;
			end

			pattern = 6; level_percent = 0;
			gray_at(200, 150, mode ? 19 : 0);
			gray_at(100, 150, mode ? 19 : 0);
			level_percent = 100;
			gray_at(200, 150, 255);
			gray_at(100, 150, mode ? 19 : 0);

			pattern = 8;
			gray_at(0, 0, mode ? 19 : 0);
			gray_at(80, 100, mode ? 14 : 0);
			gray_at(130, 100, mode ? 29 : 10);
			gray_at(190, 100, mode ? 24 : 5);
			gray_at(340, 90, 255);
			gray_at(340, 120, mode ? 243 : 242);
			gray_at(340, 200, mode ? 196 : 191);
			gray_at(340, 280, mode ? 137 : 128);
			gray_at(340, 360, mode ? 78 : 64);
			invert = 1;
			gray_at(80, 100, 255); // Inverted below-black must saturate, never wrap.
			gray_at(340, 90, mode ? 19 : 0);
			invert = 0;
			pattern = 13;
			gray_at(540, 400, mode ? 14 : 0);
			gray_at(580, 400, mode ? 19 : 0);
			gray_at(640, 400, mode ? 29 : 10);
			invert = 1; x = 650; y = 100; #1;
			if ((red !== (mode ? 19 : 0)) || (green !== (mode ? 19 : 0)) ||
			    (blue !== (mode ? 196 : 191))) $fatal(1, "SMPTE blue-only pedestal mismatch");
			invert = 0;

			// Every column and row of both new grids, including the fractional
			// 22.5-sample fine-cell spacing and the right/bottom image borders.
			for (p = 15; p <= 16; p = p + 1) begin
				pattern = 5'(p);
				for (ix = 0; ix < 720; ix = ix + 1) begin
					vertical_line = (ix == 719);
					for (k = 0; k < (p == 15 ? 16 : 32); k = k + 1)
						if (ix == (k * 720 + (p == 15 ? 15 : 31)) / (p == 15 ? 16 : 32)) vertical_line = 1;
					gray_at(ix, 11, vertical_line ? 255 : (mode ? 19 : 0));
				end
				for (iy = 0; iy < 480; iy = iy + 1)
					gray_at(11, iy, ((iy % (p == 15 ? 40 : 20)) == 0 || iy == 479) ? 255 : (mode ? 19 : 0));
				raster_border = 1;
				gray_at(1, 11, 255);
				raster_border = 0;
				invert = 1;
				gray_at(0, 11, mode ? 19 : 0);
				gray_at(11, 11, 255);
				invert = 0;
			end
			// Blanking remains code zero for every pattern, with either pedestal,
			// even if inversion and the border are enabled.
			active = 0; invert = 1; raster_border = 1;
			for (p = 0; p < 18; p = p + 1) begin
				pattern = 5'(p); gray_at(0, 0, 0);
			end
			active = 1; invert = 0; raster_border = 0;
		end
		setup_75 = 0; pattern = 17;
		gray_at(100, 100, 64);
		gray_at(200, 220, 32);
		gray_at(495, 400, 255); // Aspect-correct circle, mirrored points.
		gray_at(225, 80, 255);
		gray_at(360, 240, 255);
		gray_at(210, 160, 0); gray_at(270, 160, 51);
		gray_at(330, 160, 102); gray_at(390, 160, 153);
		gray_at(450, 160, 204); gray_at(510, 160, 255);
		gray_at(480, 300, 255); gray_at(481, 300, 0);
		gray_at(380, 104, 255); gray_at(385, 104, 0);
		gray_at(1, 300, 255);
		$display("PASS: both IRE modes, PLUGE, fine grids, monoscope, masks and blanking");
		$finish;
	end
endmodule
