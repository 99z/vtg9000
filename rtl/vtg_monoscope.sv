// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

// Original calibration chart, evaluated directly from native coordinates.
// Ellipse coefficients preserve circles on a displayed 4:3 image.
// No stored image, framebuffer, or video pipeline.
module vtg_monoscope #(parameter integer WIDTH = 720, HEIGHT = 480, parameter USE_EXTERNAL_GEOMETRY = 0)
(
	input wire [1:0] native_size,
    input wire geo_mono_inner, geo_mono_ring, geo_wedge_inside, geo_wedge_grating,
	input wire [11:0] x,
	input wire [11:0] y,
	output reg [7:0] gray
);

function automatic [11:0] hx(input integer value);
    case (native_size)
        1: hx = 12'(value * 916 / 720);
        2: hx = 12'(value * 1360 / 720);
        default: hx = 12'(value * WIDTH / 720);
    endcase
endfunction
function automatic [11:0] vy(input integer value);
    case (native_size)
        1: vy = 12'(value * 720 / 480);
        2: vy = 12'(value * 1080 / 480);
        default: vy = 12'(value * HEIGHT / 480);
    endcase
endfunction
// Constant boundaries for the selected native raster: no variable dividers.
function automatic [11:0] xb(input integer index, input integer cells);
    case (native_size)
        1: xb=12'((index*916+cells-1)/cells);
        2: xb=12'((index*1360+cells-1)/cells);
        default: xb=12'((index*WIDTH+cells-1)/cells);
    endcase
endfunction
function automatic [11:0] yb(input integer index, input integer cells);
    case (native_size)
        1: yb=12'((index*720+cells-1)/cells);
        2: yb=12'((index*1080+cells-1)/cells);
        default: yb=12'((index*HEIGHT+cells-1)/cells);
    endcase
endfunction
function automatic grid_x(input integer cells);
    integer line;
    begin
        grid_x=0;
        for(line=0;line<32;line=line+1)
            if(line<cells && x==xb(line,cells)) grid_x=1;
    end
