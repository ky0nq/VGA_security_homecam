`timescale 1ns / 1ps
module VGA_OutReg (
	input  logic        clk,
	input  logic        reset,
	input  logic        i_h_sync,
	input  logic        i_v_sync,
	input  logic [11:0] i_rgb,
	output logic        o_h_sync,
	output logic        o_v_sync,
	output logic [11:0] o_rgb
);

	logic r_h_sync, r_v_sync;
	logic [11:0] r_rgb;

	always_ff @(posedge clk, posedge reset) begin
		if (reset) begin
			r_h_sync <= 1'b1;
			r_v_sync <= 1'b1;
			r_rgb    <= 0;
		end else begin
			r_h_sync <= i_h_sync;
			r_v_sync <= i_v_sync;
			r_rgb    <= i_rgb;
		end
	end

	assign o_h_sync = r_h_sync;
	assign o_v_sync = r_v_sync;
	assign o_rgb    = r_rgb;
endmodule
