`timescale 1ns / 1ps

// =================================================================================
// Module: pink_filter_pipe
// Description: Converts RGB to a Pink/Magenta tint based on pixel luminance.
// Processing Pipeline:
//   - Converts RGB to Luminance Y = (77*R + 150*G + 29*B) >> 8
//   - Maps Luminance to Pink color ratio:
//       R = Y * 1.000 (Red dominant)
//       G = Y * 0.750 (Y - Y/4)
//       B = Y * 0.875 (Y - Y/8)
// Latency: 2 Clock Cycles
// =================================================================================

module pink_filter_pipe (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        pink_en,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    localparam int LATENCY = 2;

    // Stage 1: Luminance Multiplication (77*R, 150*G, 29*B)
    logic [11:0] s1_r, s1_g, s1_b;
    logic [11:0] s1_rgb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_r   <= 12'd0;
            s1_g   <= 12'd0;
            s1_b   <= 12'd0;
            s1_rgb <= 12'd0;
        end else begin
            s1_r   <= 8'd77  * i_rgb[11:8];
            s1_g   <= 8'd150 * i_rgb[7:4];
            s1_b   <= 8'd29  * i_rgb[3:0];
            s1_rgb <= i_rgb;
        end
    end

    // Stage 2: Luminance Accumulation, Pink Tone Mapping & Output Muxing
    logic [11:0] y_sum;
    logic [3:0]  gray;
    logic [3:0]  pink_r, pink_g, pink_b;

    assign y_sum = s1_r + s1_g + s1_b;
    assign gray  = y_sum[11:8];  // Equivalent to y_sum / 256

    assign pink_r = gray;                // R = Y * 1.000
    assign pink_g = gray - (gray >> 2);  // G = Y * 0.750
    assign pink_b = gray - (gray >> 3);  // B = Y * 0.875

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= 12'd0;
        end else begin
            o_rgb <= pink_en ? {pink_r, pink_g, pink_b} : s1_rgb;
        end
    end

    // Sync Signal Delay Pipeline (Matching Data Latency)
    logic [LATENCY-1:0] h_sync_d, v_sync_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_d <= {LATENCY{1'b1}};
            v_sync_d <= {LATENCY{1'b1}};
        end else begin
            h_sync_d <= {h_sync_d[LATENCY-2:0], i_h_sync};
            v_sync_d <= {v_sync_d[LATENCY-2:0], i_v_sync};
        end
    end

    assign o_h_sync = h_sync_d[LATENCY-1];
    assign o_v_sync = v_sync_d[LATENCY-1];

endmodule
