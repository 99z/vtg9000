// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

module vtg_patterns #(parameter integer WIDTH = 720, HEIGHT = 480, parameter PIPELINED = 0, USE_EXTERNAL_GEOMETRY = 0)
(
	input  wire [1:0]  native_size,
    input wire clk,
    input wire geo_circle_white, geo_mono_inner, geo_mono_ring, geo_wedge_inside, geo_wedge_grating,
	input  wire [11:0] x,
	input  wire [11:0] y,
	input  wire        active,
	input  wire [4:0]  pattern,
	input  wire [6:0]  level_percent,
	input  wire        setup_75,
	input  wire        invert,
	input  wire        raster_border,
	input  wire [2:0]  channel_enable,
	output reg  [7:0]  red,
	output reg  [7:0]  green,
	output reg  [7:0]  blue
);

localparam [4:0] PAT_SPLIT_BARS = 5'd0;
localparam [4:0] PAT_FLAT_FIELD = 5'd1;
localparam [4:0] PAT_CROSSHATCH = 5'd2;
localparam [4:0] PAT_GRAYSCALE  = 5'd3;
localparam [4:0] PAT_RAMP       = 5'd4;
localparam [4:0] PAT_ALT_PIXELS = 5'd5;
localparam [4:0] PAT_WINDOW     = 5'd6;
localparam [4:0] PAT_CIRCLES    = 5'd7;
localparam [4:0] PAT_PLUGE      = 5'd8;
localparam [4:0] PAT_MULTIBURST = 5'd9;
localparam [4:0] PAT_CHECKER    = 5'd10;
localparam [4:0] PAT_SAFE_AREA  = 5'd11;
localparam [4:0] PAT_FOCUS_DOTS = 5'd12;
localparam [4:0] PAT_SMPTE_BARS = 5'd13;
localparam [4:0] PAT_EBU_BARS   = 5'd14;
localparam [4:0] PAT_MEDIUM_GRID = 5'd15;
localparam [4:0] PAT_FINE_GRID   = 5'd16;
localparam [4:0] PAT_MONOSCOPE   = 5'd17;

// Each size selects constant native geometry boundaries; no image resampling.
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
// Encode each bit of the 16-band index independently. Mutually exclusive
// intervals avoid a priority chain through all fifteen thresholds.
function automatic gray_band_bit(input integer bit_index);
    integer block_index;
    begin
        gray_band_bit=0;
        for(block_index=0;block_index<8;block_index=block_index+1)
            if (((block_index*2+1)<<bit_index)<16 &&
                x>=xb((block_index*2+1)<<bit_index,16) &&
                ((((block_index*2+2)<<bit_index)>=16) ||
                 x<xb((block_index*2+2)<<bit_index,16))) gray_band_bit=1;
    end
