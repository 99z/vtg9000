`timescale 1ns/1ps

module hps_io #(
	parameter CONF_STR = ""
)(
	input wire clk_sys,
	inout wire [45:0] HPS_BUS,
	inout wire [35:0] EXT_BUS,
	inout wire [21:0] gamma_bus,
	output wire forced_scandoubler,
	output wire direct_video,
	input wire new_vmode,
	output wire [1:0] buttons,
	output wire [31:0] joystick_0,
	output wire [31:0] joystick_1,
	output wire [10:0] ps2_key,
	output wire [127:0] status,
	input wire [127:0] status_in,
	input wire status_set,
	input wire [15:0] status_menumask
);
	assign HPS_BUS = 'z;
	assign EXT_BUS = 'z;
	assign gamma_bus = 'z;
	assign forced_scandoubler = 1'b0;
	assign direct_video = 1'b0;
	assign buttons = 2'b00;
	assign joystick_0 = 32'd0;
	assign joystick_1 = 32'd0;
	assign ps2_key = 11'd0;
	assign status = 128'd0;
endmodule

module pll
(
	input wire refclk,
	input wire rst,
	output wire outclk_0,
	output wire locked
);
	reg sd_clock = 0;
	always #18.518519 sd_clock = ~sd_clock;
	assign outclk_0 = sd_clock;
	assign locked = ~rst;
endmodule

// Only clock routing/selection is modeled here. PLL frequency accuracy requires
// Quartus timing analysis and hardware measurement, not this behavioral stub.
module altera_pll #(parameter fractional_vco_multiplier="false",
    reference_clock_frequency="50.0 MHz", operation_mode="direct",
    number_of_clocks=1, output_clock_frequency0="128.52 MHz",
    phase_shift0="0 ps", duty_cycle0=50, pll_type="General", pll_subtype="General",
    pll_fractional_cout=32, pll_dsm_out_sel="1st_order",
    m_cnt_hi_div=6, m_cnt_lo_div=6, n_cnt_hi_div=1, n_cnt_lo_div=1,
    m_cnt_bypass_en="false", n_cnt_bypass_en="true",
    m_cnt_odd_div_duty_en="false", n_cnt_odd_div_duty_en="false",
    c_cnt_hi_div0=3, c_cnt_lo_div0=2, c_cnt_prst0=1, c_cnt_ph_mux_prst0=0,
    c_cnt_in_src0="ph_mux_clk", c_cnt_bypass_en0="false", c_cnt_odd_div_duty_en0="true",
    pll_vco_div=1, pll_cp_current=20, pll_bwctrl=4000,
    pll_output_clk_frequency="642.6 MHz", pll_fractional_division="3659312136",
    mimic_fbclk_type="none", pll_fbclk_mux_1="glb", pll_fbclk_mux_2="m_cnt",
    pll_m_cnt_in_src="ph_mux_clk", pll_slf_rst="true")
    (input wire refclk, rst, fbclk, input wire [63:0] reconfig_to_pll,
     output wire [63:0] reconfig_from_pll, output wire outclk, locked, fboutclk);
    reg video_clock = 0;
    always begin
        #(reconfig_to_pll[0] ? 3.890445 : 18.518519) video_clock = ~video_clock;
    end
    assign outclk = video_clock;
    assign locked = ~rst;
    assign fboutclk = 0;
    assign reconfig_from_pll = 64'd0;
endmodule
// Transaction model with backpressure. It checks the M/K/C register sequence
// and updates the modeled frequency only after a complete START transaction.
module pll_cfg_hdmi (
    input wire mgmt_clk, mgmt_reset, mgmt_write,
    input wire [5:0] mgmt_address, input wire [31:0] mgmt_writedata,
    output wire mgmt_waitrequest, output reg [63:0] reconfig_to_pll = 0,
    input wire [63:0] reconfig_from_pll
);
    reg [3:0] stall = 3;
    reg [2:0] step = 0;
    reg hd = 0;
    assign mgmt_waitrequest = stall != 0;
    always @(posedge mgmt_clk) begin
        if (mgmt_reset) begin stall<=3; step<=0; end
        else if (stall != 0) stall<=stall-1'b1;
        else if (mgmt_write) begin
            case (step)
                0: begin
                    if (mgmt_address!=4) $fatal(1,"PLL expected M write");
                    hd <= mgmt_writedata==32'h606;
                    if (mgmt_writedata!=32'h606 && mgmt_writedata!=32'h20706) $fatal(1,"PLL M value");
                end
                1: if (mgmt_address!=7 || mgmt_writedata!=(hd ? 32'd3659312136 : 32'h80000000)) $fatal(1,"PLL fractional value");
                2: if (mgmt_address!=5 || mgmt_writedata!=(hd ? 32'h20302 : 32'h20d0c)) $fatal(1,"PLL C value");
                3: begin
                    if (mgmt_address!=2 || mgmt_writedata!=1) $fatal(1,"PLL expected START");
                    reconfig_to_pll <= {63'd0, hd};
                end
                default: $fatal(1,"PLL unexpected write");
            endcase
            step <= (step==3) ? 3'd0 : step+1'b1;
            stall <= 3;
        end
    end
endmodule
