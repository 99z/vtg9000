`timescale 1ns/1ps

// Render the canonical 720x480 pattern grid directly. Native scan modes read
// this grid as interlaced even/odd rows or as the even rows of a 240p raster;
// keeping this renderer independent of raster timing makes golden images a
// stable check of pattern logic rather than a capture of either scan mode.
module tb_frame;
	reg [4:0] pattern = 0;
	reg [6:0] level_percent = 100;
	reg [11:0] x = 0;
	reg [11:0] y = 0;
	wire [7:0] red;
	wire [7:0] green;
	wire [7:0] blue;
	integer output_file;
	integer pattern_arg;
	integer level_arg;
	integer setup_arg;
	reg setup_75 = 0;
	integer ix;
	integer iy;
	integer active_pixels;
	reg [1023:0] output_path;

	vtg_patterns dut (.clk(1'b0), .geo_circle_white(1'b0), .geo_mono_inner(1'b0), .geo_mono_ring(1'b0),
        .geo_wedge_inside(1'b0), .geo_wedge_grating(1'b0), .native_size(2'd0),
		.x(x), .y(y), .active(1'b1), .pattern(pattern),
		.level_percent(level_percent), .setup_75(setup_75), .invert(1'b0),
		.raster_border(1'b0), .channel_enable(3'b111),
		.red(red), .green(green), .blue(blue)
	);

	initial begin
		if ($value$plusargs("PATTERN=%d", pattern_arg)) pattern = pattern_arg[4:0];
		if ($value$plusargs("LEVEL=%d", level_arg)) level_percent = level_arg[6:0];
		if ($value$plusargs("SETUP=%d", setup_arg)) setup_75 = (setup_arg != 0);
		if (!$value$plusargs("OUT=%s", output_path)) output_path = "build/frame.ppm";

		output_file = $fopen(output_path, "wb");
		if (!output_file) $fatal(1, "cannot open output frame");
		$fwrite(output_file, "P6\n720 480\n255\n");

		active_pixels = 0;
		for (iy = 0; iy < 480; iy = iy + 1) begin
			for (ix = 0; ix < 720; ix = ix + 1) begin
				x = ix[11:0];
				y = iy[11:0];
				#1;
				$fwrite(output_file, "%c%c%c", red, green, blue);
				active_pixels = active_pixels + 1;
			end
		end

		$fclose(output_file);
		$display("Wrote %0d canonical pattern pixels to %0s", active_pixels, output_path);
		$finish;
	end
endmodule
