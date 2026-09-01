`timescale 1ns / 1ps


module pixel_counter (
	input logic clk,
	input logic rst_n,
	input logic pclk,
	output logic [9:0] h_count, // 0 ~ 799
	output logic [9:0] v_count  // 0 ~ 524
);

	localparam H_MAX = 800, V_MAX = 525;
	
	always_ff  @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			h_count <= 0;
		end
		else begin
			if (pclk) begin
				if (h_count == H_MAX - 1) begin
					h_count <= 0;
				end 
				else begin
					h_count <= h_count + 1;
				end			
			end
		end
	end

	always_ff  @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			v_count <= 0;
		end
		else begin
			if (pclk) begin
				if (h_count == H_MAX - 1) begin
					if (v_count == V_MAX - 1) begin
						v_count <= 0;
					end 
					else begin
						v_count <= v_count + 1;
					end
				end			
			end
		end
	end

endmodule