`timescale 1ns/1ps
module tb_vtg_native_patterns;
    reg [1:0] native_size = 0;
    reg [11:0] x=0, y=0;
    reg active=1, setup_75=0, invert=0, raster_border=0;
    reg [4:0] pattern=0;
    reg [6:0] level_percent=100;
    reg [2:0] channel_enable=7;
    wire [7:0] red, green, blue;
    integer s, w, h, n, p, last;
    vtg_patterns dut (.clk(1'b0), .geo_circle_white(1'b0), .geo_mono_inner(1'b0), .geo_mono_ring(1'b0),
        .geo_wedge_inside(1'b0), .geo_wedge_grating(1'b0), .*);
    task gray(input integer expected);
        begin
            #1;
            if (red!==8'(expected) || green!==8'(expected) || blue!==8'(expected))
                $fatal(1,"size %0d pattern %0d at %0d,%0d: expected gray %0d, got %0d/%0d/%0d",s,pattern,x,y,expected,red,green,blue);
        end
    endtask
    initial begin
        for (s=0;s<3;s=s+1) begin
            native_size=2'(s);
            w=(s==2)?1360:(s==1)?916:720;
            h=(s==2)?1080:(s==1)?720:480;
            y=12'(h/2);
            // Exactly one native pixel per alternating stripe, at every column.
            pattern=5;
            for(n=0;n<w;n=n+1) begin x=12'(n); gray((n%2)?0:255); end
            // Ramp is monotonic and reaches both endpoint codes.
            pattern=4; last=0;
            for(n=0;n<w;n=n+1) begin
                x=12'(n); #1;
                if (red<last || green!==red || blue!==red) $fatal(1,"native ramp reversed");
                last=red;
            end
            if (last!=255) $fatal(1,"ramp did not reach white");
            x=0; gray(0);
            pattern=6; x=12'(w/2); y=12'(h/2); gray(255);
            x=12'(w/8); gray(0);
            raster_border=1; x=12'(w-1); gray(255); raster_border=0;
            pattern=17; x=12'(w/2); y=12'(h/2); gray(255);
            // Native geometry must span the active image, including its last edges.
            pattern=2; x=12'(w-1); y=12'(h/8); gray(255);
            x=12'(w/8+3); y=12'(h-1); gray(255);
            pattern=0; x=0; y=0; gray(255);
            y=12'(h-1); gray(0);
            // Both grayscale rows cover all 16 exact levels at every column.
            pattern=3;
            for(n=0;n<w;n=n+1) begin
                x=12'(n); y=0; gray(255-(n*16/w)*17);
                y=12'(h-1); gray((n*16/w)*17);
            end
            pattern=8; x=12'(w/2); y=12'(h*90/480); gray(255);
            pattern=10; x=12'(w/8); y=12'(h/8); gray(255);
            x=12'(w*3/8); gray(0);
            pattern=12; x=12'(w*100/720); y=12'(h*100/480); gray(128);
            pattern=13; x=0; y=0; gray(191);
            pattern=14; gray(255);
            for(p=9;p<=16;p=p+1) begin
                if (p==11 || p==15 || p==16) begin
                    pattern=5'(p); x=12'(w/2); y=12'(h/2-3); gray(255);
                end
            end
            pattern=9; y=12'(h/4);
            // Band five has a two-native-pixel period at every size.
            x=12'(600*w/720); gray(0); x=x+1; gray(255);
            // All patterns, including nonzero pedestal, must blank to zero.
            setup_75=1; active=0;
            for(p=0;p<18;p=p+1) begin pattern=5'(p); gray(0); end
            setup_75=0; active=1;
            $display("PASS: native patterns %0dx%0d, pixel spacing, ramp, window, border, chart, blanking",w,h);
        end
        $finish;
    end
endmodule
