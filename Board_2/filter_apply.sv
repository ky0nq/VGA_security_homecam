`timescale 1ns / 1ps

// =================================================================================
// Module: filter_apply
// Description: Chains multiple video color/effect filters in series.
// Data Flow: Input RGB -> Pink -> Orange -> Blue -> Gray -> Gamma -> Night -> Output RGB
// =================================================================================

module filter_apply (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    input  logic        pink_en,
    input  logic        orange_en,
    input  logic        blue_en,
    input  logic        gray_en,
    input  logic        gamma_en,
    input  logic        gamma_level,
    input  logic        night_en,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    // Intermediate pipeline signals
    logic        pink_h_sync,   pink_v_sync;
    logic [11:0] pink_rgb;

    logic        orange_h_sync, orange_v_sync;
    logic [11:0] orange_rgb;

    logic        blue_h_sync,   blue_v_sync;
    logic [11:0] blue_rgb;

    logic        gray_h_sync,   gray_v_sync;
    logic [11:0] gray_rgb;

    logic        gamma_h_sync,  gamma_v_sync;
    logic [11:0] gamma_rgb;

    // 1. Pink Filter
    pink_filter_pipe U_PINK (
        .clk     (clk),
        .rst_n   (rst_n),
        .pink_en (pink_en),
        .i_h_sync(i_h_sync),
        .i_v_sync(i_v_sync),
        .i_rgb   (i_rgb),
        .o_h_sync(pink_h_sync),
        .o_v_sync(pink_v_sync),
        .o_rgb   (pink_rgb)
    );

    // 2. Orange Filter
    orange_filter_pipe U_ORANGE (
        .clk       (clk),
        .rst_n     (rst_n),
        .orange_en (orange_en),
        .i_h_sync  (pink_h_sync),
        .i_v_sync  (pink_v_sync),
        .i_rgb     (pink_rgb),
        .o_h_sync  (orange_h_sync),
        .o_v_sync  (orange_v_sync),
        .o_rgb     (orange_rgb)
    );

    // 3. Blue Filter
    blue_filter_pipe U_BLUE (
        .clk     (clk),
        .rst_n   (rst_n),
        .blue_en (blue_en),
        .i_h_sync(orange_h_sync),
        .i_v_sync(orange_v_sync),
        .i_rgb   (orange_rgb),
        .o_h_sync(blue_h_sync),
        .o_v_sync(blue_v_sync),
        .o_rgb   (blue_rgb)
    );

    // 4. Gray Filter
    gray_filter_pipe U_GRAY (
        .clk     (clk),
        .rst_n   (rst_n),
        .gray_en (gray_en),
        .i_h_sync(blue_h_sync),
        .i_v_sync(blue_v_sync),
        .i_rgb   (blue_rgb),
        .o_h_sync(gray_h_sync),
        .o_v_sync(gray_v_sync),
        .o_rgb   (gray_rgb)
    );

    // 5. Gamma Correction Filter
    gamma_filter_pipe U_GAMMA (
        .clk        (clk),
        .rst_n      (rst_n),
        .gamma_en   (gamma_en),
        .gamma_level(gamma_level),
        .i_h_sync   (gray_h_sync),
        .i_v_sync   (gray_v_sync),
        .i_rgb      (gray_rgb),
        .o_h_sync   (gamma_h_sync),
        .o_v_sync   (gamma_v_sync),
        .o_rgb      (gamma_rgb)
    );

    // 6. Night Vision / Dark Enhancement Filter
    night_filter_pipe U_NIGHT (
        .clk     (clk),
        .rst_n   (rst_n),
        .night_en(night_en),
        .i_h_sync(gamma_h_sync),
        .i_v_sync(gamma_v_sync),
        .i_rgb   (gamma_rgb),
        .o_h_sync(o_h_sync),
        .o_v_sync(o_v_sync),
        .o_rgb   (o_rgb)
    );

endmodule