endfunction
wire [63:0] CIRCLE_X = (native_size == 1) ? (64'd64 * 1024 * 720 * 720 / 916 / 916) :
    (native_size == 2) ? (64'd64 * 1024 * 720 * 720 / 1360 / 1360) : (64'd64 * 1024 * 720 * 720 / 64'(WIDTH) / 64'(WIDTH));
wire [63:0] CIRCLE_Y = (native_size == 1) ? (64'd81 * 1024 * 480 * 480 / 720 / 720) :
    (native_size == 2) ? (64'd81 * 1024 * 480 * 480 / 1080 / 1080) : (64'd81 * 1024 * 480 * 480 / 64'(HEIGHT) / 64'(HEIGHT));


// Full-range normalized artwork codes. PLUGE is generated separately so its
// negative relative levels survive when a 7.5 IRE pedestal provides headroom.
// 0 IRE clips below-black: unsigned RGB cannot encode a negative voltage.
wire [7:0] monoscope_gray;
vtg_monoscope #(.WIDTH(WIDTH), .HEIGHT(HEIGHT), .USE_EXTERNAL_GEOMETRY(USE_EXTERNAL_GEOMETRY)) monoscope (
    .geo_mono_inner(geo_mono_inner), .geo_mono_ring(geo_mono_ring),
    .geo_wedge_inside(geo_wedge_inside), .geo_wedge_grating(geo_wedge_grating), .native_size(native_size), .x(x), .y(y), .gray(monoscope_gray));

// Direct code selection for the requested pedestal; no clocked video pipeline.
// round(255 * 0.075 + code * 0.925), expressed as a compact constant table to
// avoid adding a divider/multiplier to the pixel path.
function automatic [7:0] setup_code(input [7:0] code, input setup_flag);
	begin
		if (!setup_flag) setup_code = code;
		else case (code)
			8'd0: setup_code = 8'd19;
			8'd1: setup_code = 8'd20;
			8'd2: setup_code = 8'd21;
			8'd3: setup_code = 8'd22;
			8'd4: setup_code = 8'd23;
			8'd5: setup_code = 8'd24;
			8'd6: setup_code = 8'd25;
			8'd7: setup_code = 8'd26;
			8'd8: setup_code = 8'd27;
			8'd9: setup_code = 8'd27;
			8'd10: setup_code = 8'd28;
			8'd11: setup_code = 8'd29;
			8'd12: setup_code = 8'd30;
			8'd13: setup_code = 8'd31;
			8'd14: setup_code = 8'd32;
			8'd15: setup_code = 8'd33;
			8'd16: setup_code = 8'd34;
			8'd17: setup_code = 8'd35;
			8'd18: setup_code = 8'd36;
			8'd19: setup_code = 8'd37;
			8'd20: setup_code = 8'd38;
			8'd21: setup_code = 8'd39;
			8'd22: setup_code = 8'd39;
			8'd23: setup_code = 8'd40;
			8'd24: setup_code = 8'd41;
			8'd25: setup_code = 8'd42;
			8'd26: setup_code = 8'd43;
			8'd27: setup_code = 8'd44;
			8'd28: setup_code = 8'd45;
			8'd29: setup_code = 8'd46;
			8'd30: setup_code = 8'd47;
			8'd31: setup_code = 8'd48;
			8'd32: setup_code = 8'd49;
			8'd33: setup_code = 8'd50;
			8'd34: setup_code = 8'd51;
			8'd35: setup_code = 8'd52;
			8'd36: setup_code = 8'd52;
			8'd37: setup_code = 8'd53;
			8'd38: setup_code = 8'd54;
			8'd39: setup_code = 8'd55;
			8'd40: setup_code = 8'd56;
			8'd41: setup_code = 8'd57;
			8'd42: setup_code = 8'd58;
			8'd43: setup_code = 8'd59;
			8'd44: setup_code = 8'd60;
			8'd45: setup_code = 8'd61;
			8'd46: setup_code = 8'd62;
			8'd47: setup_code = 8'd63;
			8'd48: setup_code = 8'd64;
			8'd49: setup_code = 8'd64;
			8'd50: setup_code = 8'd65;
			8'd51: setup_code = 8'd66;
			8'd52: setup_code = 8'd67;
			8'd53: setup_code = 8'd68;
			8'd54: setup_code = 8'd69;
			8'd55: setup_code = 8'd70;
			8'd56: setup_code = 8'd71;
			8'd57: setup_code = 8'd72;
			8'd58: setup_code = 8'd73;
			8'd59: setup_code = 8'd74;
			8'd60: setup_code = 8'd75;
			8'd61: setup_code = 8'd76;
			8'd62: setup_code = 8'd76;
			8'd63: setup_code = 8'd77;
			8'd64: setup_code = 8'd78;
			8'd65: setup_code = 8'd79;
			8'd66: setup_code = 8'd80;
			8'd67: setup_code = 8'd81;
			8'd68: setup_code = 8'd82;
			8'd69: setup_code = 8'd83;
			8'd70: setup_code = 8'd84;
			8'd71: setup_code = 8'd85;
			8'd72: setup_code = 8'd86;
			8'd73: setup_code = 8'd87;
			8'd74: setup_code = 8'd88;
			8'd75: setup_code = 8'd89;
			8'd76: setup_code = 8'd89;
			8'd77: setup_code = 8'd90;
			8'd78: setup_code = 8'd91;
			8'd79: setup_code = 8'd92;
			8'd80: setup_code = 8'd93;
			8'd81: setup_code = 8'd94;
			8'd82: setup_code = 8'd95;
			8'd83: setup_code = 8'd96;
			8'd84: setup_code = 8'd97;
			8'd85: setup_code = 8'd98;
			8'd86: setup_code = 8'd99;
			8'd87: setup_code = 8'd100;
			8'd88: setup_code = 8'd101;
			8'd89: setup_code = 8'd101;
			8'd90: setup_code = 8'd102;
			8'd91: setup_code = 8'd103;
			8'd92: setup_code = 8'd104;
			8'd93: setup_code = 8'd105;
			8'd94: setup_code = 8'd106;
			8'd95: setup_code = 8'd107;
			8'd96: setup_code = 8'd108;
			8'd97: setup_code = 8'd109;
			8'd98: setup_code = 8'd110;
			8'd99: setup_code = 8'd111;
			8'd100: setup_code = 8'd112;
			8'd101: setup_code = 8'd113;
			8'd102: setup_code = 8'd113;
			8'd103: setup_code = 8'd114;
			8'd104: setup_code = 8'd115;
			8'd105: setup_code = 8'd116;
			8'd106: setup_code = 8'd117;
			8'd107: setup_code = 8'd118;
			8'd108: setup_code = 8'd119;
			8'd109: setup_code = 8'd120;
			8'd110: setup_code = 8'd121;
			8'd111: setup_code = 8'd122;
			8'd112: setup_code = 8'd123;
			8'd113: setup_code = 8'd124;
			8'd114: setup_code = 8'd125;
			8'd115: setup_code = 8'd126;
			8'd116: setup_code = 8'd126;
			8'd117: setup_code = 8'd127;
			8'd118: setup_code = 8'd128;
			8'd119: setup_code = 8'd129;
			8'd120: setup_code = 8'd130;
			8'd121: setup_code = 8'd131;
			8'd122: setup_code = 8'd132;
			8'd123: setup_code = 8'd133;
			8'd124: setup_code = 8'd134;
			8'd125: setup_code = 8'd135;
			8'd126: setup_code = 8'd136;
			8'd127: setup_code = 8'd137;
			8'd128: setup_code = 8'd138;
			8'd129: setup_code = 8'd138;
			8'd130: setup_code = 8'd139;
			8'd131: setup_code = 8'd140;
			8'd132: setup_code = 8'd141;
			8'd133: setup_code = 8'd142;
			8'd134: setup_code = 8'd143;
			8'd135: setup_code = 8'd144;
			8'd136: setup_code = 8'd145;
			8'd137: setup_code = 8'd146;
			8'd138: setup_code = 8'd147;
			8'd139: setup_code = 8'd148;
			8'd140: setup_code = 8'd149;
			8'd141: setup_code = 8'd150;
			8'd142: setup_code = 8'd150;
			8'd143: setup_code = 8'd151;
			8'd144: setup_code = 8'd152;
			8'd145: setup_code = 8'd153;
			8'd146: setup_code = 8'd154;
			8'd147: setup_code = 8'd155;
			8'd148: setup_code = 8'd156;
			8'd149: setup_code = 8'd157;
			8'd150: setup_code = 8'd158;
			8'd151: setup_code = 8'd159;
			8'd152: setup_code = 8'd160;
			8'd153: setup_code = 8'd161;
			8'd154: setup_code = 8'd162;
			8'd155: setup_code = 8'd163;
			8'd156: setup_code = 8'd163;
			8'd157: setup_code = 8'd164;
			8'd158: setup_code = 8'd165;
			8'd159: setup_code = 8'd166;
			8'd160: setup_code = 8'd167;
			8'd161: setup_code = 8'd168;
			8'd162: setup_code = 8'd169;
			8'd163: setup_code = 8'd170;
			8'd164: setup_code = 8'd171;
			8'd165: setup_code = 8'd172;
			8'd166: setup_code = 8'd173;
			8'd167: setup_code = 8'd174;
			8'd168: setup_code = 8'd175;
			8'd169: setup_code = 8'd175;
			8'd170: setup_code = 8'd176;
			8'd171: setup_code = 8'd177;
			8'd172: setup_code = 8'd178;
			8'd173: setup_code = 8'd179;
			8'd174: setup_code = 8'd180;
			8'd175: setup_code = 8'd181;
			8'd176: setup_code = 8'd182;
			8'd177: setup_code = 8'd183;
			8'd178: setup_code = 8'd184;
			8'd179: setup_code = 8'd185;
			8'd180: setup_code = 8'd186;
			8'd181: setup_code = 8'd187;
			8'd182: setup_code = 8'd187;
			8'd183: setup_code = 8'd188;
			8'd184: setup_code = 8'd189;
			8'd185: setup_code = 8'd190;
			8'd186: setup_code = 8'd191;
			8'd187: setup_code = 8'd192;
			8'd188: setup_code = 8'd193;
			8'd189: setup_code = 8'd194;
			8'd190: setup_code = 8'd195;
			8'd191: setup_code = 8'd196;
			8'd192: setup_code = 8'd197;
			8'd193: setup_code = 8'd198;
			8'd194: setup_code = 8'd199;
			8'd195: setup_code = 8'd200;
			8'd196: setup_code = 8'd200;
			8'd197: setup_code = 8'd201;
			8'd198: setup_code = 8'd202;
			8'd199: setup_code = 8'd203;
			8'd200: setup_code = 8'd204;
			8'd201: setup_code = 8'd205;
			8'd202: setup_code = 8'd206;
			8'd203: setup_code = 8'd207;
			8'd204: setup_code = 8'd208;
			8'd205: setup_code = 8'd209;
			8'd206: setup_code = 8'd210;
			8'd207: setup_code = 8'd211;
			8'd208: setup_code = 8'd212;
			8'd209: setup_code = 8'd212;
			8'd210: setup_code = 8'd213;
			8'd211: setup_code = 8'd214;
			8'd212: setup_code = 8'd215;
			8'd213: setup_code = 8'd216;
			8'd214: setup_code = 8'd217;
			8'd215: setup_code = 8'd218;
			8'd216: setup_code = 8'd219;
			8'd217: setup_code = 8'd220;
			8'd218: setup_code = 8'd221;
			8'd219: setup_code = 8'd222;
			8'd220: setup_code = 8'd223;
			8'd221: setup_code = 8'd224;
			8'd222: setup_code = 8'd224;
			8'd223: setup_code = 8'd225;
			8'd224: setup_code = 8'd226;
			8'd225: setup_code = 8'd227;
			8'd226: setup_code = 8'd228;
			8'd227: setup_code = 8'd229;
			8'd228: setup_code = 8'd230;
			8'd229: setup_code = 8'd231;
			8'd230: setup_code = 8'd232;
			8'd231: setup_code = 8'd233;
			8'd232: setup_code = 8'd234;
			8'd233: setup_code = 8'd235;
			8'd234: setup_code = 8'd236;
			8'd235: setup_code = 8'd237;
			8'd236: setup_code = 8'd237;
			8'd237: setup_code = 8'd238;
			8'd238: setup_code = 8'd239;
			8'd239: setup_code = 8'd240;
			8'd240: setup_code = 8'd241;
			8'd241: setup_code = 8'd242;
			8'd242: setup_code = 8'd243;
			8'd243: setup_code = 8'd244;
			8'd244: setup_code = 8'd245;
			8'd245: setup_code = 8'd246;
			8'd246: setup_code = 8'd247;
			8'd247: setup_code = 8'd248;
			8'd248: setup_code = 8'd249;
			8'd249: setup_code = 8'd249;
			8'd250: setup_code = 8'd250;
			8'd251: setup_code = 8'd251;
			8'd252: setup_code = 8'd252;
			8'd253: setup_code = 8'd253;
			8'd254: setup_code = 8'd254;
			default: setup_code = 8'd255;
		endcase
	end
endfunction

// Signed levels relative to picture black, in percent of the black-to-white
// excursion. Keep this separate from the normalized-code table so PLUGE is
// rounded once, including its -2% bar.
function automatic [7:0] pluge_code(input integer percent);
	integer numerator;
	begin
		if (setup_75) numerator = 76500 + 9435 * percent;
		else          numerator = 10200 * percent;
		if (numerator < 0) pluge_code = 8'd0;
		else pluge_code = 8'((numerator + 2000) / 4000);
	end
endfunction

reg [7:0] r;
reg [7:0] g;
reg [7:0] b;
reg [7:0] level_code;
reg exact_code;
// Native coordinates and centers fit in signed 13 bits, including blanking.
reg signed [12:0] dx;
reg signed [12:0] dy;
reg [63:0] distance_scaled;
reg [2:0] band;
reg [4:0] band_x;
reg [3:0] gray_step;
integer gray_index;
reg checker_x_odd;
reg checker_y_odd;

always @* begin
	case (level_percent)
		7'd0: level_code = setup_75 ? 8'd19 : 8'd0;
		7'd1: level_code = setup_75 ? 8'd21 : 8'd3;
		7'd2: level_code = setup_75 ? 8'd24 : 8'd5;
		7'd3: level_code = setup_75 ? 8'd26 : 8'd8;
		7'd4: level_code = setup_75 ? 8'd29 : 8'd10;
		7'd5: level_code = setup_75 ? 8'd31 : 8'd13;
		7'd6: level_code = setup_75 ? 8'd33 : 8'd15;
		7'd7: level_code = setup_75 ? 8'd36 : 8'd18;
		7'd8: level_code = setup_75 ? 8'd38 : 8'd20;
		7'd9: level_code = setup_75 ? 8'd40 : 8'd23;
		7'd10: level_code = setup_75 ? 8'd43 : 8'd26;
		7'd11: level_code = setup_75 ? 8'd45 : 8'd28;
		7'd12: level_code = setup_75 ? 8'd47 : 8'd31;
		7'd13: level_code = setup_75 ? 8'd50 : 8'd33;
		7'd14: level_code = setup_75 ? 8'd52 : 8'd36;
		7'd15: level_code = setup_75 ? 8'd55 : 8'd38;
		7'd16: level_code = setup_75 ? 8'd57 : 8'd41;
		7'd17: level_code = setup_75 ? 8'd59 : 8'd43;
		7'd18: level_code = setup_75 ? 8'd62 : 8'd46;
		7'd19: level_code = setup_75 ? 8'd64 : 8'd48;
		7'd20: level_code = setup_75 ? 8'd66 : 8'd51;
		7'd21: level_code = setup_75 ? 8'd69 : 8'd54;
		7'd22: level_code = setup_75 ? 8'd71 : 8'd56;
		7'd23: level_code = setup_75 ? 8'd73 : 8'd59;
		7'd24: level_code = setup_75 ? 8'd76 : 8'd61;
		7'd25: level_code = setup_75 ? 8'd78 : 8'd64;
		7'd26: level_code = setup_75 ? 8'd80 : 8'd66;
		7'd27: level_code = setup_75 ? 8'd83 : 8'd69;
		7'd28: level_code = setup_75 ? 8'd85 : 8'd71;
		7'd29: level_code = setup_75 ? 8'd88 : 8'd74;
		7'd30: level_code = setup_75 ? 8'd90 : 8'd77;
		7'd31: level_code = setup_75 ? 8'd92 : 8'd79;
		7'd32: level_code = setup_75 ? 8'd95 : 8'd82;
		7'd33: level_code = setup_75 ? 8'd97 : 8'd84;
		7'd34: level_code = setup_75 ? 8'd99 : 8'd87;
		7'd35: level_code = setup_75 ? 8'd102 : 8'd89;
		7'd36: level_code = setup_75 ? 8'd104 : 8'd92;
		7'd37: level_code = setup_75 ? 8'd106 : 8'd94;
		7'd38: level_code = setup_75 ? 8'd109 : 8'd97;
		7'd39: level_code = setup_75 ? 8'd111 : 8'd99;
		7'd40: level_code = setup_75 ? 8'd113 : 8'd102;
		7'd41: level_code = setup_75 ? 8'd116 : 8'd105;
		7'd42: level_code = setup_75 ? 8'd118 : 8'd107;
		7'd43: level_code = setup_75 ? 8'd121 : 8'd110;
		7'd44: level_code = setup_75 ? 8'd123 : 8'd112;
		7'd45: level_code = setup_75 ? 8'd125 : 8'd115;
		7'd46: level_code = setup_75 ? 8'd128 : 8'd117;
		7'd47: level_code = setup_75 ? 8'd130 : 8'd120;
		7'd48: level_code = setup_75 ? 8'd132 : 8'd122;
		7'd49: level_code = setup_75 ? 8'd135 : 8'd125;
		7'd50: level_code = setup_75 ? 8'd137 : 8'd128;
		7'd51: level_code = setup_75 ? 8'd139 : 8'd130;
		7'd52: level_code = setup_75 ? 8'd142 : 8'd133;
		7'd53: level_code = setup_75 ? 8'd144 : 8'd135;
		7'd54: level_code = setup_75 ? 8'd146 : 8'd138;
		7'd55: level_code = setup_75 ? 8'd149 : 8'd140;
		7'd56: level_code = setup_75 ? 8'd151 : 8'd143;
		7'd57: level_code = setup_75 ? 8'd154 : 8'd145;
		7'd58: level_code = setup_75 ? 8'd156 : 8'd148;
		7'd59: level_code = setup_75 ? 8'd158 : 8'd150;
		7'd60: level_code = setup_75 ? 8'd161 : 8'd153;
		7'd61: level_code = setup_75 ? 8'd163 : 8'd156;
		7'd62: level_code = setup_75 ? 8'd165 : 8'd158;
		7'd63: level_code = setup_75 ? 8'd168 : 8'd161;
		7'd64: level_code = setup_75 ? 8'd170 : 8'd163;
		7'd65: level_code = setup_75 ? 8'd172 : 8'd166;
		7'd66: level_code = setup_75 ? 8'd175 : 8'd168;
		7'd67: level_code = setup_75 ? 8'd177 : 8'd171;
		7'd68: level_code = setup_75 ? 8'd180 : 8'd173;
		7'd69: level_code = setup_75 ? 8'd182 : 8'd176;
		7'd70: level_code = setup_75 ? 8'd184 : 8'd179;
		7'd71: level_code = setup_75 ? 8'd187 : 8'd181;
		7'd72: level_code = setup_75 ? 8'd189 : 8'd184;
		7'd73: level_code = setup_75 ? 8'd191 : 8'd186;
		7'd74: level_code = setup_75 ? 8'd194 : 8'd189;
		7'd75: level_code = setup_75 ? 8'd196 : 8'd191;
		7'd76: level_code = setup_75 ? 8'd198 : 8'd194;
		7'd77: level_code = setup_75 ? 8'd201 : 8'd196;
		7'd78: level_code = setup_75 ? 8'd203 : 8'd199;
		7'd79: level_code = setup_75 ? 8'd205 : 8'd201;
		7'd80: level_code = setup_75 ? 8'd208 : 8'd204;
		7'd81: level_code = setup_75 ? 8'd210 : 8'd207;
		7'd82: level_code = setup_75 ? 8'd213 : 8'd209;
		7'd83: level_code = setup_75 ? 8'd215 : 8'd212;
		7'd84: level_code = setup_75 ? 8'd217 : 8'd214;
		7'd85: level_code = setup_75 ? 8'd220 : 8'd217;
		7'd86: level_code = setup_75 ? 8'd222 : 8'd219;
		7'd87: level_code = setup_75 ? 8'd224 : 8'd222;
		7'd88: level_code = setup_75 ? 8'd227 : 8'd224;
		7'd89: level_code = setup_75 ? 8'd229 : 8'd227;
		7'd90: level_code = setup_75 ? 8'd231 : 8'd230;
		7'd91: level_code = setup_75 ? 8'd234 : 8'd232;
		7'd92: level_code = setup_75 ? 8'd236 : 8'd235;
		7'd93: level_code = setup_75 ? 8'd238 : 8'd237;
		7'd94: level_code = setup_75 ? 8'd241 : 8'd240;
		7'd95: level_code = setup_75 ? 8'd243 : 8'd242;
		7'd96: level_code = setup_75 ? 8'd246 : 8'd245;
		7'd97: level_code = setup_75 ? 8'd248 : 8'd247;
		7'd98: level_code = setup_75 ? 8'd250 : 8'd250;
		7'd99: level_code = setup_75 ? 8'd253 : 8'd252;
		default: level_code = 8'd255;
	endcase
	exact_code = 0;
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
				if (y < vy(240)) begin
					if (x < hx(90))       begin r = 8'd255; g = 8'd255; b = 8'd255; end
					else if (x < hx(180)) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
					else if (x < hx(270)) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
					else if (x < hx(360)) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
					else if (x < hx(450)) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
					else if (x < hx(540)) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
					else if (x < hx(630)) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
					else              begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
				end else begin
					if (x < hx(90))       begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < hx(180)) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
					else if (x < hx(270)) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
					else if (x < hx(360)) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
					else if (x < hx(450)) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
					else if (x < hx(540)) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
					else if (x < hx(630)) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
					else              begin r = 8'd255; g = 8'd255; b = 8'd255; end
				end
			end

			PAT_FLAT_FIELD: begin
				exact_code = 1;
				r = level_code;
				g = level_code;
				b = level_code;
			end

			PAT_CROSSHATCH, PAT_MEDIUM_GRID, PAT_FINE_GRID: begin
				// Square cells on a 4:3 display: 8x6, 16x12, and 32x24.
				if (((pattern == PAT_CROSSHATCH) && (grid_x(8) || grid_y(6,1))) ||
				    ((pattern == PAT_MEDIUM_GRID) && (grid_x(16) || grid_y(12,1))) ||
				    ((pattern == PAT_FINE_GRID) && (grid_x(32) || grid_y(24,1))) ||
				    (x == hx(720) - 12'd1) || (y == vy(480) - 12'd1)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_GRAYSCALE: begin
				// Thirty-two displayed patches: 16 steps per row, with the
				// direction reversed in the lower half as shown in the manual.
				for(gray_index=0;gray_index<4;gray_index=gray_index+1)
                    gray_step[gray_index]=gray_band_bit(gray_index);
				if (y < vy(240)) r = ~{gray_step,gray_step};
				else         r = {gray_step,gray_step};
				g = r;
				b = r;
			end

			PAT_RAMP: begin
				// Widen before multiplying: the 12-bit product previously wrapped
				// every ~45 samples instead of producing a monotonic full ramp.
				case (native_size)
                    1: r = 8'(({20'd0, x} * 32'd584453) >> 21);
                    2: r = 8'(({20'd0, x} * 32'd393506) >> 21);
                    default: r = 8'(({20'd0, x} * 32'd91) >> 8);
                endcase
				g = r;
				b = r;
			end

			PAT_ALT_PIXELS: begin
				if (~x[0]) begin r = 8'hff; g = 8'hff; b = 8'hff; end
			end

			PAT_WINDOW: begin
				if ((x >= hx(180)) && (x < hx(540)) && (y >= vy(120)) && (y < vy(360))) begin
					exact_code = 1; r = level_code; g = level_code; b = level_code;
				end
			end

			PAT_CIRCLES: begin
                if (USE_EXTERNAL_GEOMETRY) begin
                    if (geo_circle_white) begin r=255;g=255;b=255;end
                end else begin
				dx = 13'({20'd0, x});
				dy = 13'({20'd0, y});
				dx = dx - $signed({1'b0, hx(360)});
				dy = dy - $signed({1'b0, vy(240)});
				distance_scaled = (64'(dx * dx) * CIRCLE_X) + (64'(dy * dy) * CIRCLE_Y);
				if ((distance_scaled >= 64'd3301171200) && (distance_scaled <= 64'd3334348800)) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end

				dx = 13'({20'd0, x} - 32'(hx(45)));
				dy = 13'({20'd0, y} - 32'(vy(40)));
				distance_scaled = (64'(dx * dx) * CIRCLE_X) + (64'(dy * dy) * CIRCLE_Y);
				if ((distance_scaled >= 64'd77137920) && (distance_scaled <= 64'd93063168)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = 13'({20'd0, x} - 32'(hx(674)));
				distance_scaled = (64'(dx * dx) * CIRCLE_X) + (64'(dy * dy) * CIRCLE_Y);
				if ((distance_scaled >= 64'd77137920) && (distance_scaled <= 64'd93063168)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = 13'({20'd0, x} - 32'(hx(45)));
				dy = 13'({20'd0, y} - 32'(vy(439)));
				distance_scaled = (64'(dx * dx) * CIRCLE_X) + (64'(dy * dy) * CIRCLE_Y);
				if ((distance_scaled >= 64'd77137920) && (distance_scaled <= 64'd93063168)) begin r = 8'hff; g = 8'hff; b = 8'hff; end
				dx = 13'({20'd0, x} - 32'(hx(674)));
				distance_scaled = (64'(dx * dx) * CIRCLE_X) + (64'(dy * dy) * CIRCLE_Y);
				if ((distance_scaled >= 64'd77137920) && (distance_scaled <= 64'd93063168)) begin r = 8'hff; g = 8'hff; b = 8'hff; end

                end
				if ((x == hx(360) - 12'd1) || (x == hx(360)) || (y == vy(240) - 12'd1) || (y == vy(240))) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_PLUGE: begin
				exact_code = 1;
				r = pluge_code(0);
				g = pluge_code(0);
				b = pluge_code(0);

				// Three bars per side: left -2/+4/+2%, right +2/+4/-2%.
				if ((y >= vy(80)) && (y < vy(400))) begin
					if (((x >= hx(72))  && (x < hx(108))) ||
					    ((x >= hx(612)) && (x < hx(648)))) begin exact_code = 1; r = pluge_code(-2); g = pluge_code(-2); b = pluge_code(-2); end
					if (((x >= hx(126)) && (x < hx(162))) ||
					    ((x >= hx(558)) && (x < hx(594)))) begin exact_code = 1; r = pluge_code(4);  g = pluge_code(4);  b = pluge_code(4);  end
					if (((x >= hx(180)) && (x < hx(216))) ||
					    ((x >= hx(504)) && (x < hx(540)))) begin r = pluge_code(2);  g = pluge_code(2);  b = pluge_code(2);  end

					// Center contrast stack, bottom to top: 25/50/75/100%,
					// with a 95% patch inset into the 100% region.
					if ((x >= hx(281)) && (x < hx(439))) begin
						if (y < vy(160))      begin r = pluge_code(100); g = pluge_code(100); b = pluge_code(100); end
						else if (y < vy(240)) begin r = pluge_code(75);  g = pluge_code(75);  b = pluge_code(75);  end
						else if (y < vy(320)) begin r = pluge_code(50);  g = pluge_code(50);  b = pluge_code(50);  end
						else               begin r = pluge_code(25);  g = pluge_code(25);  b = pluge_code(25);  end
					end
					if ((x >= hx(315)) && (x < hx(405)) && (y >= vy(105)) && (y < vy(135))) begin
						r = pluge_code(95); g = pluge_code(95); b = pluge_code(95);
					end
				end
			end

			PAT_MULTIBURST: begin
				if (x < hx(120)) begin band = 0; band_x = x[4:0]; end
				else if (x < hx(240)) begin band = 1; band_x = 5'(x - hx(120)); end
				else if (x < hx(360)) begin band = 2; band_x = 5'(x - hx(240)); end
				else if (x < hx(480)) begin band = 3; band_x = 5'(x - hx(360)); end
				else if (x < hx(600)) begin band = 4; band_x = 5'(x - hx(480)); end
				else begin band = 5; band_x = 5'(x - hx(600)); end
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
				checker_x_odd = ((x >= hx(180)) && (x < hx(360))) || (x >= hx(540));
				checker_y_odd = ((y >= vy(120)) && (y < vy(240))) || (y >= vy(360));
				if (checker_x_odd == checker_y_odd) begin r = 8'hff; g = 8'hff; b = 8'hff; end
			end

			PAT_SAFE_AREA: begin
				if ((x == hx(36)) || (x == hx(683)) || (y == vy(24)) || (y == vy(455)) ||
				    (x == hx(72)) || (x == hx(647)) || (y == vy(48)) || (y == vy(431)) ||
				    (x == hx(360) - 12'd1) || (x == hx(360)) || (y == vy(240) - 12'd1) || (y == vy(240))) begin
					r = 8'hff; g = 8'hff; b = 8'hff;
				end
			end

			PAT_FOCUS_DOTS: begin
				r = 8'd128; g = 8'd128; b = 8'd128;
				if (((x >= hx(18))  && (x < hx(90))  && (y >= vy(16))  && (y < vy(64)))  ||
				    ((x >= hx(630)) && (x < hx(702)) && (y >= vy(16))  && (y < vy(64)))  ||
				    ((x >= hx(324)) && (x < hx(396)) && (y >= vy(216)) && (y < vy(264))) ||
				    ((x >= hx(18))  && (x < hx(90))  && (y >= vy(416)) && (y < vy(464))) ||
				    ((x >= hx(630)) && (x < hx(702)) && (y >= vy(416)) && (y < vy(464)))) begin
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
				if (y < vy(320)) begin
					if (x < hx(102))      begin r = 8'd191; g = 8'd191; b = 8'd191; end
					else if (x < hx(206)) begin r = 8'd191; g = 8'd191; b = 8'd0;   end
					else if (x < hx(308)) begin r = 8'd0;   g = 8'd191; b = 8'd191; end
					else if (x < hx(412)) begin r = 8'd0;   g = 8'd191; b = 8'd0;   end
					else if (x < hx(514)) begin r = 8'd191; g = 8'd0;   b = 8'd191; end
					else if (x < hx(618)) begin r = 8'd191; g = 8'd0;   b = 8'd0;   end
					else              begin r = 8'd0;   g = 8'd0;   b = 8'd191; end
				end else if (y < vy(360)) begin
					if (x < hx(102))      begin r = 8'd0;   g = 8'd0;   b = 8'd191; end
					else if (x < hx(206)) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < hx(308)) begin r = 8'd191; g = 8'd0;   b = 8'd191; end
					else if (x < hx(412)) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else if (x < hx(514)) begin r = 8'd0;   g = 8'd191; b = 8'd191; end
					else if (x < hx(618)) begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
					else              begin r = 8'd191; g = 8'd191; b = 8'd191; end
				end else begin
					if (x < hx(128))      begin r = 8'd0;   g = 8'd30;  b = 8'd68;  end
					else if (x < hx(258)) begin r = 8'd255; g = 8'd255; b = 8'd255; end
					else if (x < hx(386)) begin r = 8'd67;  g = 8'd0;   b = 8'd93;  end
					else if (x < hx(514)) begin exact_code = 1; r = pluge_code(0);   g = pluge_code(0);   b = pluge_code(0);   end
					else if (x < hx(566)) begin exact_code = 1; r = pluge_code(-2); g = pluge_code(-2); b = pluge_code(-2); end
					else if (x < hx(618)) begin exact_code = 1; r = pluge_code(0);   g = pluge_code(0);   b = pluge_code(0);   end
					else if (x < hx(669)) begin exact_code = 1; r = pluge_code(4);  g = pluge_code(4);  b = pluge_code(4);  end
					else              begin exact_code = 1; r = pluge_code(0);   g = pluge_code(0);   b = pluge_code(0);   end
				end
			end

			PAT_EBU_BARS: begin
				if (x < hx(90))       begin r = 8'd255; g = 8'd255; b = 8'd255; end
				else if (x < hx(180)) begin r = 8'd255; g = 8'd255; b = 8'd0;   end
				else if (x < hx(270)) begin r = 8'd0;   g = 8'd255; b = 8'd255; end
				else if (x < hx(360)) begin r = 8'd0;   g = 8'd255; b = 8'd0;   end
				else if (x < hx(450)) begin r = 8'd255; g = 8'd0;   b = 8'd255; end
				else if (x < hx(540)) begin r = 8'd255; g = 8'd0;   b = 8'd0;   end
				else if (x < hx(630)) begin r = 8'd0;   g = 8'd0;   b = 8'd255; end
				else              begin r = 8'd0;   g = 8'd0;   b = 8'd0;   end
			end

			PAT_MONOSCOPE: begin
				r = monoscope_gray; g = monoscope_gray; b = monoscope_gray;
			end

			default: begin
				r = 8'hff;
				g = 8'h00;
				b = 8'hff;
			end
		endcase

		if (raster_border && ((x < hx(2)) || (x >= hx(718)) || (y < vy(2)) || (y >= vy(478)))) begin
			exact_code = 0;
			r = 8'hff;
			g = 8'hff;
			b = 8'hff;
		end

    end
