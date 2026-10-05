PATTERN_RTL := rtl/vtg_raster.sv rtl/vtg_patterns.sv rtl/vtg9000_core.sv
CONTROL_RTL := rtl/vtg_controls.sv
RTL := $(PATTERN_RTL) $(CONTROL_RTL)
BUILD_DIR := build

.PHONY: test lint lint-top frames verify-frames clean

test: $(BUILD_DIR)/tb_vtg9000_core $(BUILD_DIR)/tb_vtg_controls
	vvp $(BUILD_DIR)/tb_vtg9000_core
	vvp $(BUILD_DIR)/tb_vtg_controls

lint:
	verilator --lint-only --timing -Wall -Wno-fatal --top-module vtg9000_core $(PATTERN_RTL)
	verilator --lint-only --timing -Wall -Wno-fatal --top-module vtg_controls $(CONTROL_RTL)

lint-top:
	iverilog -g2012 -Wall -s emu -I. -Itb -o $(BUILD_DIR)/top_syntax \
		VTG9000.sv $(RTL) tb/top_stubs.sv

$(BUILD_DIR)/tb_vtg9000_core: $(PATTERN_RTL) tb/tb_vtg9000_core.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg9000_core -o $@ $^

$(BUILD_DIR)/tb_vtg_controls: $(CONTROL_RTL) tb/tb_vtg_controls.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_controls -o $@ $^

$(BUILD_DIR)/tb_frame: $(PATTERN_RTL) tb/tb_frame.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_frame -o $@ $^

frames: $(BUILD_DIR)/tb_frame
	mkdir -p $(BUILD_DIR)/frames
	@for pattern in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do \
		vvp $< +PATTERN=$$pattern +LEVEL=100 +OUT=$(BUILD_DIR)/frames/pattern_$$pattern.ppm; \
	done
	sha256sum $(BUILD_DIR)/frames/*.ppm

verify-frames: frames
	sha256sum -c tb/golden_frames.sha256

clean:
	rm -rf $(BUILD_DIR)
