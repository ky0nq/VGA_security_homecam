`timescale 1ns / 1ps

// =================================================================================
// Module: rom_reader_upscale
// Description: Memory Reader & Upscaler for Professor display region.
// Features:
//   - Supports 2x Digital Zoom based on directional pulse triggers (zoom_r/l/d)
//   - Latches selected zoom region (zoom_in) until next direction trigger
//   - Calculates 17-bit ROM addresses for 320x240 source image scaling
//   - Formats 16-bit ROM pixel data into RGB444 output with 1-cycle pipeline delay
// =================================================================================

module rom_reader_upscale (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        zoom_en,
    input  logic        zoom_r,     // 1-clock pulse trigger for right region
    input  logic        zoom_l,     // 1-clock pulse trigger for left region
    input  logic        zoom_d,     // 1-clock pulse trigger for bottom region

    input  logic        de,         // Data Enable (Display Active Area)
    input  logic [9:0]  x_pixel,
    input  logic [9:0]  y_pixel,

    output logic [16:0] addr,
    input  logic [15:0] px_data,
    output logic [11:0] o_rgb
);

    logic [1:0] zoom_in;
    logic       dispArea, dispArea_d;

    // Zoom Region Selection Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zoom_in <= 2'b00;
        end else if (!zoom_en) begin
            zoom_in <= 2'b00;       // Reset to default region when zoom disabled
        end else if (zoom_l) begin
            zoom_in <= 2'b10;
        end else if (zoom_r) begin
            zoom_in <= 2'b01;
        end else if (zoom_d) begin
            zoom_in <= 2'b11;
        end
    end

    assign dispArea = de;

    // ROM Address Generation (Base scaling: 320 x Y + X via bit-shifts)
    // 320 * Y = (Y << 8) + (Y << 6)
    assign addr = dispArea ? ( (((y_pixel[9:1] >> zoom_en) + zoom_in[1] * 120) << 8)  
                            +  (((y_pixel[9:1] >> zoom_en) + zoom_in[1] * 120) << 6)
                            +  ((x_pixel[9:1] >> zoom_en) + zoom_in[0] * 160) ) : 17'd0;

    // Display Active Region Pipeline Matching (1 Clock Delay)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dispArea_d <= 1'b0;
        end else begin
            dispArea_d <= dispArea;
        end
    end

    // Pixel Data Unpacking: RGB565/RGB555 format to RGB444
    assign o_rgb = dispArea_d ? {px_data[15:12], px_data[10:7], px_data[4:1]} : 12'd0;

endmodule
