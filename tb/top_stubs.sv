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
	assign outclk_0 = refclk;
	assign locked = ~rst;
endmodule
