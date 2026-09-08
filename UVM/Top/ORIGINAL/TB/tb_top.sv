`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import dut_pkg::*;

module tb_top;
    // Reduce timing parameters to speed up two-board integration tests.
	my_report_server svr;
	
	initial begin
		$fsdbDumpfile("../SIM/sim/wave.fsdb");
		if ($test$plusargs("TEST_MODE=AUTH_SUCCESS") ||
		    $test$plusargs("TEST_MODE=AUTH_LOCKOUT")) begin
			$fsdbDumpvars(1, tb_top);
			$fsdbDumpvars(0, tb_top.u_board1.U_AUTH_PATH);
			$fsdbDumpvars(0, tb_top.u_board1.U_UART_PACKET_CONTROLLER);
			$fsdbDumpvars(0, tb_top.u_board2.U_UART_LINK);
		end else begin
			$fsdbDumpvars(0, tb_top);
			$fsdbDumpMDA(0, tb_top);
		end
		svr = new();
		my_report_server::set_server(svr);
	end	
	
    localparam int SIM_CLK_FREQ_HZ = 1_000_000;
    localparam int BAUD_RATE       = 115_200;
    localparam int I2C_FREQ_HZ     = 100_000;

    logic clk   = 1'b0;
    logic pclk1 = 1'b0;
    logic pclk2 = 1'b0;
    logic rst_n = 1'b0;

    uart_if #(.CLK_FREQ_HZ(SIM_CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE))
        board1_uart_vif(clk);
    uart_if #(.CLK_FREQ_HZ(SIM_CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE))
        board2_uart_vif(clk);
    sccb_if board1_sccb_vif();
    sccb_if board2_sccb_vif();
    camera_if board1_camera_vif(pclk1);
    camera_if board2_camera_vif(pclk2);
    control_if board1_control_vif(clk);
    vga_if board1_vga_vif(clk, rst_n);
    vga_if board2_vga_vif(clk, rst_n);

    // Cross-connect the UART link while observing both endpoints.
    assign board1_uart_vif.peer_tx = board2_uart_vif.tx;
    assign board2_uart_vif.peer_tx = board1_uart_vif.tx;

    wire board1_xclk;
    wire board1_alarm;
    wire board1_setup_busy;
    wire board1_setup_done;
    wire board1_setup_error;
    wire [6:0] board1_sccb_write_count;
    wire board1_marker_valid;
    wire board1_grid_valid;
    wire [3:0] board1_grid_id;
    wire board1_grid_enter_pulse;
    wire board1_h_sync;
    wire board1_v_sync;
    wire [3:0] board1_red;
    wire [3:0] board1_green;
    wire [3:0] board1_blue;

    wire board2_xclk;
    wire board2_setup_busy;
    wire board2_setup_done;
    wire board2_setup_error;
    wire [6:0] board2_sccb_write_count;
    wire board2_unlock_en;
    wire board2_h_sync;
    wire board2_v_sync;
    wire [3:0] board2_red;
    wire [3:0] board2_green;
    wire [3:0] board2_blue;

    assign board1_vga_vif.h_sync = board1_h_sync;
    assign board1_vga_vif.v_sync = board1_v_sync;
    assign board1_vga_vif.rgb = {board1_red, board1_green, board1_blue};
    assign board2_vga_vif.h_sync = board2_h_sync;
    assign board2_vga_vif.v_sync = board2_v_sync;
    assign board2_vga_vif.rgb = {board2_red, board2_green, board2_blue};
    assign board2_vga_vif.de          = u_board2.U_VIDEO_PATH.U_VGA_CAM.de;
    assign board2_vga_vif.x_pixel     = u_board2.U_VIDEO_PATH.U_VGA_CAM.x_pixel;
    assign board2_vga_vif.y_pixel     = u_board2.U_VIDEO_PATH.U_VGA_CAM.y_pixel;
    assign board2_vga_vif.source_addr = u_board2.U_VIDEO_PATH.U_VGA_CAM.rAddr;
    assign board2_vga_vif.source_data = u_board2.U_VIDEO_PATH.U_VGA_CAM.rData;
    assign board2_vga_vif.pixel_tick  = u_board2.U_VIDEO_PATH.U_VGA_CAM.U_VGA_DEC.pclk;
    assign board2_vga_vif.gaussian_rgb = u_board2.U_VIDEO_PATH.gauss_rgb;
    assign board2_vga_vif.unlock_state = board2_unlock_en;
    assign board2_vga_vif.zoom_en      = u_board2.zoom_en;
    assign board2_vga_vif.zoom_in      = u_board2.U_VIDEO_PATH.U_VGA_CAM.U_READER_UPSCALE.zoom_in;
    assign board1_vga_vif.de          = 1'b0;
    assign board1_vga_vif.x_pixel     = '0;
    assign board1_vga_vif.y_pixel     = '0;
    assign board1_vga_vif.source_addr = '0;
    assign board1_vga_vif.source_data = '0;
    assign board1_vga_vif.pixel_tick  = 1'b0;
    assign board1_vga_vif.gaussian_rgb = '0;
    assign board1_vga_vif.unlock_state = u_board1.unlock_state;
    assign board1_vga_vif.zoom_en      = 1'b0;
    assign board1_vga_vif.zoom_in      = 2'b00;
    assign board1_vga_vif.unlock_fail  = u_board1.unlock_fail;
    assign board1_vga_vif.alarm        = board1_alarm;
    assign board1_vga_vif.grid_id      = board1_grid_id;
    assign board1_vga_vif.grid_enter_pulse = board1_grid_enter_pulse;
    assign board1_vga_vif.pattern_index = u_board1.pattern_index;
    assign board1_vga_vif.fail_count   = u_board1.U_CONTROL_UNIT.fail_count_q;
    assign board1_vga_vif.control_state = u_board1.U_CONTROL_UNIT.c_state;
    assign board2_vga_vif.unlock_fail  = 1'b0;
    assign board2_vga_vif.alarm        = 1'b0;
    assign board2_vga_vif.grid_id      = 4'b0;
    assign board2_vga_vif.grid_enter_pulse = 1'b0;
    assign board2_vga_vif.pattern_index = 3'b0;
    assign board2_vga_vif.fail_count   = 2'b0;
    assign board2_vga_vif.control_state = 2'b0;
    assign board1_vga_vif.effect_sel   = 1'b0;
    assign board1_vga_vif.button_pulse = {u_board1.btn_U_pulse,u_board1.btn_D_pulse,u_board1.btn_R_pulse,u_board1.btn_L_pulse};
    assign board1_vga_vif.uart_rx_data = u_board1.uart_rx_data;
    assign board1_vga_vif.uart_rx_done = u_board1.uart_rx_done;
    assign board1_vga_vif.uart_tx_data = u_board1.uart_tx_data;
    assign board1_vga_vif.uart_tx_start = u_board1.uart_tx_start;
    assign board1_vga_vif.timeout_done = 1'b0;
    assign board2_vga_vif.effect_sel   = u_board2.effect_sel;
    assign board2_vga_vif.button_pulse = {u_board2.btn_u_pulse,u_board2.btn_d,u_board2.btn_r,u_board2.btn_l};
    assign board2_vga_vif.uart_rx_data = u_board2.U_UART_LINK.rx_data;
    assign board2_vga_vif.uart_rx_done = u_board2.U_UART_LINK.rx_done;
    assign board2_vga_vif.uart_tx_data = u_board2.U_UART_LINK.tx_data;
    assign board2_vga_vif.uart_tx_start = u_board2.U_UART_LINK.tx_start;
    assign board2_vga_vif.timeout_done = u_board2.U_UART_LINK.done_10s;

    // SCCB configuration counts exposed in waveforms.
    assign board1_sccb_write_count = board1_sccb_vif.write_count;
    assign board2_sccb_write_count = board2_sccb_vif.write_count;

    system_top #(
        .CLK_FREQ_HZ    (SIM_CLK_FREQ_HZ),
        .I2C_FREQ_HZ    (I2C_FREQ_HZ),
        .POWERUP_DELAY_MS(1),
        .STABLE_FRAMES  (1)
    ) u_board1 (
        .clk(clk),
        .pclk(board1_camera_vif.pclk),
        .rst_n(rst_n),
        .btn_R(board1_control_vif.btn_R),
        .btn_L(board1_control_vif.btn_L),
        .btn_D(board1_control_vif.btn_D),
        .btn_U(board1_control_vif.btn_U),
        .auth_sw(board1_control_vif.auth_sw),
        .zoom_en(board1_control_vif.zoom_en),
        .effect_en(board1_control_vif.effect_en),
        .uart_rx(board1_uart_vif.rx),
        .uart_tx(board1_uart_vif.tx),
        .alram(board1_alarm),
        .cam_href(board1_camera_vif.href),
        .cam_vsync(board1_camera_vif.vsync),
        .cam_data(board1_camera_vif.data),
        .xclk(board1_xclk),
        .cam_scl(board1_sccb_vif.cam_scl),
        .cam_sda(board1_sccb_vif.cam_sda),
        .o_setup_busy(board1_setup_busy),
        .o_setup_done(board1_setup_done),
        .o_setup_error(board1_setup_error),
        .o_marker_valid(board1_marker_valid),
        .o_grid_valid(board1_grid_valid),
        .o_grid_id(board1_grid_id),
        .o_grid_enter_pulse(board1_grid_enter_pulse),
        .h_sync(board1_h_sync),
        .v_sync(board1_v_sync),
        .port_red(board1_red),
        .port_green(board1_green),
        .port_blue(board1_blue)
    );

    OV7670_top #(
        .CLK_FREQ_HZ     (SIM_CLK_FREQ_HZ),
        .BAUD_RATE       (BAUD_RATE),
        .I2C_FREQ_HZ     (I2C_FREQ_HZ),
        .POWERUP_DELAY_MS(1)
    ) u_board2 (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(board2_uart_vif.rx),
        .uart_tx(board2_uart_vif.tx),
        .pclk(board2_camera_vif.pclk),
        .cam_href(board2_camera_vif.href),
        .cam_vsync(board2_camera_vif.vsync),
        .cam_data(board2_camera_vif.data),
        .xclk(board2_xclk),
        .setup_busy(board2_setup_busy),
        .setup_done(board2_setup_done),
        .setup_error(board2_setup_error),
        .cam_scl(board2_sccb_vif.cam_scl),
        .cam_sda(board2_sccb_vif.cam_sda),
        .unlock_en(board2_unlock_en),
        .h_sync(board2_h_sync),
        .v_sync(board2_v_sync),
        .port_red(board2_red),
        .port_green(board2_green),
        .port_blue(board2_blue)
    );

    always #5  clk   = ~clk;
    always #20 pclk1 = ~pclk1;
    always #20 pclk2 = ~pclk2;

    initial begin
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual sccb_if)::set( null, "uvm_test_top.env.board1_agent.*", "sccb_vif", board1_sccb_vif);
        uvm_config_db#(virtual sccb_if)::set( null, "uvm_test_top.env.board2_agent.*", "sccb_vif", board2_sccb_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.board1_agent.*", "uart_vif", board1_uart_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.board2_agent.*", "uart_vif", board2_uart_vif);
        uvm_config_db#(virtual camera_if)::set(null, "uvm_test_top.env.board1_agent.*", "camera_vif", board1_camera_vif);
        uvm_config_db#(virtual camera_if)::set(null, "uvm_test_top.env.board2_agent.*", "camera_vif", board2_camera_vif);
        uvm_config_db#(virtual control_if)::set(null, "uvm_test_top.env.board1_agent.*", "control_vif", board1_control_vif);
        uvm_config_db#(virtual vga_if)::set(null, "uvm_test_top", "board1_vga_vif", board1_vga_vif);
        uvm_config_db#(virtual vga_if)::set(null, "uvm_test_top", "board2_vga_vif", board2_vga_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top", "board2_uart_vif", board2_uart_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.auth_scb", "uart1_vif", board1_uart_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.auth_scb", "uart2_vif", board2_uart_vif);
        uvm_config_db#(virtual control_if)::set(null, "uvm_test_top.env.auth_scb", "control_vif", board1_control_vif);
        uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top.env.auth_cov", "uart2_vif", board2_uart_vif);
        uvm_config_db#(virtual control_if)::set(null, "uvm_test_top.env.auth_cov", "control_vif", board1_control_vif);
        uvm_config_db#(virtual vga_if)::set(null, "uvm_test_top.env.board2_scb", "vga_vif", board2_vga_vif);
        uvm_config_db#(bit)::set(null, "uvm_test_top.env.board2_scb", "check_video",
            !($test$plusargs("TEST_MODE=AUTH_SUCCESS") ||
              $test$plusargs("TEST_MODE=AUTH_LOCKOUT")));
        run_test("Dut_test");
    end

    // Limit runtime to prevent hangs on missing responses.
    initial begin
        if ($test$plusargs("TEST_MODE=AUTH_SUCCESS") ||
            $test$plusargs("TEST_MODE=AUTH_LOCKOUT")) begin
            #10ms;
            $fatal(1, "AUTH test exceeded its 10 ms functional timeout");
        end
    end

    initial begin
        #250ms;
        $fatal;
    end
endmodule
