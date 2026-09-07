`timescale 1ns / 1ps

// Reads the frame buffer at double size and picks which zoom area to show.

module rom_reader_upscale (
    input logic clk,
    input logic rst_n,
    input logic zoom_en,
    input logic zoom_r,   // 1-clock pulse
    input logic zoom_l,   // 1-clock pulse
    input logic zoom_d,   // 1-clock pulse
    input logic de,
    input logic [ 9:0] x_pixel,
    input logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input logic [15:0] px_data,
    output logic [11:0] o_rgb
);
	logic [1:0] zoom_in;
    logic dispArea, dispArea_d;

    //============================================================
    // remembers which zoom area is picked
    //   zoom_en off (or reset) goes back to the default area (00)
    //   a button pulse switches to that area, no pulse just keeps the last one
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zoom_in <= 2'b00;
        end else if (!zoom_en) begin
            zoom_in <= 2'b00;          // zoom off, go back to default area
        end else if (zoom_l) begin
            zoom_in <= 2'b10;
        end else if (zoom_r) begin
            zoom_in <= 2'b01;
        end else if (zoom_d) begin
            zoom_in <= 2'b11;
        end
        // otherwise keep the current area
    end

    assign dispArea = de;
    // this line does the math for a plain 1:1 read (kept here for reference)
    //assign addr = dispArea ? (y_pixel[9:1] * 320 + x_pixel[9:1]) : 0;

    // divide x/y by 2 for the 2x upscale, then add the zoom area offset
	assign addr = dispArea ? ( (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 8)  
							+  (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 6)
							+  ((x_pixel[9:1]>> zoom_en)+zoom_in[0]*160)) : 0;

    // memory read takes 1 clock, so delay dispArea by 1 clock to line up with px_data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dispArea_d <= 1'b0;
        end else begin
            dispArea_d <= dispArea;
        end
    end

    // RGB565 to RGB444: just keep the top 4 bits of each color
    assign o_rgb = dispArea_d ? {px_data[15:12], px_data[10:7], px_data[4:1]} : 0;

endmodule
