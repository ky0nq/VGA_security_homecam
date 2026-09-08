`timescale 1ns / 1ps

module camera_clk_gen (
    input  logic clk,
    input  logic rst_n,
    output logic xclk
);

    logic [1:0] clk_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 2'd0;
            xclk    <= 1'b0;
        end else begin
            if (clk_cnt == 2'd3) begin
                clk_cnt <= 2'd0;
                xclk    <= 1'b0;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
                xclk    <= (clk_cnt < 2'd2) ? 1'b1 : 1'b0;
            end
        end
    end

endmodule
