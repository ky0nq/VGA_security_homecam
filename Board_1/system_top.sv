`timescale 1ns / 1ps

module system_top #(
    parameter integer IMG_WIDTH  = 320,
    parameter integer IMG_HEIGHT = 240,

    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ = 100_000,
    parameter integer POWERUP_DELAY_MS = 50,

    parameter logic [4:0] BLUE_B_MIN = 5'd20,
    parameter logic [5:0] BLUE_BR_MARGIN = 6'd10,
    parameter logic [5:0] BLUE_BG_MARGIN = 6'd10,

    parameter integer MIN_BLUE_PIXELS = 50,
    parameter integer STABLE_FRAMES   = 3,

    parameter integer ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT)
) (
    // =========================================================
    // Clock / Reset
    // =========================================================
    input logic clk,
    input logic pclk,
    input logic rst_n,

    // =========================================================
    // Button / SW
    // =========================================================
    input logic btn_R,
    input logic btn_L,
    input logic btn_D,
    input logic btn_U,    
    input logic auth_sw,    // sw[0]
    input logic zoom_en,    // sw[1]
    input logic effect_en,  // sw[2]

    // =========================================================
    // Uart Rx, Tx
    // =========================================================
    input  logic uart_rx, // JA1
    output logic uart_tx, // JA2

    // =========================================================
    // System Control Unit Interface
    // =========================================================
    output logic alram,

    // =========================================================
    // OV7670 Camera Interface
    // =========================================================
    input logic       cam_href,
    input logic       cam_vsync,
    input logic [7:0] cam_data,

    output logic xclk,
    output logic cam_scl,
    inout  wire  cam_sda,

    // =========================================================
    // Camera Setup Status
    // =========================================================
    output logic o_setup_busy,
    output logic o_setup_done,
    output logic o_setup_error,

    output logic       o_marker_valid,
    // =========================================================
    // Tracking Debug Interface
    // =========================================================
    output logic       o_grid_valid,
    output logic [3:0] o_grid_id,
    output logic       o_grid_enter_pulse,

    // =========================================================
    // Auth FSM Debug Interface
    // =========================================================
    //output logic [1:0] o_auth_state,
    //output logic [2:0] o_pattern_index,

    // =========================================================
    // Board 1 VGA Output
    // =========================================================
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    logic        auth_start;
    logic        pattern_clear;

    logic        unlock_pass;
    logic        unlock_fail;
    logic        auth_active;

    logic [11:0] board1_video_rgb;
    logic        vp_h_sync;
    logic        vp_v_sync;
    logic [11:0] ui_rgb;
    logic        board1_path_busy;

    logic                  frame_we;
    logic [ADDR_WIDTH-1:0] frame_waddr;
    logic [15:0]           frame_rgb565;

    logic                  path_clear_pclk;
    logic                  track_update_pulse;
    logic [8:0]            center_x;
    logic [7:0]            center_y;

    logic [1:0]            auth_state;
    logic [2:0]            pattern_index;

    // Uart
    logic       uart_tx_start;
    logic [7:0] uart_tx_data;
    logic       uart_tx_busy;
    logic       uart_tx_done;

    logic [7:0] uart_rx_data;
    logic       uart_rx_done;

    logic unlock_state;

    logic btn_U_pulse;
    logic btn_D_pulse;
    logic btn_R_pulse;
    logic btn_L_pulse;

    logic remote_relock_pulse;

assign remote_relock_pulse = uart_rx_done && (uart_rx_data == 8'h80);

    // =========================================================
    // Button_debounce
    // =========================================================

    btn_debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .DEBOUNCE_MS(10)
    ) U_BTN_U_DEBOUNCE (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_U),
        .btn_pulse (btn_U_pulse)
    );

    btn_debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .DEBOUNCE_MS(10)
    ) U_BTN_D_DEBOUNCE (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_D),
        .btn_pulse (btn_D_pulse)
    );

    btn_debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .DEBOUNCE_MS(10)
    ) U_BTN_R_DEBOUNCE (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_R),
        .btn_pulse (btn_R_pulse)
    );

    btn_debounce #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .DEBOUNCE_MS(10)
    ) U_BTN_L_DEBOUNCE (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_L),
        .btn_pulse (btn_L_pulse)
    );

    // =========================================================
    // Camera Front End
    // =========================================================
    camera_frontend #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),

        .CLK_FREQ_HZ     (CLK_FREQ_HZ),
        .I2C_FREQ_HZ     (I2C_FREQ_HZ),
        .POWERUP_DELAY_MS(POWERUP_DELAY_MS),

        .ADDR_WIDTH(ADDR_WIDTH)
    ) U_CAMERA_FRONTEND (
        .clk  (clk),
        .pclk (pclk),
        .rst_n(rst_n),

        // OV7670 Pixel Interface
        .cam_href (cam_href),
        .cam_vsync(cam_vsync),
        .cam_data (cam_data),

        // OV7670 Clock / SCCB
        .xclk   (xclk),
        .cam_scl(cam_scl),
        .cam_sda(cam_sda),

        // Camera Setup Status
        .o_setup_busy (o_setup_busy),
        .o_setup_done (o_setup_done),
        .o_setup_error(o_setup_error),

        // RGB565 Capture Output
        .o_frame_we    (frame_we),
        .o_frame_waddr (frame_waddr),
        .o_frame_rgb565(frame_rgb565)
    );

    // =========================================================
    // Auth Path
    // =========================================================
    auth_path #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),

        .BLUE_B_MIN    (BLUE_B_MIN),
        .BLUE_BR_MARGIN(BLUE_BR_MARGIN),
        .BLUE_BG_MARGIN(BLUE_BG_MARGIN),

        .MIN_BLUE_PIXELS(MIN_BLUE_PIXELS),
        .STABLE_FRAMES  (STABLE_FRAMES),

        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_AUTH_PATH (
        .clk  (clk),
        .pclk (pclk),
        .rst_n(rst_n),

        // System Control Interface
        .i_auth_start   (auth_start),
        .i_pattern_clear(pattern_clear),

        // Camera Front End Interface
        .i_cam_vsync   (cam_vsync),
        .i_frame_we    (frame_we),
        .i_frame_rgb565(frame_rgb565),

        // Auth Result
        .o_unlock_pass(unlock_pass),
        .o_unlock_fail(unlock_fail),
        .o_auth_active(auth_active),

        // Board 1 Video Path Interface
        .o_path_clear_pclk   (path_clear_pclk),
        .o_track_update_pulse(track_update_pulse),
        .o_marker_valid      (o_marker_valid),
        .o_center_x          (center_x),
        .o_center_y          (center_y),

        // Tracking Debug
        .o_grid_valid      (o_grid_valid),
        .o_grid_id         (o_grid_id),
        .o_grid_enter_pulse(o_grid_enter_pulse),

        // Auth FSM Debug
        .o_auth_state   (auth_state),
        .o_pattern_index(pattern_index)
    );



    board1_control_unit #(
        .CLK_FREQ_HZ    (CLK_FREQ_HZ),
        .LOCKOUT_SECONDS(60)
    ) U_BOARD1_CONTROL_UNIT (
        .clk  (clk),
        .rst_n(rst_n),

        // Basys3 SW0
        .i_auth_sw(auth_sw),

        .i_remote_relock(remote_relock_pulse),

        // Auth Path result
        .i_unlock_pass(unlock_pass),
        .i_unlock_fail(unlock_fail),

        // Auth Path
        .o_auth_start   (auth_start),
        .o_pattern_clear(pattern_clear),

        .o_unlock_state(unlock_state),

        // fail alram
        .o_alram(alram)
    );
    // =========================================================
    // Board 1 Video Path
    // =========================================================
    board1_video_path #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .ADDR_WIDTH(ADDR_WIDTH),

        // Grid
        .GRID_LINE_THICKNESS(2),
        .GRID_LINE_COLOR    (12'hFFF),

        // Tracking Path
        .PATH_SMOOTH_SHIFT     (2),
        .PATH_MOVE_MARGIN      (2),
        .PATH_MAX_JUMP         (80),
        .PATH_LINE_RADIUS      (1),
        .PATH_LOST_FRAME_MARGIN(2),
        .PATH_LINE_COLOR       (12'hFF0)
    ) U_BOARD1_VIDEO_PATH (
        .clk  (clk),
        .pclk (pclk),
        .rst_n(rst_n),

        // Camera Front End Interface
        .i_cam_vsync   (cam_vsync),
        .i_frame_we    (frame_we),
        .i_frame_waddr (frame_waddr),
        .i_frame_rgb565(frame_rgb565),

        // Auth Path Interface
        .i_auth_active    (auth_active),
        .i_path_clear_pclk(path_clear_pclk),

        .i_marker_valid(o_marker_valid),
        .i_center_x    (center_x),
        .i_center_y    (center_y),

        // VGA Output (routed through the UI overlay)
        .o_h_sync(vp_h_sync),
        .o_v_sync(vp_v_sync),
        .o_rgb   (board1_video_rgb),

        // Debug
        .o_path_busy(board1_path_busy)
    );


    // =========================================================
    // Uart
    // =========================================================
    uart_tx #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) U_UART_TX (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_start(uart_tx_start),
        .tx_data (uart_tx_data),
        .tx_busy (uart_tx_busy),
        .tx_done (uart_tx_done),
        .tx      (uart_tx)
    );

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE(115200)
    ) U_UART_RX (
        .clk    (clk),
        .rst_n  (rst_n),
        .rx     (uart_rx),
        .rx_data(uart_rx_data),
        .rx_done(uart_rx_done)
    );

    uart_packet_controller U_UART_PACKET_CONTROLLER (
        .clk  (clk),
        .rst_n(rst_n),

        .i_unlock_state(unlock_state),

        .i_btn_U_pulse(btn_U_pulse),
        .i_btn_D_pulse(btn_D_pulse),
        .i_btn_R_pulse(btn_R_pulse),
        .i_btn_L_pulse(btn_L_pulse),

        .i_effect_en(effect_en),
        .i_zoom_en  (zoom_en),

        .i_tx_busy(uart_tx_busy),
        .i_tx_done(uart_tx_done),

        .o_tx_start(uart_tx_start),
        .o_tx_data (uart_tx_data)
    );
    // =========================================================
    // HUD UI : Header + State Badge + Pattern/Grid/Marker Status
    // =========================================================
    ui_frame_wrapper U_UI (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_h_sync       (vp_h_sync),
        .i_v_sync       (vp_v_sync),
        .i_rgb          (board1_video_rgb),

        .i_auth_active  (auth_active),
        .i_unlock_state (unlock_state),
        .i_lockout      (alram),
        .i_marker_valid (o_marker_valid),
        .i_grid_valid   (o_grid_valid),
        .i_grid_id      (o_grid_id),
        .i_auth_state   (auth_state),
        .i_pattern_index(pattern_index),

        .o_h_sync       (h_sync),
        .o_v_sync       (v_sync),
        .o_rgb          (ui_rgb)
    );

    assign port_red   = ui_rgb[11:8];
    assign port_green = ui_rgb[7:4];
    assign port_blue  = ui_rgb[3:0];

endmodule