endfunction
function automatic grid_y(input integer cells, input [11:0] thickness);
    integer line;
    begin
        grid_y=0;
        for(line=0;line<24;line=line+1)
            if(line<cells && y>=yb(line,cells) && y<yb(line,cells)+12'(thickness)) grid_y=1;
    end
endfunction
wire [63:0] CIRCLE_X = (native_size == 1) ? (64'd64 * 1024 * 720 * 720 / 916 / 916) :
    (native_size == 2) ? (64'd64 * 1024 * 720 * 720 / 1360 / 1360) : (64'd64 * 1024 * 720 * 720 / 64'(WIDTH) / 64'(WIDTH));
wire [63:0] CIRCLE_Y = (native_size == 1) ? (64'd81 * 1024 * 480 * 480 / 720 / 720) :
    (native_size == 2) ? (64'd81 * 1024 * 480 * 480 / 1080 / 1080) : (64'd81 * 1024 * 480 * 480 / 64'(HEIGHT) / 64'(HEIGHT));
wire [11:0] center_x=(native_size==1)?12'd458:(native_size==2)?12'd680:12'(WIDTH/2);
wire [11:0] center_y=(native_size==1)?12'd360:(native_size==2)?12'd540:12'(HEIGHT/2);
wire signed [12:0] dx = $signed({1'b0, x}) - $signed({1'b0,center_x});
wire signed [12:0] dy = $signed({1'b0, y}) - $signed({1'b0,center_y});
wire [25:0] dx_squared = 26'(dx * dx);
wire [25:0] dy_squared = 26'(dy * dy);
wire [63:0] radius_squared = (64'(dx_squared) * CIRCLE_X) + (64'(dy_squared) * CIRCLE_Y);
wire [12:0] abs_dx = dx[12] ? 13'(-dx) : 13'(dx);
wire [12:0] fan_origin=(native_size==1)?13'd96:(native_size==2)?13'd144:13'(HEIGHT*64/480);
wire [12:0] fan_y = {1'b0, y} - fan_origin;
wire [31:0] fan_x8 = (native_size == 1) ? (32'(abs_dx) * 8 * 720 * 720) :
    (native_size == 2) ? (32'(abs_dx) * 8 * 1080 * 720) : (32'(abs_dx) * 8 * HEIGHT * 720);
wire [31:0] fan_height = (native_size == 1) ? (32'(fan_y) * 916 * 480) :
    (native_size == 2) ? (32'(fan_y) * 1360 * 480) : (32'(fan_y) * WIDTH * 480);
// Each comparison has constant endpoints. Select the finished flags rather
// than multiplying a mode-dependent step by the block index in the pixel path.
function automatic outer_x_even;
    integer block_index;
    reg sd, hd720, hd1080;
    begin
        sd=0; hd720=0; hd1080=0;
        for(block_index=0;block_index<21;block_index=block_index+1) begin
            if(x>=12'(block_index*36) && x<12'(block_index*36+18)) sd=1;
            if(x>=12'(block_index*44) && x<12'(block_index*44+22)) hd720=1;
            if(x>=12'(block_index*68) && x<12'(block_index*68+34)) hd1080=1;
        end
        outer_x_even=(native_size==1)?hd720:(native_size==2)?hd1080:sd;
    end
endfunction
function automatic outer_y_even;
    integer block_index;
    reg sd, hd720, hd1080;
    begin
        sd=0; hd720=0; hd1080=0;
        for(block_index=0;block_index<15;block_index=block_index+1) begin
            if(y>=12'(block_index*32) && y<12'(block_index*32+16)) sd=1;
            if(y>=12'(block_index*48) && y<12'(block_index*48+24)) hd720=1;
            if(y>=12'(block_index*72) && y<12'(block_index*72+36)) hd1080=1;
        end
        outer_y_even=(native_size==1)?hd720:(native_size==2)?hd1080:sd;
    end
endfunction
// x = 2*q + parity. Base-4 digits of q sum modulo three because 4=1
// modulo three. This exact period-six grating avoids a synthesized divider.
wire [4:0] mod3_sum=5'(x[2:1])+5'(x[4:3])+5'(x[6:5])+5'(x[8:7])+5'(x[10:9])+5'(x[11]);
wire q_mod3_zero=(mod3_sum==0)||(mod3_sum==3)||(mod3_sum==6)||
    (mod3_sum==9)||(mod3_sum==12)||(mod3_sum==15);
wire q_mod3_one=(mod3_sum==1)||(mod3_sum==4)||(mod3_sum==7)||
    (mod3_sum==10)||(mod3_sum==13)||(mod3_sum==16);
wire period_six_white=q_mod3_zero || (q_mod3_one && !x[0]);
reg grating;

always @* begin
	gray = 8'd64;
	grating = 0;
	// 16x12 background grid, with even-row horizontal lines also visible in 240p.
	if (grid_x(16) || grid_y(12,2)) gray = 8'd128;

	if (USE_EXTERNAL_GEOMETRY ? geo_mono_inner : radius_squared < 64'd3276800000) begin
		gray = 8'd32;
		// Eight pairs of diverging rays form a resolution wedge. The bands
		// become narrower near its tip, using only constant-slope comparisons.
		if ((y >= vy(64)) && (y < vy(136)) && (USE_EXTERNAL_GEOMETRY ? geo_wedge_inside : (fan_x8 <= (fan_height << 3)))) begin
			grating = USE_EXTERNAL_GEOMETRY ? geo_wedge_grating : (fan_x8 < fan_height) ||
				((fan_x8 >= fan_height * 2) && (fan_x8 < fan_height * 3)) ||
				((fan_x8 >= fan_height * 4) && (fan_x8 < fan_height * 5)) ||
				((fan_x8 >= fan_height * 6) && (fan_x8 < fan_height * 7));
			gray = grating ? 8'd255 : 8'd0;
		end
		// Six exact normalized grayscale steps, black through white.
		if ((x >= hx(180)) && (x < hx(540)) && (y >= vy(156)) && (y < vy(196))) begin
			if (x < hx(240)) gray = 8'd0;
			else if (x < hx(300)) gray = 8'd51;
			else if (x < hx(360)) gray = 8'd102;
			else if (x < hx(420)) gray = 8'd153;
			else if (x < hx(480)) gray = 8'd204;
			else gray = 8'd255;
		end
		// Five vertical gratings: periods 16, 8, 6, 4, and 2 logical samples.
		if ((x >= hx(180)) && (x < hx(540)) && (y >= vy(292)) && (y < vy(340))) begin
			if (x < hx(252)) grating = (x[3:0] < 8);
			else if (x < hx(324)) grating = (x[2:0] < 4);
			else if (x < hx(396)) grating = period_six_white;
			else if (x < hx(468)) grating = ~x[1];
			else grating = ~x[0];
			gray = grating ? 8'd255 : 8'd0;
		end
		// Low-frequency horizontal bars for comparing horizontal/vertical focus.
		if ((x >= hx(300)) && (x < hx(420)) && (y >= vy(360)) && (y < vy(400)))
			gray = y[2] ? 8'd0 : 8'd255;
		// Center target and orthogonal convergence marks.
		if (((x >= hx(324)) && (x < hx(396)) && ((y == vy(220)) || (y == vy(259)))) ||
		    ((y >= vy(220)) && (y < vy(260)) && ((x == hx(324)) || (x == hx(395)))))
			gray = 8'd255;
	end
	// A two-row outline retains the circle's extremities in progressive mode.
	if (USE_EXTERNAL_GEOMETRY ? geo_mono_ring : ((radius_squared >= 64'd3276800000) && (radius_squared <= 64'd3358720000)))
		gray = 8'd255;
	if ((x == hx(360) - 12'd1) || (x == hx(360)) || (y == vy(240) - 12'd1) || (y == vy(240))) gray = 8'd255;
	// Alternating edge blocks and a continuous outer border reveal overscan.
	if ((x < hx(18)) || (x >= hx(702)) || (y < vy(16)) || (y >= vy(464)))
		gray = (outer_x_even() == outer_y_even()) ? 8'd255 : 8'd0;
	if ((x < hx(2)) || (x >= hx(718)) || (y < vy(2)) || (y >= vy(478))) gray = 8'd255;
end

endmodule
