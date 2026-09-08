`timescale 1ns / 1ps

module board1_video_path #(
    parameter integer IMG_WIDTH  = 320,
    parameter integer IMG_HEIGHT = 240,

    parameter integer ADDR_WIDTH = $clog2(IMG_WIDTH * IMG_HEIGHT),

    // Grid display settings
    parameter integer GRID_LINE_THICKNESS = 2,
    parameter logic [11:0] GRID_LINE_COLOR = 12'hFFF,

    // Tracking path settings
    parameter integer PATH_SMOOTH_SHIFT = 2,
    parameter integer PATH_MOVE_MARGIN = 2,
    parameter integer PATH_MAX_JUMP = 80,
    parameter integer PATH_LINE_RADIUS = 1,
    parameter integer PATH_LOST_FRAME_MARGIN = 2,
    parameter logic [11:0] PATH_LINE_COLOR = 12'hFF0
) (
    // =========================================================
    // Clock / Reset
    // =========================================================
    input logic clk,
    input logic pclk,
    input logic rst_n,

    // =========================================================
    // Camera front-end inputs
    // =========================================================
    input logic                  i_cam_vsync,
    input logic                  i_frame_we,
    input logic [ADDR_WIDTH-1:0] i_frame_waddr,
    input logic [          15:0] i_frame_rgb565,

    // =========================================================
    // Authentication path inputs
    // =========================================================
    input logic i_auth_active,
    input logic i_path_clear_pclk,

    input logic       i_marker_valid,
    input logic [8:0] i_center_x,
    input logic [7:0] i_center_y,

    // =========================================================
    // VGA outputs
    // =========================================================
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb,

    // Debug signals
    output logic o_path_busy
);

    // =========================================================
    // Frame buffer signals
    // =========================================================
    logic [ADDR_WIDTH-1:0] frame_raddr;
    logic [          15:0] frame_rdata;

    // =========================================================
    // VGA timing signals
    // =========================================================
    logic                  display_enable;
    logic [           9:0] vga_x;
    logic [           9:0] vga_y;

    logic                  internal_h_sync;
    logic                  internal_v_sync;

    // =========================================================
    // RGB pipeline signals
    // =========================================================
    logic [          11:0] camera_rgb444;
    logic [          11:0] grid_overlay_rgb;
    logic [          11:0] tracking_rgb;

    logic                  tracking_h_sync;
    logic                  tracking_v_sync;

    // =========================================================
    // Frame Buffer
    //
    // Write Clock : OV7670 pclk
    // Read Clock  : VGA clk
    // =========================================================
    VGA_framebuffer #(
        .IMG_W(IMG_WIDTH),
        .IMG_H(IMG_HEIGHT),
        .DW   (16),
        .AW   (ADDR_WIDTH)
    ) U_FRAMEBUFFER (
        // Camera Write Side
        .wclk (pclk),
        .we   (i_frame_we),
        .wAddr(i_frame_waddr),
        .wData(i_frame_rgb565),

        // VGA Read Side
        .rclk (clk),
        .rAddr(frame_raddr),
        .rData(frame_rdata)
    );

    // =========================================================
    // VGA Timing Generator
    //
    // 640×480 @ 60Hz
    // =========================================================
    VGA_Decoder_top U_VGA_DECODER (
        .clk  (clk),
        .rst_n(rst_n),

        .h_sync(internal_h_sync),
        .v_sync(internal_v_sync),

        .x_pixel(vga_x),
        .y_pixel(vga_y),
        .de     (display_enable)
    );

    // =========================================================
    // Frame Buffer Reader
    //
    // Scale 320x240 RGB565 video to 640x480 RGB444.
    // =========================================================
    rom_reader_upscale U_FRAME_READER (
        .clk  (clk),
        .rst_n(rst_n),

        .de     (display_enable),
        .x_pixel(vga_x),
        .y_pixel(vga_y),

        .addr   (frame_raddr),
        .px_data(frame_rdata),

        .o_rgb(camera_rgb444)
    );

    // =========================================================
    // 3×3 Grid Overlay
    //
    // Show the grid only while authentication is active.
    // =========================================================
    grid_overlay #(
        .LINE_THICKNESS(GRID_LINE_THICKNESS),
        .LINE_COLOR    (GRID_LINE_COLOR)
    ) U_GRID_OVERLAY (
        .i_enable(i_auth_active),

        .i_de   (display_enable),
        .i_vga_x(vga_x),
        .i_vga_y(vga_y),

        .i_rgb(camera_rgb444),
        .o_rgb(grid_overlay_rgb)
    );

    // =========================================================
    // Tracking Path Overlay
    //
    // Draw the blue marker path over the gridded video.
    // =========================================================
    tracking_path_overlay #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),

        .SMOOTH_SHIFT     (PATH_SMOOTH_SHIFT),
        .MOVE_MARGIN      (PATH_MOVE_MARGIN),
        .MAX_JUMP         (PATH_MAX_JUMP),
        .LINE_RADIUS      (PATH_LINE_RADIUS),
        .LOST_FRAME_MARGIN(PATH_LOST_FRAME_MARGIN),

        .LINE_COLOR(PATH_LINE_COLOR)
    ) U_TRACKING_PATH_OVERLAY (
        // Camera PCLK Domain
        .i_pclk     (pclk),
        .i_rst_n    (rst_n),
        .i_cam_vsync(i_cam_vsync),
        .i_clear    (i_path_clear_pclk),

        .i_marker_valid(i_marker_valid),
        .i_center_x    (i_center_x),
        .i_center_y    (i_center_y),

        // VGA Clock Domain
        .i_vga_clk(clk),

        .i_de    (display_enable),
        .i_h_sync(internal_h_sync),
        .i_v_sync(internal_v_sync),
        .i_vga_x (vga_x),
        .i_vga_y (vga_y),

        // Camera video with grid
        .i_rgb(grid_overlay_rgb),

        // Final video with tracking path
        .o_h_sync(tracking_h_sync),
        .o_v_sync(tracking_v_sync),
        .o_rgb   (tracking_rgb),

        .o_busy(o_path_busy)
    );

    // =========================================================
    // VGA Output Register
    // =========================================================
    VGA_vga_outreg U_VGA_OUTREG (
        .clk  (clk),
        .rst_n(rst_n),

        .i_h_sync(tracking_h_sync),
        .i_v_sync(tracking_v_sync),
        .i_rgb   (tracking_rgb),

        .o_h_sync(o_h_sync),
        .o_v_sync(o_v_sync),
        .o_rgb   (o_rgb)
    );

endmodule
