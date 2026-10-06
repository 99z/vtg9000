// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps

module vtg9000_core #(parameter integer PIPELINE_STAGES = 0)
(
	input  wire        clk,
	input  wire        reset,
	input  wire [2:0]  video_mode,
	input  wire [4:0]  pattern,
	input  wire [6:0]  level_percent,
	input  wire        setup_75,
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

// 0=480i, 1=240p, 2=480p, 3=720p60, 4=1080p60, 5=720p120.
// Uniform CE: SD transport is 27 MHz, HD transport is 128.52 MHz.
wire raw_ce, raw_hblank, raw_vblank, raw_hsync, raw_vsync;
wire raw_de, raw_frame_start, raw_field;
wire [11:0] raw_x, raw_y;
wire [7:0] raw_red, raw_green, raw_blue;
reg sample_phase = 0;
always @(posedge clk) begin
	if (reset) sample_phase <= 0;
	else sample_phase <= ~sample_phase;
end
assign raw_ce = ((video_mode < 2) || (video_mode == 3)) ? sample_phase : 1'b1;
wire legacy = video_mode < 2;
wire [11:0] lx, ly, px, py;
wire lf, lhb, lvb, ld, lhs, lvs, lstart;
wire phb, pvb, pd, phs, pvs, pstart;

vtg_raster raster
(
	.clk(clk),
	.reset(reset),
	.ce(raw_ce),
	.interlaced(video_mode == 0),
	.x(lx),
	.y(ly),
	.field(lf),
	.hblank(lhb),
	.vblank(lvb),
	.de(ld),
	.hsync(lhs),
	.vsync(lvs),
	.frame_start(lstart)
);

vtg_progressive progressive (.clk(clk), .reset(reset), .ce(raw_ce), .mode(video_mode),
    .x(px), .y(py), .hblank(phb), .vblank(pvb), .de(pd),
    .hsync(phs), .vsync(pvs), .frame_start(pstart));
assign raw_x = legacy ? lx : px;
assign raw_y = legacy ? ly : py;
assign raw_field = legacy && lf;
assign raw_hblank = legacy ? lhb : phb;
assign raw_vblank = legacy ? lvb : pvb;
assign raw_de = legacy ? ld : pd;
assign raw_hsync = legacy ? lhs : phs;
assign raw_vsync = legacy ? lvs : pvs;
assign raw_frame_start = legacy ? lstart : pstart;
wire [1:0] pattern_size = (video_mode == 4) ? 2'd2 :
    ((video_mode == 3) || (video_mode == 5)) ? 2'd1 : 2'd0;
wire [55:0] rendered;
generate if(PIPELINE_STAGES==0) begin : direct_patterns
    vtg_patterns patterns (.clk(clk), .native_size(pattern_size), .x(raw_x), .y(raw_y), .active(raw_de),
        .pattern(pattern), .level_percent(level_percent), .setup_75(setup_75), .invert(invert),
        .raster_border(raster_border), .channel_enable(channel_enable),
        .geo_circle_white(1'b0), .geo_mono_inner(1'b0), .geo_mono_ring(1'b0),
        .geo_wedge_inside(1'b0), .geo_wedge_grating(1'b0),
        .red(raw_red), .green(raw_green), .blue(raw_blue));
    assign rendered={raw_x,raw_y,raw_red,raw_green,raw_blue,raw_ce,raw_hblank,raw_vblank,
        raw_hsync,raw_vsync,raw_de,raw_frame_start,raw_field};
end else begin : staged_patterns
    // Five geometry stages followed by algorithm, inversion and code/mask stages.
    (* altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *)
    reg [51:0] controls[0:4];
    reg [31:0] timing[0:2];
    wire [11:0] gx,gy;
    wire gc,ghb,gvb,ghs,gvs,gd,gstart,gfield;
    wire [4:0] gp;
    wire [6:0] gl;
    wire gs,gi,gb;
    wire [2:0] gchannels;
    wire [1:0] gsize;
    wire cwhite,minner,mring,winside,wgrating;
    wire [31:0] geometry_timing={gx,gy,gc,ghb,gvb,ghs,gvs,gd,gstart,gfield};
    integer t;
    always @(posedge clk) begin
        controls[0]<={raw_x,raw_y,raw_ce,raw_hblank,raw_vblank,raw_hsync,raw_vsync,
            raw_de,raw_frame_start,raw_field,pattern,level_percent,setup_75,invert,
            raster_border,channel_enable,pattern_size};
        for(t=1;t<5;t=t+1) controls[t]<=controls[t-1];
        timing[0]<=geometry_timing;
        for(t=1;t<3;t=t+1) timing[t]<=timing[t-1];
    end
    assign {gx,gy,gc,ghb,gvb,ghs,gvs,gd,gstart,gfield,gp,gl,gs,gi,gb,gchannels,gsize}=controls[4];
    vtg_geometry_pipe geometry (.clk(clk),.x(raw_x),.y(raw_y),.native_size(pattern_size),
        .circle_white(cwhite),.mono_inner(minner),.mono_ring(mring),
        .wedge_inside(winside),.wedge_grating(wgrating));
    vtg_patterns #(.PIPELINED(1),.USE_EXTERNAL_GEOMETRY(1)) patterns (
        .clk(clk),.native_size(gsize),.x(gx),.y(gy),.active(gd),.pattern(gp),
        .level_percent(gl),.setup_75(gs),.invert(gi),.raster_border(gb),.channel_enable(gchannels),
        .geo_circle_white(cwhite),.geo_mono_inner(minner),.geo_mono_ring(mring),
        .geo_wedge_inside(winside),.geo_wedge_grating(wgrating),
        .red(raw_red),.green(raw_green),.blue(raw_blue));
    assign rendered={timing[2][31:8],raw_red,raw_green,raw_blue,timing[2][7:0]};
end endgenerate

// This is a streaming register pipeline, not an image store. Every transport
// clock advances one aligned RGB/timing packet. Retiming can distribute these
// registers through the arithmetic at 128.52 MHz without changing pixels.
generate
    if (PIPELINE_STAGES == 0) begin : unpipelined
        assign {x, y, red, green, blue, ce_pix, hblank, vblank, hsync, vsync,
            de, frame_start, field} = rendered;
    end else begin : streaming
        // Keep discrete registers available to the fitter's retiming pass.
        localparam integer OUTPUT_STAGES=PIPELINE_STAGES-8;
        (* altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *)
        reg [55:0] pixels [0:OUTPUT_STAGES-1];
        reg [PIPELINE_STAGES-1:0] valid = 0;
        integer stage;
        always @(posedge clk) begin
            pixels[0] <= rendered;
            for (stage=1; stage<OUTPUT_STAGES; stage=stage+1)
                pixels[stage] <= pixels[stage-1];
            if (reset) valid <= 0;
            else valid <= (valid << 1) | {{(PIPELINE_STAGES-1){1'b0}},1'b1};
        end
        wire pixel_valid = valid[PIPELINE_STAGES-1] && !reset;
        assign {x, y, red, green, blue, ce_pix, hblank, vblank, hsync, vsync,
            de, frame_start, field} = pixel_valid ? pixels[OUTPUT_STAGES-1] :
            {48'd0, 8'b01111000};
    end
endgenerate

endmodule