end

reg [7:0] alg_r,alg_g,alg_b,inv_r,inv_g,inv_b,final_r,final_g,final_b;
reg alg_exact,alg_active,alg_invert,alg_smpte,alg_setup;
reg inv_exact,inv_active,inv_setup;
reg [2:0] alg_channels,inv_channels;
// The optional clock is unused by the portable combinational variant.
wire _unused_clk=&{1'b0,clk,alg_channels};
wire post_invert=PIPELINED?alg_invert:invert;
wire post_smpte=PIPELINED?alg_smpte:(pattern==PAT_SMPTE_BARS);
wire post_exact=PIPELINED?alg_exact:exact_code;
wire post_active=PIPELINED?alg_active:active;
wire [7:0] post_black=(PIPELINED?alg_setup:setup_75)?8'd19:8'd0;
wire normalization_setup=PIPELINED?inv_setup:setup_75;
wire norm_exact=PIPELINED?inv_exact:exact_code;
wire norm_active=PIPELINED?inv_active:active;
wire [2:0] norm_channels=PIPELINED?inv_channels:channel_enable;
reg [7:0] post_r,post_g,post_b,norm_r,norm_g,norm_b;
wire [7:0] masked_r=norm_channels[2]?norm_r:8'd0;
wire [7:0] masked_g=norm_channels[1]?norm_g:8'd0;
wire [7:0] masked_b=norm_channels[0]?norm_b:8'd0;
always @* begin
    post_r=PIPELINED?alg_r:r;
    post_g=PIPELINED?alg_g:g;
    post_b=PIPELINED?alg_b:b;
    if(post_active) begin

		if (post_invert && (post_smpte)) begin
			// The VTG's special function for SMPTE bars is blue-only mode.
			post_r = post_exact ? post_black : 8'd0;
			post_g = post_r;
		end else if (post_invert && post_exact) begin
			// Reflect picture codes about black/white; clip post_inverted below-black
			// to white rather than wrapping past the unsigned code range.
			post_r = (post_r < post_black) ? 8'd255 : 8'(255 + {24'd0, post_black} - {24'd0, post_r});
			post_g = post_r; post_b = post_r;
		end else if (post_invert) begin
			post_r = ~post_r;
			post_g = ~post_g;
			post_b = ~post_b;
		end
    end
end
always @* begin
    norm_r=PIPELINED?inv_r:post_r;
    norm_g=PIPELINED?inv_g:post_g;
    norm_b=PIPELINED?inv_b:post_b;
    if(norm_active && !norm_exact) begin
        norm_r=setup_code(norm_r,normalization_setup); norm_g=setup_code(norm_g,normalization_setup); norm_b=setup_code(norm_b,normalization_setup);
    end
    red=PIPELINED?final_r:masked_r;
    green=PIPELINED?final_g:masked_g;
    blue=PIPELINED?final_b:masked_b;
end
generate if(PIPELINED) begin : color_stages
    always @(posedge clk) begin
        alg_r<=r;alg_g<=g;alg_b<=b;alg_exact<=exact_code;
        alg_active<=active;alg_invert<=invert;alg_smpte<=pattern==PAT_SMPTE_BARS;
        alg_setup<=setup_75;alg_channels<=channel_enable;
        inv_r<=post_r;inv_g<=post_g;inv_b<=post_b;
        inv_exact<=alg_exact;inv_active<=alg_active;inv_setup<=alg_setup;inv_channels<=alg_channels;
        final_r<=masked_r;final_g<=masked_g;final_b<=masked_b;
    end
end else begin : no_color_registers
    assign {alg_r,alg_g,alg_b,inv_r,inv_g,inv_b,final_r,final_g,final_b,
        alg_exact,alg_active,alg_invert,alg_smpte,alg_setup,inv_exact,inv_active,inv_setup,
        alg_channels,inv_channels} = '0;
end endgenerate

endmodule
