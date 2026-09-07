`timescale 1ns / 1ps

// Picks between the blurred camera and the filtered camera based on unlock_en.

module video_path (
    input logic clk,      // system clock
    input logic pclk,     // real OV7670 pixel clock
    input logic rst_n,

    // signals that already came out of the UART decoder
    input logic unlock_en,   // from uart_link
    input logic zoom_en,
    input logic effect_sel,
    input logic btn_l,
    input logic btn_r,
    input logic btn_d,
    input logic btn_u,         // from uart_link, already a 1-clock pulse

    // OV7670 capture pins
    input  logic       cam_href,
    input  logic       cam_vsync,
    input  logic [7:0] cam_data,
    output logic       xclk,       // OV7670 XCLK pin

    // SCCB pins for camera register setup
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    // final output, goes into vga_outreg next
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    //============================================================
    // vga_cam : SCCB setup + capture + frame buffer + zoom/upscale
    //============================================================
    logic        cam_h_sync;
    logic        cam_v_sync;
    logic [11:0] cam_rgb;

    vga_cam U_VGA_CAM (
        .clk        (clk),
        .pclk       (pclk),
        .rst_n      (rst_n),
        .zoom_en    (zoom_en),
        .zoom_r     (btn_r),
        .zoom_l     (btn_l),
        .zoom_d     (btn_d),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .cam_scl    (cam_scl),
        .cam_sda    (cam_sda),
        .cam_href   (cam_href),
        .cam_vsync  (cam_vsync),
        .cam_data   (cam_data),
        .o_h_sync   (cam_h_sync),
        .o_v_sync   (cam_v_sync),
        .o_rgb      (cam_rgb),
        .xclk       (xclk)
    );

    //============================================================
    // blur branch, always running
    //============================================================
    logic        gauss_h_sync;
    logic        gauss_v_sync;
    logic [11:0] gauss_rgb;

    gauss_filter_pipe U_GAUSS_FILTER (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(cam_h_sync),
        .i_v_sync(cam_v_sync),
        .i_rgb   (cam_rgb),
        .o_h_sync(gauss_h_sync),
        .o_v_sync(gauss_v_sync),
        .o_rgb   (gauss_rgb)
    );

    //============================================================
    // filter branch, also always running
    //============================================================
    logic pink_en, orange_en, blue_en, gray_en;
    logic gamma_en, gamma_level, night_en;

    filter_control U_FILTER_CONTROL (
        .clk        (clk),
        .rst_n      (rst_n),
        .unlock_en  (unlock_en),
        .effect_sel (effect_sel),
        .btn_u_pulse(btn_u),
        .pink_en    (pink_en),
        .blue_en    (blue_en),
        .orange_en  (orange_en),
        .gray_en    (gray_en),
        .gamma_en   (gamma_en),
        .gamma_level(gamma_level),
        .night_en   (night_en)
    );

    logic        filter_h_sync;
    logic        filter_v_sync;
    logic [11:0] filter_rgb;

    filter_apply U_FILTER_APPLY (
        .clk        (clk),
        .rst_n      (rst_n),
        .i_h_sync   (cam_h_sync),
        .i_v_sync   (cam_v_sync),
        .i_rgb      (cam_rgb),
        .pink_en    (pink_en),
        .orange_en  (orange_en),
        .blue_en    (blue_en),
        .gray_en    (gray_en),
        .gamma_en   (gamma_en),
        .gamma_level(gamma_level),
        .night_en   (night_en),
        .o_h_sync   (filter_h_sync),
        .o_v_sync   (filter_v_sync),
        .o_rgb      (filter_rgb)
    );

    //============================================================
    // final pick: unlock_en = 0 shows the blur, 1 shows the filtered picture
    //============================================================
    assign o_rgb    = unlock_en ? filter_rgb    : gauss_rgb;
    assign o_h_sync = unlock_en ? filter_h_sync : gauss_h_sync;
    assign o_v_sync = unlock_en ? filter_v_sync : gauss_v_sync;

endmodule
