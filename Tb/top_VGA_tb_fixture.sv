`timescale 1ns / 1ps

// Shared fixture for top_VGA scenario testbenches.
module top_VGA_tb_fixture #(
    parameter integer CLK_FREQ_HZ        = 1_000_000,
    parameter integer BAUD_RATE          = 100_000,
    parameter integer DEBOUNCE_MS        = 1,
    parameter integer I2C_FREQ_HZ        = 100_000,
    parameter integer POWERUP_DELAY_MS   = 50
);

    localparam integer DEBOUNCE_CYCLES =
        (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    logic board1_btn_R     = 1'b0;
    logic board1_btn_L     = 1'b0;
    logic board1_btn_D     = 1'b0;
    logic board1_btn_U     = 1'b0;
    logic board1_auth_sw   = 1'b0;
    logic board1_zoom_en   = 1'b0;
    logic board1_effect_en = 1'b0;

    wire board1_uart_tx;
    wire board2_uart_tx;
    wire board1_alarm;
    wire board2_unlock_en;

    // VGA signals are connected explicitly so they are easy to add to Wave.
    wire       board1_h_sync;
    wire       board1_v_sync;
    wire [3:0] board1_red;
    wire [3:0] board1_green;
    wire [3:0] board1_blue;

    wire       board2_h_sync;
    wire       board2_v_sync;
    wire [3:0] board2_red;
    wire [3:0] board2_green;
    wire [3:0] board2_blue;

    tri board1_cam_sda;
    tri board2_cam_sda;

    always #5 clk = ~clk;

    top_VGA #(
        .CLK_FREQ_HZ       (CLK_FREQ_HZ),
        .BAUD_RATE         (BAUD_RATE),
        .BUTTON_DEBOUNCE_MS(DEBOUNCE_MS),
        .I2C_FREQ_HZ       (I2C_FREQ_HZ),
        .POWERUP_DELAY_MS  (POWERUP_DELAY_MS)
    ) DUT (
        .clk              (clk),
        .rst_n            (rst_n),

        .board1_btn_R     (board1_btn_R),
        .board1_btn_L     (board1_btn_L),
        .board1_btn_D     (board1_btn_D),
        .board1_btn_U     (board1_btn_U),
        .board1_auth_sw   (board1_auth_sw),
        .board1_zoom_en   (board1_zoom_en),
        .board1_effect_en (board1_effect_en),

        .board1_pclk      (1'b0),
        .board1_cam_href  (1'b0),
        .board1_cam_vsync (1'b0),
        .board1_cam_data  (8'h00),
        .board1_cam_sda   (board1_cam_sda),
        .board1_alarm     (board1_alarm),
        .board1_h_sync    (board1_h_sync),
        .board1_v_sync    (board1_v_sync),
        .board1_port_red  (board1_red),
        .board1_port_green(board1_green),
        .board1_port_blue (board1_blue),

        .board2_pclk      (1'b0),
        .board2_cam_href  (1'b0),
        .board2_cam_vsync (1'b0),
        .board2_cam_data  (8'h00),
        .board2_cam_sda   (board2_cam_sda),
        .board2_unlock_en (board2_unlock_en),
        .board2_h_sync    (board2_h_sync),
        .board2_v_sync    (board2_v_sync),
        .board2_port_red  (board2_red),
        .board2_port_green(board2_green),
        .board2_port_blue (board2_blue),

        .board1_uart_tx   (board1_uart_tx),
        .board2_uart_tx   (board2_uart_tx)
    );

    // Board 1 observation points.
    wire board1_btn_u_pulse = DUT.U_BOARD1_SYSTEM.btn_U_pulse;
    wire board1_btn_d_pulse = DUT.U_BOARD1_SYSTEM.btn_D_pulse;
    wire board1_btn_r_pulse = DUT.U_BOARD1_SYSTEM.btn_R_pulse;
    wire board1_btn_l_pulse = DUT.U_BOARD1_SYSTEM.btn_L_pulse;

    wire board1_tx_event_valid =
        DUT.U_BOARD1_SYSTEM.U_UART_PACKET_CONTROLLER.tx_event_valid;
    wire       board1_tx_start = DUT.U_BOARD1_SYSTEM.uart_tx_start;
    wire [7:0] board1_tx_data  = DUT.U_BOARD1_SYSTEM.uart_tx_data;
    wire       board1_tx_busy  = DUT.U_BOARD1_SYSTEM.uart_tx_busy;
    wire       board1_tx_done  = DUT.U_BOARD1_SYSTEM.uart_tx_done;

    wire       board1_rx_done = DUT.U_BOARD1_SYSTEM.uart_rx_done;
    wire [7:0] board1_rx_data = DUT.U_BOARD1_SYSTEM.uart_rx_data;
    wire       board1_unlock_state = DUT.U_BOARD1_SYSTEM.unlock_state;
    wire       board1_remote_relock = DUT.U_BOARD1_SYSTEM.remote_relock_pulse;

    // Board 2 observation points.
    wire       board2_rx_done = DUT.U_BOARD2_SYSTEM.U_UART_LINK.rx_done;
    wire [7:0] board2_rx_data = DUT.U_BOARD2_SYSTEM.U_UART_LINK.rx_data;
    wire       board2_btn_l_pulse = DUT.U_BOARD2_SYSTEM.U_UART_LINK.btn_l;
    wire       board2_btn_r_pulse = DUT.U_BOARD2_SYSTEM.U_UART_LINK.btn_r;
    wire       board2_btn_d_pulse = DUT.U_BOARD2_SYSTEM.U_UART_LINK.btn_d;
    wire       board2_btn_u_pulse =
        DUT.U_BOARD2_SYSTEM.U_UART_LINK.btn_u_pulse;
    wire       board2_zoom_en = DUT.U_BOARD2_SYSTEM.U_UART_LINK.zoom_en;
    wire       board2_effect_sel = DUT.U_BOARD2_SYSTEM.U_UART_LINK.effect_sel;

    // UART-only scenarios do not send camera pixels. Initialize only the
    // simulation framebuffers to black so unused video data does not appear
    // as X in the waveform. This does not modify the synthesizable RTL.
    task automatic init_video_black;
        integer pixel_index;
        begin
            for (pixel_index = 0; pixel_index < 320 * 240;
                 pixel_index = pixel_index + 1) begin
                DUT.U_BOARD1_SYSTEM.U_BOARD1_VIDEO_PATH.U_FRAMEBUFFER.mem[pixel_index]
                    = 16'h0000;
                DUT.U_BOARD2_SYSTEM.U_VIDEO_PATH.U_VGA_CAM.U_FRAMEBUFFER.mem[pixel_index]
                    = 16'h0000;
            end
        end
    endtask

    task automatic reset_dut;
        begin
            board1_btn_R     = 1'b0;
            board1_btn_L     = 1'b0;
            board1_btn_D     = 1'b0;
            board1_btn_U     = 1'b0;
            board1_auth_sw   = 1'b0;
            board1_zoom_en   = 1'b0;
            board1_effect_en = 1'b0;
            rst_n            = 1'b0;

            repeat (10) @(posedge clk);
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic press_btn_u;
        begin
            @(negedge clk);
            board1_btn_U = 1'b1;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
            @(negedge clk);
            board1_btn_U = 1'b0;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
        end
    endtask

    task automatic press_btn_d;
        begin
            @(negedge clk);
            board1_btn_D = 1'b1;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
            @(negedge clk);
            board1_btn_D = 1'b0;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
        end
    endtask

    task automatic press_btn_r;
        begin
            @(negedge clk);
            board1_btn_R = 1'b1;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
            @(negedge clk);
            board1_btn_R = 1'b0;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
        end
    endtask

    task automatic press_btn_l;
        begin
            @(negedge clk);
            board1_btn_L = 1'b1;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
            @(negedge clk);
            board1_btn_L = 1'b0;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
        end
    endtask

    task automatic force_board1_unlocked;
        begin
            // Force the control FSM state, not its derived output net. This
            // lets a later reset restore the state and output deterministically.
            force DUT.U_BOARD1_SYSTEM.U_CONTROL_UNIT.c_state = 2'd2;
        end
    endtask

    task automatic release_board1_unlock_force;
        begin
            release DUT.U_BOARD1_SYSTEM.U_CONTROL_UNIT.c_state;
        end
    endtask

endmodule
