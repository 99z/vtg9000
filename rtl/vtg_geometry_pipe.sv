// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps
// Five explicit arithmetic stages; one native-coordinate sample each clock.
module vtg_geometry_pipe (
    input wire clk,
    input wire [11:0] x,y,
    input wire [1:0] native_size,
    output reg circle_white, mono_inner, mono_ring, wedge_inside, wedge_grating
);
    function automatic [11:0] hx(input integer v);
        case(native_size)
            1: hx=12'(v*916/720);
            2: hx=12'(v*1360/720);
            default: hx=12'(v);
        endcase
    endfunction
    function automatic [11:0] vy(input integer v);
        case(native_size)
            1: vy=12'(v*720/480);
            2: vy=12'(v*1080/480);
            default: vy=12'(v);
        endcase
    endfunction
    reg signed [12:0] dx1[0:2],dy1[0:2];
    reg [16:0] cx1,cy1,cx2,cy2;
    reg [25:0] sx2[0:2],sy2[0:2];
    reg [42:0] px3[0:2],py3[0:2];
    reg [43:0] radius4[0:4];
    wire [11:0] center_x=(native_size==1)?12'd458:(native_size==2)?12'd680:12'd360;
    wire signed [12:0] center_dx=$signed({1'b0,x})-$signed({1'b0,center_x});
    reg [12:0] fan_abs1,fan_y1;
    reg [22:0] fan_x_scale1;
    reg [19:0] fan_y_scale1;
    reg [31:0] fx2,fy2,fx3,fy3,fx4;
    reg [31:0] ray4[1:8];
    integer i;
    function automatic corner_ring(input [43:0] radius);
        corner_ring=radius>=44'd77137920 && radius<=44'd93063168;
    endfunction
    always @(posedge clk) begin
        // Differences and coefficients, all bounded explicitly.
        dx1[0]<=center_dx;
        dx1[1]<=$signed({1'b0,x})-$signed({1'b0,hx(45)});
        dx1[2]<=$signed({1'b0,x})-$signed({1'b0,hx(674)});
        dy1[0]<=$signed({1'b0,y})-$signed({1'b0,vy(240)});
        dy1[1]<=$signed({1'b0,y})-$signed({1'b0,vy(40)});
        dy1[2]<=$signed({1'b0,y})-$signed({1'b0,vy(439)});
        cx1<=(native_size==1)?17'(64'd64*1024*720*720/916/916):
             (native_size==2)?17'(64'd64*1024*720*720/1360/1360):17'd65536;
        cy1<=(native_size==1)?17'(64'd81*1024*480*480/720/720):
             (native_size==2)?17'(64'd81*1024*480*480/1080/1080):17'd82944;
        fan_abs1<=center_dx[12]?13'(-center_dx):13'(center_dx);
        fan_y1<={1'b0,y}-13'(vy(64));
        fan_x_scale1<=(native_size==1)?23'd4147200:(native_size==2)?23'd6220800:23'd2764800;
        fan_y_scale1<=(native_size==1)?20'd439680:(native_size==2)?20'd652800:20'd345600;
        // Squares and fan products.
        for(i=0;i<3;i=i+1) begin sx2[i]<=26'(dx1[i]*dx1[i]); sy2[i]<=26'(dy1[i]*dy1[i]); end
        cx2<=cx1;cy2<=cy1;
        fx2<=32'(fan_abs1*fan_x_scale1);fy2<=32'(fan_y1*fan_y_scale1);
        // Scale the squared distances. Products use 26+17 bits.
        for(i=0;i<3;i=i+1) begin px3[i]<=43'(sx2[i]*cx2);py3[i]<=43'(sy2[i]*cy2);end
        fx3<=fx2;fy3<=fy2;
        // Orthogonal sums and the constant-slope fan boundaries.
        radius4[0]<={1'b0,px3[0]}+{1'b0,py3[0]};
        radius4[1]<={1'b0,px3[1]}+{1'b0,py3[1]};
        radius4[2]<={1'b0,px3[2]}+{1'b0,py3[1]};
        radius4[3]<={1'b0,px3[1]}+{1'b0,py3[2]};
        radius4[4]<={1'b0,px3[2]}+{1'b0,py3[2]};
        fx4<=fx3;
        for(i=1;i<=8;i=i+1) ray4[i]<=fy3*32'(i);
        // Comparisons: direct native geometry, no coordinate resampling.
        circle_white<=(radius4[0]>=44'd3301171200 && radius4[0]<=44'd3334348800) ||
            corner_ring(radius4[1]) || corner_ring(radius4[2]) || corner_ring(radius4[3]) || corner_ring(radius4[4]);
        mono_inner<=radius4[0]<44'd3276800000;
        mono_ring<=radius4[0]>=44'd3276800000 && radius4[0]<=44'd3358720000;
        wedge_inside<=fx4<=ray4[8];
        wedge_grating<=fx4<ray4[1] || (fx4>=ray4[2] && fx4<ray4[3]) ||
            (fx4>=ray4[4] && fx4<ray4[5]) || (fx4>=ray4[6] && fx4<ray4[7]);
    end
endmodule
