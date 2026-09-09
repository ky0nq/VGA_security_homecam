`timescale 1ns / 1ps

// =================================================================================
// Module: framebuffer
// Description: Dual-clock simple dual-port Block RAM for image buffering.
//              - Write Port: Synchronous to wclk (Camera Pixel Clock)
//              - Read Port : Synchronous to rclk (VGA Display Clock)
// Memory Size: 320x240 pixels x 16-bit word width
// =================================================================================

module framebuffer #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DW    = 16,
    parameter AW    = $clog2(IMG_W * IMG_H)
) (
    // Write Interface (Camera side - PCLK domain)
    input  logic          wclk,
    input  logic          we,
    input  logic [AW-1:0] wAddr,
    input  logic [DW-1:0] wData,

    // Read Interface (VGA side - System clock domain)
    input  logic          rclk,
    input  logic [AW-1:0] rAddr,
    output logic [DW-1:0] rData
);

    // Frame Buffer Memory Array
    logic [DW-1:0] mem[0:(IMG_W*IMG_H)-1];

    // Synchronous Write Operation
    always_ff @(posedge wclk) begin
        if (we) begin
            mem[wAddr] <= wData;
        end
    end

    // Synchronous Read Operation
    always_ff @(posedge rclk) begin
        rData <= mem[rAddr];
    end

endmodule
