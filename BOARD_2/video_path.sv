`timescale 1ns / 1ps

// =================================================================================
// Module: video_path
// Description: Core video processing pipeline.
//              Routes camera streams through Gaussian blurring (Locked State) or
//              User Effects (Unlocked State) based on the `unlock_en` signal.
//
// Features:
//   - OV7670 camera capture and framebuffer readout via `vga_cam`.
//   - Gaussian blur pipeline (`gauss_filter_pipe`) applied when system is locked (`unlock_en = 0`).
//   - Custom color/gamma/night-mode effects (`filter_apply` & `filter_control`) applied when unlocked (`unlock_en = 1`).
//   - Dynamic MUX selection for output Sync and RGB streams.
// =================================================================================

module video_path (
    input  logic        clk,          // System clock (100 MHz)
    input  logic        pclk,         // OV7670 camera pixel clock
    input  logic        rst_n,        // Active-low asynchronous reset

    // UART Control Signals
    input  logic        unlock_en,    // Security state: 0 = Locked (Gaussian), 1 = Unlocked (Custom Effects)
    input  logic        zoom_en,      // Zoom mode enable
    input  logic        effect_sel,   // Filter selection toggle mode
    input  logic        btn_l,        // Left pan control pulse
    input  logic        btn_r,        // Right pan control pulse
    input  logic        btn_d,        // Down pan control pulse
    input  logic        btn_u,        // Up pan / Filter cycle pulse (1-clock pulse)

    // OV7670 Hardware Capture Interface
    input  logic        cam_href,
    input  logic        cam_vsync,
    input  logic [7:0]  cam_data,
    output logic        xclk,         // Master clock output to OV7670 (25 MHz)

    // SCCB Configuration Interface
    output logic        setup_busy,
    output logic        setup_done,
    output logic        setup_error,
    output logic        cam_scl,
    inout  wire         cam_sda,

    // Pipeline Video Stream Output (Drives `ui_frame_wrapper` / `vga_outreg`)
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    //==============================================================================
    // 1. VGA Camera Core (SCCB + Capture + Framebuffer + Upscaler/Pan/Zoom)
    //==============================================================================
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

    //==============================================================================
    // 2. Gaussian Blur Pipeline (Active when System is Locked)
    //==============================================================================
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

    //==============================================================================
    // 3. User Filter Controller & Apply Pipeline (Active when System is Unlocked)
    //==============================================================================
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

    //==============================================================================
    // 4. Output Multiplexer (Selected by `unlock_en`)
    //==============================================================================
    assign o_rgb    = unlock_en ? filter_rgb    : gauss_rgb;
    assign o_h_sync = unlock_en ? filter_h_sync : gauss_h_sync;
    assign o_v_sync = unlock_en ? filter_v_sync : gauss_v_sync;

endmodule
