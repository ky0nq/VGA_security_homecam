`timescale 1ns / 1ps

// =================================================================================
// Module: VGA_Decoder (Top Wrapper) & vga_decoder (Combinational Decoder)
// Description: Standard VGA 640x480 @ 60Hz timing generator pipeline.
//
// Features:
//   - Pixel clock generation and 2D pixel scanning (H/V counters).
//   - Generation of standard negative-polarity HSYNC and VSYNC pulses.
//   - Data Enable (DE) flag and active display area coordinates (x_pixel, y_pixel).
//
// Timing Specifications (640x480 @ 60Hz):
//   - Horizontal: Active = 640, FP = 16, Sync = 96, BP = 48 (Total = 800 Clocks)
//   - Vertical  : Active = 480, FP = 10, Sync = 2,  BP = 33 (Total = 525 Lines)
// =================================================================================

module VGA_Decoder (
    input  logic        clk,      // System clock (e.g., 100 MHz)
    input  logic        rst_n,    // Active-low asynchronous reset
    output logic        h_sync,   // Horizontal Sync Output (Active Low)
    output logic        v_sync,   // Vertical Sync Output (Active Low)
    output logic [9:0]  x_pixel,  // Active horizontal pixel coordinate (0~639)
    output logic [9:0]  y_pixel,  // Active vertical pixel coordinate (0~479)
    output logic        de        // Data Enable / Active Video Area Indicator
);

    // Internal Pixel Clock and Counter Signals
    logic       pclk;
    logic [9:0] h_count;
    logic [9:0] v_count;

    // 25 MHz Pixel Clock Generator (Derived from System Clock)
    pclk_gen U_PCLK_GEN (
        .clk   (clk),
        .rst_n (rst_n),
        .pclk  (pclk)
    );

    // Horizontal and Vertical Raster Counter
    pixel_counter U_PIXEL_COUNTER (
        .clk     (clk),
        .rst_n   (rst_n),
        .pclk    (pclk),
        .h_count (h_count),
        .v_count (v_count)
    );

    // Decoder Module Driving VGA Signals from Counter Values
    vga_decoder U_VGA_DECODER (
        .h_count (h_count),
        .v_count (v_count),
        .h_sync  (h_sync),
        .v_sync  (v_sync),
        .x_pixel (x_pixel),
        .y_pixel (y_pixel),
        .de      (de)
    );

endmodule


// =================================================================================
// Sub-Module: vga_decoder
// Description: Combinational logic generating sync pulses, pixel coordinates,
//              and display enable based on current line/frame counter states.
// =================================================================================

module vga_decoder (
    input  logic [9:0] h_count,   // Current horizontal raster counter (0~799)
    input  logic [9:0] v_count,   // Current vertical raster counter (0~524)
    output logic       h_sync,    // Horizontal Sync Signal
    output logic       v_sync,    // Vertical Sync Signal
    output logic [9:0] x_pixel,   // Horizontal Pixel Coordinate
    output logic [9:0] y_pixel,   // Vertical Pixel Coordinate
    output logic       de         // Active Data Region
);

    // VGA 640x480 @ 60Hz Timing Constants
    localparam int H_Visible_area = 640;
    localparam int H_Front_porch  = 16;
    localparam int H_Sync_pulse   = 96;
    localparam int H_Back_porch   = 48;
    localparam int H_Whole_line   = 800;

    localparam int V_Visible_area = 480;
    localparam int V_Front_porch  = 10;
    localparam int V_Sync_pulse   = 2;
    localparam int V_Back_porch   = 33;
    localparam int V_Whole_frame  = 525;

    // Direct Mapping of Counter Values to Pixel Coordinates
    assign x_pixel = h_count;
    assign y_pixel = v_count;

    // Active-Low Horizontal Sync Pulse Generation (Active between Front Porch and Back Porch)
    assign h_sync = !((h_count >= (H_Visible_area + H_Front_porch)) &&
                      (h_count <  (H_Visible_area + H_Front_porch + H_Sync_pulse)));

    // Active-Low Vertical Sync Pulse Generation
    assign v_sync = !((v_count >= (V_Visible_area + V_Front_porch)) &&
                      (v_count <  (V_Visible_area + V_Front_porch + V_Sync_pulse)));

    // Data Enable (DE) Assertion During Active Visible Region
    assign de = (h_count < H_Visible_area) && (v_count < V_Visible_area);

endmodule
