`timescale 1ns / 1ps

module OV7670_XCLK_gen #(
    parameter int DIV = 4                 
)(
    input  logic clk,
    input  logic reset,
    output logic xclk
);
    localparam int HALF = DIV/2;
    localparam int CW   = (HALF < 2) ? 1 : $clog2(HALF);   

    logic [CW-1:0] cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt  <= '0;
            xclk <= 1'b0;
        end else if (cnt == HALF-1) begin
            cnt  <= '0;
            xclk <= ~xclk;
        end else begin
            cnt <= cnt + 1'b1;
        end
    end
endmodule
