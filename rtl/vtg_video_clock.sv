// SPDX-License-Identifier: GPL-2.0-or-later
`timescale 1ns/1ps
// A direct PLL output is required by the framework's clock-select primitives.
// Change its frequency under video reset; the management clock remains 27 MHz.
module vtg_video_clock (
    input wire refclk, clk_sd, reset, select_hd,
    output wire clk_video, locked
);
    wire raw_locked, cfg_wait;
    wire [63:0] to_pll, from_pll;
    reg [2:0] state = 0;
    reg target_hd = 0, valid = 0;
    reg [6:0] settle = 0;
    reg [1:0] lock_sync = 0;
    reg [5:0] address;
    reg [31:0] data;
    wire write = (state >= 1) && (state <= 4);
    // AN 661: M/N/C low bits hold low count, high bits hold high count;
    // bit17 enables odd division. K is the fractional M numerator over 2^32.
    // SD: 50 * (13 + 0.5) / 25 = 27 MHz (675 MHz VCO).
    // HD: 50 * (12 + 0.852) / 5 = 128.52 MHz (642.6 MHz VCO).
    always @* begin
        address = 0;
        data = 0;
        case (state)
            1: begin address=4; data=target_hd ? 32'h00000606 : 32'h00020706; end
            2: begin address=7; data=target_hd ? 32'd3659312136 : 32'h80000000; end
            3: begin address=5; data=target_hd ? 32'h00020302 : 32'h00020d0c; end
            4: begin address=2; data=1; end
            default: begin end
        endcase
    end
    always @(posedge clk_sd) begin
        lock_sync <= {lock_sync[0], raw_locked};
        if (reset) begin state<=0; valid<=0; target_hd<=0; settle<=0; end
        else case (state)
            0: if (!valid || target_hd != select_hd) begin
                target_hd <= select_hd;
                valid <= 0;
                state <= 1;
            end
            1,2,3: if (!cfg_wait) state <= state + 3'd1;
            4: if (!cfg_wait) begin state<=5; settle<=127; end
            5: if (settle != 0) settle<=settle-1'b1; else state<=6;
            6: if (!cfg_wait && lock_sync[1]) begin state<=0; valid<=1; end
            default: state<=0;
        endcase
    end
    assign locked = valid && lock_sync[1] && (target_hd == select_hd) && !reset;
    // The existing framework's reconfiguration IP is reused without editing sys/.
    pll_cfg_hdmi cfg (.mgmt_clk(clk_sd), .mgmt_reset(reset),
        .mgmt_waitrequest(cfg_wait), .mgmt_write(write),
        .mgmt_address(address), .mgmt_writedata(data),
        .reconfig_to_pll(to_pll), .reconfig_from_pll(from_pll));
    // Initialize at the fastest rate so derive_pll_clocks checks 128.52 MHz.
    altera_pll #(
        .fractional_vco_multiplier("true"), .pll_fractional_cout(32),
        .pll_dsm_out_sel("1st_order"), .reference_clock_frequency("50.0 MHz"),
        .operation_mode("direct"), .number_of_clocks(1),
        .output_clock_frequency0("128.520000 MHz"),
        .phase_shift0("0 ps"), .duty_cycle0(50),
        .pll_type("Cyclone V"), .pll_subtype("Reconfigurable"),
        .m_cnt_hi_div(6), .m_cnt_lo_div(6),
        .n_cnt_hi_div(1), .n_cnt_lo_div(1),
        .m_cnt_bypass_en("false"), .n_cnt_bypass_en("true"),
        .m_cnt_odd_div_duty_en("false"), .n_cnt_odd_div_duty_en("false"),
        .c_cnt_hi_div0(3), .c_cnt_lo_div0(2),
        .c_cnt_prst0(1), .c_cnt_ph_mux_prst0(0),
        .c_cnt_in_src0("ph_mux_clk"), .c_cnt_bypass_en0("false"),
        .c_cnt_odd_div_duty_en0("true"), .pll_vco_div(1),
        .pll_cp_current(20), .pll_bwctrl(4000),
        .pll_output_clk_frequency("642.600000 MHz"),
        .pll_fractional_division("3659312136"),
        .mimic_fbclk_type("gclk"), .pll_fbclk_mux_1("glb"),
        .pll_fbclk_mux_2("m_cnt"), .pll_m_cnt_in_src("ph_mux_clk"),
        .pll_slf_rst("true")
    ) video_pll (.refclk(refclk), .rst(1'b0), .outclk(clk_video),
        .locked(raw_locked), .fboutclk(), .fbclk(1'b0),
        .reconfig_to_pll(to_pll), .reconfig_from_pll(from_pll));
endmodule
