`timescale 1ns / 1ps

// =================================================================================
// Module: ui_frame_wrapper
// Description: Wrapper module instantiating sync tracking, label ROM lookup, 
//              and frame overlay logic for video output processing.
//
// Features:
//   - Reconstructs active video coordinates (X, Y) and DE from incoming H/V Sync signals.
//   - Integrates UI overlay (Border & Label text box).
//   - Aligns H/V Sync output delay (2 clock cycles) with `ui_frame_overlay` latency.
// =================================================================================

module ui_frame_wrapper #(
    parameter int          LABEL_ID     = 0,            // 0: Terminal, 1: Home Cam
    parameter int          LABEL_W      = 78,           // Label text width in pixels
    parameter int          BORDER_PX    = 4,            // Outer border thickness
    parameter logic [11:0] BORDER_COLOR = 12'hFFF,      // Border color (RGB444)
    parameter string       LABEL_MEM    = "ui_labels.mem" // Memory init file path
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    // VGA Coordinate Recovery Tracker
    logic       de;
    logic [9:0] x, y;

    vga_sync_tracker U_TRACKER (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(i_h_sync),
        .i_v_sync(i_v_sync),
        .o_de    (de),
        .o_x     (x),
        .o_y     (y)
    );

    // Label ROM Interface Signals
    logic       label_sel, label_pixel;
    logic [6:0] label_x;
    logic [4:0] label_y;

    ui_label_rom #(
        .MEM_FILE(LABEL_MEM)
    ) U_LABEL_ROM (
        .clk    (clk),
        .i_label(label_sel),
        .i_x    (label_x),
        .i_y    (label_y),
        .o_pixel(label_pixel)
    );

    // UI Frame Overlay Core Module
    ui_frame_overlay #(
        .LABEL_ID    (LABEL_ID),
        .LABEL_W     (LABEL_W),
        .BORDER_PX   (BORDER_PX),
        .BORDER_COLOR(BORDER_COLOR)
    ) U_OVERLAY (
        .clk          (clk),
        .rst_n        (rst_n),
        .i_de         (de),
        .i_x          (x),
        .i_y          (y),
        .i_rgb        (i_rgb),
        .o_label_sel  (label_sel),
        .o_label_x    (label_x),
        .o_label_y    (label_y),
        .i_label_pixel(label_pixel),
        .o_rgb        (o_rgb)
    );

    // 2-Clock Sync Signal Delay Match (Matches 2-cycle latency of U_OVERLAY)
    logic h_sync_q1, v_sync_q1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_q1 <= 1'b1;
            v_sync_q1 <= 1'b1;
            o_h_sync  <= 1'b1;
            o_v_sync  <= 1'b1;
        end else begin
            h_sync_q1 <= i_h_sync;
            v_sync_q1 <= i_v_sync;
            o_h_sync  <= h_sync_q1;
            o_v_sync  <= v_sync_q1;
        end
    end

endmodule
