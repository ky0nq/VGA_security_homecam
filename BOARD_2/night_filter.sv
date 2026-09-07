`timescale 1ns / 1ps

// =================================================================================
// Module: night_filter_pipe
// Description: Simulates a Night Vision Goggle (Image Intensifier) effect.
// Processing Pipeline:
//   - Converts RGB to Luminance Y = (77*R + 150*G + 29*B) >> 8
//   - Applies Gamma 0.5 boosting to Green channel via 16-entry LUT (LUT_BOOST)
//   - Attenuates Red and Blue channels (Y >> 3) to yield a monochrome green tint
// Latency: 2 Clock Cycles
// =================================================================================

module night_filter_pipe (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        night_en,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    localparam int LATENCY = 2;

    // 16-Entry Luminance Boost LUT (Gamma ~0.5)
    localparam logic [3:0] LUT_BOOST[0:15] = '{
        4'd0, 4'd4, 4'd5, 4'd7, 4'd8, 4'd9, 4'd9, 4'd10,
        4'd11, 4'd12, 4'd12, 4'd13, 4'd13, 4'd14, 4'd14, 4'd15
    };

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

    // Stage 2: Luminance Accumulation, Boosting & Green-tint Mapping
    logic [11:0] y_sum;
    logic [3:0]  gray;
    logic [3:0]  night_r, night_g, night_b;

    assign y_sum = s1_r + s1_g + s1_b;
    assign gray  = y_sum[11:8];  // Equivalent to y_sum / 256

    assign night_r = gray >> 3;        // Attenuated Red (Y * 0.125)
    assign night_g = LUT_BOOST[gray];  // Boosted Green
    assign night_b = gray >> 3;        // Attenuated Blue (Y * 0.125)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= 12'd0;
        end else begin
            o_rgb <= night_en ? {night_r, night_g, night_b} : s1_rgb;
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
