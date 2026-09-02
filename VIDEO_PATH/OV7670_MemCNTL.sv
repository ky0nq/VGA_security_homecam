`timescale 1ns / 1ps

// Watches the camera href/vsync/data lines and writes each pixel into the frame buffer.

module OV7670_MemCNTL #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DW    = 16,
    parameter AW    = $clog2(IMG_W * IMG_H)
) (
    input  logic        pclk,
    input  logic        rst_n,
    input  logic        cam_href,
    input  logic        cam_vsync,
    input  logic [ 7:0] cam_data,
    output logic        we,
    output logic [AW-1:0] wAddr,
    output logic [DW-1:0] wData
);

    logic byteSel;      // picks the high byte or the low byte of one pixel
    logic [7:0] px_data; // holds the first (high) byte until the second one arrives

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            we <= 1'b0;
            wAddr <= 0;
            wData <= 0;
            byteSel <= 1'b0;
            px_data <= 0;
        end else begin
            we <= 1'b0;  // we is only high for 1 clock 
            if (we)
                wAddr <= wAddr + 1'b1;  // move to the next pixel address

            if (cam_vsync) begin
                // new frame starting, go back to address 0
                wAddr <= 0;
                byteSel <= 1'b0;
            end else if (!cam_href) begin
                // Start every active line from the first RGB565 byte.
                // This prevents a partial/odd previous line from swapping the
                // high and low bytes at the left edge of the next line.
                byteSel <= 1'b0;
            end else begin
                // normal pixel data, merge the two bytes into one RGB565 word
                byteSel <= ~byteSel;
                if (!byteSel) begin
                    px_data <= cam_data;   // first byte, just save it
                end else begin
                    wData <= {px_data, cam_data};  // second byte, write both
                    we <= 1'b1;
                end
            end
        end
    end

endmodule
