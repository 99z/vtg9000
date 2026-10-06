`timescale 1ns/1ps

module tb_vtg_top;
	reg clk = 0, reset = 1;
	reg [127:0] osd = 0;
	reg native_hs = 1, native_vs = 1;
	wire hs, vs;
	integer i, h, v, selection;
    reg old_vmode;
    realtime t0, period_ns;
    task choose_mode(input integer choice, input integer expected_mode);
        begin
            @(negedge dut.clk_pix);
            old_vmode = dut.new_vmode;
            osd[27:25] = 3'(choice);
            repeat (4) @(negedge dut.clk_pix);
            if (!dut.video_reset || dut.VGA_DE) $fatal(1,"switch failed to blank");
            if (dut.new_vmode === old_vmode) $fatal(1,"mode notification missing");
            wait (!dut.video_reset);
            repeat (dut.core.PIPELINE_STAGES+4) @(negedge dut.clk_video);
            if (dut.core.video_mode !== 3'(expected_mode)) $fatal(1,"resolution did not reach raster");
            if (dut.status_in !== osd) $fatal(1,"resolution lost in control writeback");
            @(posedge dut.clk_video); t0=$realtime;
            @(posedge dut.clk_video); period_ns=$realtime-t0;
            if (expected_mode>=3) begin
                if (period_ns<7.778 || period_ns>7.783) $fatal(1,"HD clock not selected");
            end else if (period_ns<37.034 || period_ns>37.041) $fatal(1,"SD clock not selected");
            for (selection=0;selection<64;selection=selection+1) begin
                @(negedge dut.clk_video);
                if (expected_mode==3 || expected_mode<2) begin
                    if (dut.ce_pix !== dut.core.sample_phase) $fatal(1,"half-rate mode CE");
                end else if (!dut.ce_pix) $fatal(1,"full-rate mode lost a pixel clock");
                if (expected_mode>=2 && dut.field) $fatal(1,"progressive field parity");
            end
        end
    endtask
	initial begin #1_000_000; $fatal(1,"video clock switching timeout"); end
	always #10 clk = ~clk;
	emu dut (.CLK_50M(clk), .RESET(reset), .VGA_HS(hs), .VGA_VS(vs),
		.HDMI_WIDTH(12'd0), .HDMI_HEIGHT(12'd0), .CLK_AUDIO(clk),
		.SD_MISO(1'b0), .SD_CD(1'b0), .DDRAM_BUSY(1'b0), .DDRAM_DOUT(64'd0),
		.DDRAM_DOUT_READY(1'b0), .UART_CTS(1'b0), .UART_RXD(1'b0),
		.UART_DSR(1'b0), .USER_IN(7'd0), .OSD_STATUS(1'b0));
	initial begin
		force dut.status = osd;
		force dut.hsync = native_hs;
		force dut.vsync = native_vs;
		osd[127:25] = '1;
		osd[16:14] = 3'b101;
		osd[17] = 1;
		osd[4:1] = 4'b1010;
		osd[23:19] = 17;
		osd[24] = 1;
		osd[18] = 1;
		osd[11:5] = 75;
		osd[13:12] = 3;
		repeat (3) @(negedge clk);
		reset = 0;
		wait (!dut.video_reset);
		repeat (dut.core.PIPELINE_STAGES+4) @(negedge dut.clk_video);
		if (dut.selected_pattern !== 17 || dut.core.pattern !== 17 || !dut.core.setup_75)
			$fatal(1, "new pattern/IRE status bits did not reach core");
		if (dut.status_in !== osd) $fatal(1, "OSD writeback moved unrelated setting bits");
		// The retired sync bit must have no influence on the framework inputs.
		for (i = 0; i < 2; i = i + 1) begin
			osd[17] = (i != 0);
			for (h = 0; h < 2; h = h + 1) begin
				native_hs = (h != 0);
				for (v = 0; v < 2; v = v + 1) begin
					native_vs = (v != 0); #1;
					if (hs !== (h != 0) || vs !== (v != 0))
						$fatal(1, "top level altered native H/V sync");
				end
			end
		end
		choose_mode(1,2);
        choose_mode(2,3);
        choose_mode(3,4);
        choose_mode(4,5);
        choose_mode(0,1);
        osd[18]=0;
        repeat (4) @(negedge dut.clk_pix);
        wait (!dut.video_reset);
        if (dut.core.video_mode !== 0) $fatal(1,"legacy default 480i lost");
        // Change the requested class while a reconfiguration is still in flight.
        choose_mode(3,4);
        @(negedge dut.clk_pix); osd[27:25]=0;
        repeat (3) @(negedge dut.clk_pix);
        osd[27:25]=4;
        repeat (5) @(negedge dut.clk_pix);
        if (!dut.video_reset) $fatal(1,"rapid mode change released video early");
        wait (!dut.video_reset);
        if (dut.core.video_mode!==5 || !dut.hd_locked) $fatal(1,"rapid request did not converge");
        old_vmode=dut.new_vmode;
        osd[18]=1;
        repeat (5) @(negedge dut.clk_pix);
        if (dut.new_vmode!==old_vmode || dut.video_reset) $fatal(1,"inactive format restarted HD");
        choose_mode(0,1);
        $display("PASS: OSD writeback, mode switches/rapid requests, PLL transactions/CE, separate sync");
		$finish;
	end
endmodule
