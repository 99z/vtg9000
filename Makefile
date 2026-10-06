PATTERN_RTL := rtl/vtg_geometry_pipe.sv rtl/vtg_progressive.sv rtl/vtg_raster.sv rtl/vtg_monoscope.sv rtl/vtg_patterns.sv rtl/vtg9000_core.sv
CONTROL_RTL := rtl/vtg_controls.sv
RTL := $(PATTERN_RTL) $(CONTROL_RTL) rtl/vtg_video_clock.sv
BUILD_DIR := build
PATTERN_IDS := 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17
FRAME_FILES := $(foreach id,$(PATTERN_IDS),$(BUILD_DIR)/frames/pattern_$(id).ppm $(BUILD_DIR)/frames/setup75_pattern_$(id).ppm)

.PHONY: test lint lint-top frames verify-frames check-build-tools clean

test: $(BUILD_DIR)/tb_vtg_pipeline $(BUILD_DIR)/tb_vtg_modes $(BUILD_DIR)/tb_vtg_native_patterns $(BUILD_DIR)/tb_vtg9000_core $(BUILD_DIR)/tb_vtg_controls $(BUILD_DIR)/tb_vtg_pattern_updates $(BUILD_DIR)/tb_vtg_top
	vvp $(BUILD_DIR)/tb_vtg_pipeline
	vvp $(BUILD_DIR)/tb_vtg_modes
	vvp $(BUILD_DIR)/tb_vtg_native_patterns
	vvp $(BUILD_DIR)/tb_vtg9000_core
	vvp $(BUILD_DIR)/tb_vtg_controls
	vvp $(BUILD_DIR)/tb_vtg_pattern_updates
	vvp $(BUILD_DIR)/tb_vtg_top

lint:
	verilator --lint-only --timing -Wall -Wno-fatal --top-module vtg9000_core $(PATTERN_RTL)
	verilator --lint-only --timing -Wall -Wno-fatal --top-module vtg_controls $(CONTROL_RTL)

lint-top:
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s emu -I. -Itb -o $(BUILD_DIR)/top_syntax \
		VTG9000.sv $(RTL) tb/top_stubs.sv

$(BUILD_DIR)/tb_vtg9000_core: $(PATTERN_RTL) tb/tb_vtg9000_core.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg9000_core -o $@ $^

$(BUILD_DIR)/tb_vtg_controls: $(CONTROL_RTL) tb/tb_vtg_controls.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_controls -o $@ $^

$(BUILD_DIR)/tb_vtg_pattern_updates: $(PATTERN_RTL) tb/tb_vtg_pattern_updates.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_pattern_updates -o $@ $^

$(BUILD_DIR)/tb_vtg_top: VTG9000.sv $(RTL) tb/top_stubs.sv tb/tb_vtg_top.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_top -I. -Itb -o $@ $^

$(BUILD_DIR)/tb_frame: $(PATTERN_RTL) tb/tb_frame.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_frame -o $@ $^

$(BUILD_DIR)/frames/pattern_%.ppm: $(BUILD_DIR)/tb_frame
	mkdir -p $(BUILD_DIR)/frames
	vvp $< +PATTERN=$* +LEVEL=100 +OUT=$@.tmp
	mv $@.tmp $@

$(BUILD_DIR)/frames/setup75_pattern_%.ppm: $(BUILD_DIR)/tb_frame
	mkdir -p $(BUILD_DIR)/frames
	vvp $< +PATTERN=$* +LEVEL=100 +SETUP=1 +OUT=$@.tmp
	mv $@.tmp $@

frames: $(FRAME_FILES)
	sha256sum $(BUILD_DIR)/frames/*.ppm

verify-frames: frames
	sha256sum -c tb/golden_frames.sha256

check-build-tools:
	python3 -m unittest discover -s tb -p 'test_build_tools.py' -v

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/tb_vtg_modes: rtl/vtg_progressive.sv tb/tb_vtg_modes.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_modes -o $@ $^

$(BUILD_DIR)/tb_vtg_native_patterns: rtl/vtg_patterns.sv rtl/vtg_monoscope.sv tb/tb_vtg_native_patterns.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_native_patterns -o $@ $^

$(BUILD_DIR)/tb_vtg_pipeline: $(PATTERN_RTL) tb/tb_vtg_pipeline.sv
	mkdir -p $(BUILD_DIR)
	iverilog -g2012 -Wall -s tb_vtg_pipeline -o $@ $^
