`timescale 1ns / 1ps

module VGA_Decoder (
    input  logic       clk,
    input  logic       rst_n,
    output logic       h_sync,
    output logic       v_sync,
    output logic [9:0] x_pixel,
    output logic [9:0] y_pixel,
    output logic       de
);

    logic       pclk;
    logic [9:0] h_count;
    logic [9:0] v_count;

    pclk_gen U_PCLK_GEN (
        .clk   (clk),
        .rst_n (rst_n),
        .pclk  (pclk)
    );

    pixel_counter U_PIXEL_COUNTER (
        .clk     (clk),
        .rst_n   (rst_n),
        .pclk    (pclk),
        .h_count (h_count),
        .v_count (v_count)
    );

    vga_decoder U_VGA_DECODER (
        .h_count (h_count),
        .v_count (v_count),
        .h_sync  (h_sync),
        .v_sync  (v_sync),
        .x_pixel (x_pixel),
        .y_pixel (y_pixel),
        .de      (de)
    );

endmodule

module vga_decoder (
	input logic [9:0] h_count,
	input logic [9:0] v_count,
	output logic h_sync,
	output logic v_sync,
	output logic [9:0] x_pixel,
	output logic [9:0] y_pixel,
	output logic de
);
	
	localparam H_Visible_area   = 640;   
	localparam H_Front_porch    =  16;    
	localparam H_Sync_pulse     =  96;   
	localparam H_Back_porch     =  48;   
	localparam H_Whole_line     = 800; 

	localparam V_Visible_area   = 480;   
	localparam V_Front_porch    =  10;   
	localparam V_Sync_pulse     =   2;   
	localparam V_Back_porch     =  33;  
	localparam V_Whole_frame    = 525;   
	
	assign x_pixel = h_count;
	assign y_pixel = v_count;
	
	assign h_sync = !((h_count >= (H_Visible_area + H_Front_porch))
             && (h_count <  (H_Visible_area + H_Front_porch + H_Sync_pulse)));
	assign v_sync = !((v_count >= (V_Visible_area + V_Front_porch))
               && (v_count <  (V_Visible_area + V_Front_porch + V_Sync_pulse)));
  assign de = (h_count < H_Visible_area) && (v_count < V_Visible_area);
  
	
endmodule