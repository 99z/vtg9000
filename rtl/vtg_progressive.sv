// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps
// Native progressive modes. Totals are counts (reference tables use last+1).
module vtg_progressive (
    input wire clk, reset, ce,
    input wire [2:0] mode,
    output wire [11:0] x, y,
    output wire hblank, vblank, de, hsync, vsync, frame_start
);
    wire hd1080 = mode == 4;
    wire hd720 = (mode == 3) || (mode == 5);
    wire [11:0] width = hd1080 ? 12'd1360 : hd720 ? 12'd916 : 12'd720;
    wire [11:0] height = hd1080 ? 12'd1080 : hd720 ? 12'd720 : 12'd480;
    wire [11:0] ht = hd1080 ? 12'd1904 : hd720 ? 12'd1428 : 12'd858;
    wire [11:0] vt = hd1080 ? 12'd1125 : hd720 ? 12'd750 : 12'd525;
    wire [11:0] hs0 = hd1080 ? 12'd1600 : hd720 ? 12'd1108 : 12'd736;
    wire [11:0] hs1 = hd1080 ? 12'd1688 : hd720 ? 12'd1196 : 12'd798;
    wire [11:0] vs0 = hd1080 ? 12'd1088 : hd720 ? 12'd728 : 12'd489;
    wire [11:0] vs1 = hd1080 ? 12'd1093 : hd720 ? 12'd733 : 12'd495;
    reg [11:0] h_count = 0, v_count = 0;
    always @(posedge clk) begin
        if (reset) begin h_count <= 0; v_count <= 0; end
        else if (ce) begin
            if (h_count == ht - 12'd1) begin
                h_count <= 0;
                v_count <= (v_count == vt - 12'd1) ? 12'd0 : v_count + 12'd1;
            end else h_count <= h_count + 12'd1;
        end
    end
    assign x = h_count;
    assign y = v_count;
    assign hblank = h_count >= width;
    assign vblank = v_count >= height;
    assign de = ~(hblank | vblank);
    // Match reference HD negative sync; standard 480p is also negative.
    assign hsync = ~((h_count >= hs0) && (h_count < hs1));
    assign vsync = ~((v_count >= vs0) && (v_count < vs1));
    assign frame_start = ce && (h_count == 0) && (v_count == 0);
endmodule
