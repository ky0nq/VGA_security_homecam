`timescale 1ns / 1ps

// =================================================================================
// Module: vga_sync_tracker
// Description: Reconstructs active video coordinates (x, y) and data enable (de)
//              signals solely by tracking incoming HSYNC and VSYNC edges.
//
// Application:
//   - Fits at the end of deep image processing pipelines (e.g., Gaussian blur,
//     Sobel edge detection) where pixel data and sync signals are delayed together.
//   - Eliminates the need to propagate coordinate busses through intermediate filters,
//     automatically re-aligning video coordinates regardless of pipeline latency.
//
// Timing Reference (VGA 640x480 @ 60Hz from 100 MHz clock via 4-phase divider):
//   - H_TOTAL = 800, H_VISIBLE = 640 | HSYNC Pulse: 656 to 751 (Rising edge at 752)
//   - V_TOTAL = 525, V_VISIBLE = 480 | VSYNC Pulse: 490 to 491 (Rising edge at 492)
// =================================================================================

module vga_sync_tracker (
    input  logic        clk,       // System clock (100 MHz)
    input  logic        rst_n,     // Active-low asynchronous reset

    // Incoming Delayed Sync Inputs
    input  logic        i_h_sync,  // Pipeline-delayed Horizontal Sync
    input  logic        i_v_sync,  // Pipeline-delayed Vertical Sync

    // Reconstructed Display Signals
    output logic        o_de,      // Active Video Display Enable (1 = Active Pixel Area)
    output logic [9:0]  o_x,       // Reconstructed Horizontal Coordinate (0 ~ 799)
    output logic [9:0]  o_y        // Reconstructed Vertical Coordinate (0 ~ 524)
);

    // VGA 640x480 Standard Parameters
    localparam int H_TOTAL   = 800;
    localparam int V_TOTAL   = 525;
    localparam int H_VISIBLE = 640;
    localparam int V_VISIBLE = 480;

    // Pulse Termination Offsets (1-based count where rising edge occurs)
    localparam int H_SYNC_END = 752;  // HSYNC low: 656..751, rises at 752
    localparam int V_SYNC_END = 492;  // VSYNC low: 490..491, rises at 492

    // Edge Detection Registers
    logic h_sync_q, v_sync_q;
    logic h_rise, v_rise;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_q <= 1'b1;
            v_sync_q <= 1'b1;
        end else begin
            h_sync_q <= i_h_sync;
            v_sync_q <= i_v_sync;
        end
    end

    assign h_rise =  i_h_sync & ~h_sync_q;
    assign v_rise =  i_v_sync & ~v_sync_q;

    // 25 MHz Pixel Clock Phase Divider (Sub-sampled from 100 MHz system clock)
    // Automatically re-phases on every HSYNC rising edge to prevent phase drift.
    logic [1:0] phase;
    logic       tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      phase <= 2'd0;
        else if (h_rise) phase <= 2'd0;        // Phase resynchronization per line
        else             phase <= phase + 2'd1;
    end

    assign tick = (phase == 2'd3);              // Pixel tick pulse every 4 system clocks

    // Raster Position Tracking Counters
    logic [9:0] x_cnt, y_cnt;
    logic       line_end;

    assign line_end = tick && (x_cnt == H_TOTAL - 1);

    // Horizontal Raster Counter Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      x_cnt <= 10'd0;
        else if (h_rise) x_cnt <= 10'(H_SYNC_END);
        else if (tick)   x_cnt <= (x_cnt == H_TOTAL - 1) ? 10'd0 : x_cnt + 10'd1;
    end

    // Vertical Raster Counter Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        y_cnt <= 10'd0;
        else if (v_rise)   y_cnt <= 10'(V_SYNC_END);
        else if (line_end) y_cnt <= (y_cnt == V_TOTAL - 1) ? 10'd0 : y_cnt + 10'd1;
    end

    // Output Coordinates & Display Enable Recovery
    assign o_x  = x_cnt;
    assign o_y  = y_cnt;
    assign o_de = (x_cnt < H_VISIBLE) && (y_cnt < V_VISIBLE);

endmodule
