`timescale 1ns / 1ps

// Top module. Connects uart_link, video_path, and vga_outreg to the board pins.

module OV7670_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input logic clk,
    input logic rst_n,

    // UART link to the tracking board
    input  logic uart_rx,
    output logic uart_tx,

    // OV7670 capture pins
    input  logic       pclk,       // real pixel clock coming out of the camera
    input  logic       cam_href,
    input  logic       cam_vsync,
    input  logic [7:0] cam_data,
    output logic       xclk,

    // SCCB pins used to set up the camera registers
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    output logic unlock_en,   // unlock_en coming from uart_link

    // VGA output pins
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    //============================================================
    // uart_link : UART + 10 second silence watchdog + byte decoding
    //============================================================
    logic zoom_en;
    logic effect_sel;
    logic btn_l, btn_r, btn_d;
    logic btn_u_pulse;

    uart_link #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART_LINK (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (uart_rx),
        .tx         (uart_tx),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l      (btn_l),
        .btn_r      (btn_r),
        .btn_d      (btn_d),
        .btn_u_pulse(btn_u_pulse),
        .unlock_en  (unlock_en)
    );

    //============================================================
    // video_path : camera setup + capture + frame buffer + zoom + filters
    //============================================================
    logic        vp_h_sync;
    logic        vp_v_sync;
    logic [11:0] vp_rgb;

    video_path U_VIDEO_PATH (
        .clk        (clk),
        .pclk       (pclk),       // pass the real camera pixel clock straight through
        .rst_n      (rst_n),
        .unlock_en  (unlock_en),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l      (btn_l),
        .btn_r      (btn_r),
        .btn_d      (btn_d),
        .btn_u      (btn_u_pulse),
        .cam_href   (cam_href),
        .cam_vsync  (cam_vsync),
        .cam_data   (cam_data),
        .xclk       (xclk),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .cam_scl    (cam_scl),
        .cam_sda    (cam_sda),
        .o_h_sync   (vp_h_sync),
        .o_v_sync   (vp_v_sync),
        .o_rgb      (vp_rgb)
    );

    //============================================================
    // vga_outreg : split RGB444 into 4/4/4 and register the final output
    //============================================================
    logic [11:0] out_rgb;

    vga_outreg U_VGA_OUTREG (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(vp_h_sync),
        .i_v_sync(vp_v_sync),
        .i_rgb   (vp_rgb),
        .o_h_sync(h_sync),
        .o_v_sync(v_sync),
        .o_rgb   (out_rgb)
    );

    assign {port_red, port_green, port_blue} = out_rgb;

endmodule
