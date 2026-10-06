derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# Fixed 27 MHz controls enter the independently reconfigured video PLL domain
# through two-register synchronizers. Constrain stages after the first normally.
set_false_path -to [get_registers {*|mode_meta* *|settings_meta*}]

# The separate video PLL has no guaranteed phase relationship to the other PLLs.
# Transfers use the existing framework's async FIFOs or explicit synchronizers.
# Paths wholly within the video domain retain their single-cycle requirements.
set_clock_groups -asynchronous \
    -group [get_clocks {*|video_clock|*}] \
    -group [get_clocks {*|pll|pll_inst|* pll_hdmi|* pll_audio|* spi_sck hdmi_sck *|h2f_user0_clk FPGA_CLK1_50 FPGA_CLK2_50 FPGA_CLK3_50}]
