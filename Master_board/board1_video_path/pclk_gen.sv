`timescale 1ns / 1ps

module pclk_gen (
	input logic clk,
	input logic rst_n,
	output logic pclk
);

	logic [1:0] p_cnt;
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			p_cnt <= 0;
			pclk <= 0;		
		end
		else begin
			if (p_cnt == 2'd3) begin
				p_cnt <= 0;
				pclk <= 1'b1;
			end
			else begin
				p_cnt <= p_cnt + 1;
				pclk <= 1'b0;
			end
		end
	end

endmodule