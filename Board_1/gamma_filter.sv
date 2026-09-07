`timescale 1ns / 1ps

module gamma_filter_pipe (
    input  logic clk,
    input  logic rst_n,
    input  logic gamma_en,
    input  logic gamma_level,
    input  logic i_h_sync,
    input  logic i_v_sync,
    input  logic [11:0] i_rgb,
    output logic o_h_sync,
    output logic o_v_sync,
    output logic [11:0] o_rgb
);

    logic [3:0] r_in, g_in, b_in;
    logic [3:0] r_gamma, g_gamma, b_gamma;

    assign r_in = i_rgb[11:8];
    assign g_in = i_rgb[7:4];
    assign b_in = i_rgb[3:0];

    function automatic logic [3:0] gamma_lut_g07(input logic [3:0] x);
        case (x)
            4'd0:  gamma_lut_g07 = 4'd0;
            4'd1:  gamma_lut_g07 = 4'd2;
            4'd2:  gamma_lut_g07 = 4'd4;
            4'd3:  gamma_lut_g07 = 4'd5;
            4'd4:  gamma_lut_g07 = 4'd6;
            4'd5:  gamma_lut_g07 = 4'd7;
            4'd6:  gamma_lut_g07 = 4'd8;
            4'd7:  gamma_lut_g07 = 4'd9;
            4'd8:  gamma_lut_g07 = 4'd10;
            4'd9:  gamma_lut_g07 = 4'd10;
            4'd10: gamma_lut_g07 = 4'd11;
            4'd11: gamma_lut_g07 = 4'd12;
            4'd12: gamma_lut_g07 = 4'd13;
            4'd13: gamma_lut_g07 = 4'd14;
            4'd14: gamma_lut_g07 = 4'd14;
            4'd15: gamma_lut_g07 = 4'd15;
            default: gamma_lut_g07 = 4'd0;
        endcase
    endfunction

    function automatic logic [3:0] gamma_lut_g03(input logic [3:0] x);
        case (x)
            4'd0:  gamma_lut_g03 = 4'd0;
            4'd1:  gamma_lut_g03 = 4'd7;
            4'd2:  gamma_lut_g03 = 4'd8;
            4'd3:  gamma_lut_g03 = 4'd9;
            4'd4:  gamma_lut_g03 = 4'd10;
            4'd5:  gamma_lut_g03 = 4'd11;
            4'd6:  gamma_lut_g03 = 4'd11;
            4'd7:  gamma_lut_g03 = 4'd12;
            4'd8:  gamma_lut_g03 = 4'd12;
            4'd9:  gamma_lut_g03 = 4'd13;
            4'd10: gamma_lut_g03 = 4'd13;
            4'd11: gamma_lut_g03 = 4'd14;
            4'd12: gamma_lut_g03 = 4'd14;
            4'd13: gamma_lut_g03 = 4'd14;
            4'd14: gamma_lut_g03 = 4'd15;
            4'd15: gamma_lut_g03 = 4'd15;
            default: gamma_lut_g03 = 4'd0;
        endcase
    endfunction

    always_comb begin
        if (gamma_level) begin
            r_gamma = gamma_lut_g03(r_in);
            g_gamma = gamma_lut_g03(g_in);
            b_gamma = gamma_lut_g03(b_in);
        end
        else begin
            r_gamma = gamma_lut_g07(r_in);
            g_gamma = gamma_lut_g07(g_in);
            b_gamma = gamma_lut_g07(b_in);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            o_rgb <= 12'h000;
        else
            o_rgb <= gamma_en ? {r_gamma, g_gamma, b_gamma} : i_rgb;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;
            o_v_sync <= 1'b1;
        end
        else begin
            o_h_sync <= i_h_sync;
            o_v_sync <= i_v_sync;
        end
    end

endmodule