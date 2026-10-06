`timescale 1ns/1ps
module tb_vtg_modes;
    reg clk = 0, reset = 1, ce = 1;
    reg [2:0] mode = 2;
    wire [11:0] x, y;
    wire hblank, vblank, de, hsync, vsync, frame_start;
    always #5 clk = ~clk;
    vtg_progressive dut (.*);
    integer m, n, ht, vt, w, h, hs0, hs1, vs0, vs1;
    integer active_count, hs_count, vs_count;
    task check_mode(input integer id);
        begin
            mode = 3'(id);
            case (id)
                2: begin w=720; h=480; ht=858; vt=525; hs0=736; hs1=798; vs0=489; vs1=495; end
                4: begin w=1360; h=1080; ht=1904; vt=1125; hs0=1600; hs1=1688; vs0=1088; vs1=1093; end
                default: begin w=916; h=720; ht=1428; vt=750; hs0=1108; hs1=1196; vs0=728; vs1=733; end
            endcase
            reset = 1;
            repeat (2) @(negedge clk);
            reset = 0;
            active_count=0; hs_count=0; vs_count=0;
            // Two frames verify cadence and wrap with no accumulated drift.
            for (n=0; n<ht*vt*2; n=n+1) begin
                if (x !== 12'(n%ht) || y !== 12'((n/ht)%vt)) $fatal(1, "mode %0d raster %0d",id,n);
                if (de !== (x<w && y<h) || hblank !== (x>=w) || vblank !== (y>=h)) $fatal(1,"mode %0d blanking",id);
                if (hsync !== !(x>=hs0 && x<hs1) || vsync !== !(y>=vs0 && y<vs1)) $fatal(1,"mode %0d sync",id);
                if (frame_start !== (x==0 && y==0)) $fatal(1,"mode %0d frame origin",id);
                if (de) active_count=active_count+1;
                if (!hsync) hs_count=hs_count+1;
                if (!vsync) vs_count=vs_count+1;
                // Pause CE at an arbitrary pixel: the raster must hold.
                if (n==17) begin
                    ce=0; @(negedge clk);
                    if (x!==17 || y!==0) $fatal(1,"raster advanced without CE");
                    ce=1;
                end
                @(negedge clk);
            end
            if (x!==0 || y!==0 || !frame_start) $fatal(1,"mode %0d wrap",id);
            if (active_count!=w*h*2 || hs_count!=(hs1-hs0)*vt*2 || vs_count!=(vs1-vs0)*ht*2)
                $fatal(1,"mode %0d counts",id);
            $display("PASS: mode %0d native %0dx%0d, totals %0dx%0d, two frames",id,w,h,ht,vt);
        end
    endtask
    initial begin
        for (m=2;m<=5;m=m+1) check_mode(m);
        $finish;
    end
endmodule
