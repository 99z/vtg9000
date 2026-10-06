`timescale 1ns/1ps
// Compare the hardware stream against the established procedural raster/pixel
// generator. Check every timing and color bit under continuous pixel delivery,
// blanking, interlaced field boundaries, pattern changes and mode resets.
module tb_vtg_pipeline;
    localparam integer LATENCY = 32;
    reg clk=0, reset=1;
    reg [2:0] video_mode=0;
    reg [4:0] pattern=0;
    reg [6:0] level_percent=100;
    reg setup_75=0, invert=0, raster_border=0;
    reg [2:0] channel_enable=7;
    wire [55:0] reference_packet, actual_packet;
    wire [11:0] rx,ry,ax,ay;
    wire [7:0] rr,rg,rb,ar,ag,ab;
    wire rc,rhb,rvb,rhs,rvs,rd,rstart,rf;
    wire ac,ahb,avb,ahs,avs,ad,astart,af;
    always #5 clk=~clk;
    vtg9000_core reference (.clk(clk),.reset(reset),.video_mode(video_mode),
        .pattern(pattern),.level_percent(level_percent),.setup_75(setup_75),
        .invert(invert),.raster_border(raster_border),.channel_enable(channel_enable),
        .x(rx),.y(ry),.red(rr),.green(rg),.blue(rb),.ce_pix(rc),.hblank(rhb),
        .vblank(rvb),.hsync(rhs),.vsync(rvs),.de(rd),.frame_start(rstart),.field(rf));
    vtg9000_core #(.PIPELINE_STAGES(LATENCY)) dut (.clk(clk),.reset(reset),.video_mode(video_mode),
        .pattern(pattern),.level_percent(level_percent),.setup_75(setup_75),
        .invert(invert),.raster_border(raster_border),.channel_enable(channel_enable),
        .x(ax),.y(ay),.red(ar),.green(ag),.blue(ab),.ce_pix(ac),.hblank(ahb),
        .vblank(avb),.hsync(ahs),.vsync(avs),.de(ad),.frame_start(astart),.field(af));
    assign reference_packet={rx,ry,rr,rg,rb,rc,rhb,rvb,rhs,rvs,rd,rstart,rf};
    assign actual_packet={ax,ay,ar,ag,ab,ac,ahb,avb,ahs,avs,ad,astart,af};
    reg [55:0] history [0:LATENCY-1];
    reg [LATENCY-1:0] valid=0;
    reg [11:0] forced_h=0, forced_v=0;
    integer i,mode,p,k,w,h,px,py;
    integer comparisons=0;
    always @(posedge clk) begin
        // Capture the same pre-edge stream that the hardware registers sample.
        for(i=LATENCY-1;i>0;i=i-1) history[i]=history[i-1];
        history[0]=reference_packet;
        valid=(valid<<1)|{{(LATENCY-1){1'b0}},!reset};
        #2;
        if (reset || !valid[LATENCY-1]) begin
            if (actual_packet !== {48'd0,8'b01111000}) $fatal(1,"pipeline exposed invalid/startup pixels");
        end else begin
            if (actual_packet !== history[LATENCY-1])
                $fatal(1,"stream mismatch mode=%0d pattern=%0d x=%0d y=%0d actual=%h expected=%h",video_mode,pattern,ax,ay,actual_packet,history[LATENCY-1]);
            comparisons=comparisons+1;
        end
    end
    task jump(input integer hx,input integer vy);
        begin
            @(negedge clk); #1;
            forced_h=12'(hx); forced_v=12'(vy);
            force reference.raster.h_count=forced_h;
            force dut.raster.h_count=forced_h;
            force reference.raster.v_count=forced_v;
            force dut.raster.v_count=forced_v;
            force reference.progressive.h_count=forced_h;
            force dut.progressive.h_count=forced_h;
            force reference.progressive.v_count=forced_v;
            force dut.progressive.v_count=forced_v;
            @(negedge clk); #1;
            release reference.raster.h_count; release dut.raster.h_count;
            release reference.raster.v_count; release dut.raster.v_count;
            release reference.progressive.h_count; release dut.progressive.h_count;
            release reference.progressive.v_count; release dut.progressive.v_count;
        end
    endtask
    initial begin
        repeat (40) @(posedge clk);
        for(mode=0;mode<6;mode=mode+1) begin
            @(posedge clk); #1; reset=1; video_mode=3'(mode);
            repeat (40) @(posedge clk);
            #1; reset=0;
            // All 18 patterns, level/pedestal and channel changes in flight.
            for(p=0;p<18;p=p+1) begin
                @(posedge clk); #1;
                pattern=5'(p); setup_75=p[0]; invert=p[1]; raster_border=p[2];
                level_percent=7'(p*5); channel_enable=p[0]?3'b111:3'b101;
                jump(100,(mode<2)?18:100);
                repeat (100) @(posedge clk);
            end
            // Sample the geometry chart across its circle, wedge, gratings and edges.
            w=(mode==4)?1360:((mode==3 || mode==5)?916:720);
            h=(mode==4)?1080:((mode==3 || mode==5)?720:480);
            @(posedge clk); #1;
            pattern=17; invert=0; setup_75=0; raster_border=0; channel_enable=7;
            for(k=0;k<64;k=k+1) begin
                px=(k*113+45)%w; py=(k*71+64)%h;
                jump(px,(mode<2)?18+py/2:py);
                repeat (40) @(posedge clk);
            end
            // Jump near sync/line/frame boundaries; both field phases in 480i.
            jump(730,(mode<2)?18:100); repeat (300) @(posedge clk);
            if(mode==0) begin
                jump(400,262); repeat (300) @(posedge clk);
                jump(850,524); repeat (100) @(posedge clk);
            end
            repeat (40) @(posedge clk);
        end
        $display("PASS: streaming pipeline, %0d aligned RGB/CE/sync/field packets across all modes",comparisons);
        $finish;
    end
endmodule
