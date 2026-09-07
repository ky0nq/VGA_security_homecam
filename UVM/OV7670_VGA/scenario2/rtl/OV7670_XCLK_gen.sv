`timescale 1ns / 1ps

// 시스템 클럭을 나눠서 카메라 XCLK 생성. DIV=4 면 100MHz -> 25MHz.
// 정확히 24MHz 필요하면 Clocking Wizard 로 교체.
module OV7670_XCLK_gen #(
    parameter int DIV = 4                 // 짝수, 2 이상
)(
    input  logic clk,
    input  logic reset,
    output logic xclk
);
    localparam int HALF = DIV/2;
    localparam int CW   = (HALF < 2) ? 1 : $clog2(HALF);   // cnt 는 0..HALF-1 만 (HALF+1 아님)

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
