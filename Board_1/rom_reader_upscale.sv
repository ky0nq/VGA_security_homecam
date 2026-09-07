`timescale 1ns / 1ps

// Prof - Upscale
module rom_reader_upscale (
    input logic clk,
    input logic rst_n,
    input logic de,
    input logic [ 9:0] x_pixel,
    input logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input logic [15:0] px_data,
    output logic [11:0] o_rgb
);

    logic dispArea, dispArea_d;

    assign dispArea = de;
    assign addr = dispArea ? (y_pixel[9:1] * 320 + x_pixel[9:1]) : 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dispArea_d <= 1'b0;
        end else begin
            dispArea_d <= dispArea;
        end
    end

    assign o_rgb = dispArea_d ? {px_data[15:12], px_data[10:7], px_data[4:1]} : 0;

endmodule