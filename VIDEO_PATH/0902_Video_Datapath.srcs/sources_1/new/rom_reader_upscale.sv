`timescale 1ns / 1ps


module rom_reader_upscale (
    input logic clk,
    input logic rst_n,
    input logic zoom_en,
    input logic zoom_r,
    input logic zoom_l,
    input logic zoom_d,
    input logic de,
    input logic [ 9:0] x_pixel,
    input logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input logic [15:0] px_data,
    output logic [11:0] o_rgb
);
	logic [1:0] zoom_in;
    logic dispArea, dispArea_d;

	always @(*) begin
		if(zoom_en == 1)begin
			case ({zoom_r, zoom_l, zoom_d})
				3'b001 : begin zoom_in = 2'b11; end
				3'b010 : begin zoom_in = 2'b10; end
				3'b100 : begin zoom_in = 2'b01; end
				default : begin zoom_in = 2'b00; end
			endcase
		end
		else begin zoom_in = 0; end
	end

    assign dispArea = de;
    //assign addr = dispArea ? (y_pixel[9:1] * 320 + x_pixel[9:1]) : 0;
	assign addr = dispArea ? ( (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 8)  
							+  (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 6)
							+  ((x_pixel[9:1]>> zoom_en)+zoom_in[0]*160)) : 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dispArea_d <= 1'b0;
        end else begin
            dispArea_d <= dispArea;
        end
    end

    assign o_rgb = dispArea_d ? {px_data[15:12], px_data[10:7], px_data[4:1]} : 0;

endmodule