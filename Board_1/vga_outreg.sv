`timescale 1ns / 1ps

module vga_outreg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;
            o_v_sync <= 1'b1;
            o_rgb    <= 12'b0;
        end else begin
            o_h_sync <= i_h_sync;
            o_v_sync <= i_v_sync;
            o_rgb    <= i_rgb;
        end
    end

endmodule
