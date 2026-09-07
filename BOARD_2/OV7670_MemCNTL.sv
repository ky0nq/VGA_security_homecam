`timescale 1ns / 1ps

// =================================================================================
// Module: OV7670_MemCNTL
// Purpose: Receive 8-bit image data from the OV7670 camera, combine every 2 bytes
//          into a 16-bit pixel, and generate memory write address and enable signals.
// =================================================================================

module OV7670_MemCNTL #(
    parameter IMG_W = 320,                  // Image width (pixels)
    parameter IMG_H = 240,                  // Image height (pixels)
    parameter DW    = 16,                   // Data width (16-bit per pixel)
    parameter AW    = $clog2(IMG_W * IMG_H) // Memory address width
) (
    input  logic          pclk,             // Pixel clock from camera
    input  logic          rst_n,            // Active-low reset signal
    input  logic          cam_href,         // High when line data is valid
    input  logic          cam_vsync,        // High when new image frame starts
    input  logic [7:0]    cam_data,         // 8-bit camera input data
    output logic          we,               // Memory write enable pulse
    output logic [AW-1:0] wAddr,            // Memory write address
    output logic [DW-1:0] wData             // Combined 16-bit pixel data
);

    logic       byteSel;                    // 0: First byte (High), 1: Second byte (Low)
    logic [7:0] px_data;                    // Temporary storage for the first byte

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            we      <= 1'b0;
            wAddr   <= '0;
            wData   <= '0;
            byteSel <= 1'b0;
            px_data <= '0;
        end else begin
            we <= 1'b0;                     // Clear write pulse by default (1-clock pulse)

            // Move to the next memory address after writing a pixel
            if (we)
                wAddr <= wAddr + 1'b1;

            // Priority 1: New frame signal (Reset memory address to 0)
            if (cam_vsync) begin
                wAddr   <= '0;
                byteSel <= 1'b0;
            end 
            // Priority 2: Line is not active (Reset byte order counter)
            else if (!cam_href) begin
                // Always start each new line from the first byte.
                // This prevents color mismatch (swapping High and Low bytes).
                byteSel <= 1'b0;
            end 
            // Priority 3: Active image data coming in
            else begin
                byteSel <= ~byteSel;        // Toggle byte counter (0 -> 1 -> 0 -> 1)

                // First byte of the pixel (High byte)
                if (!byteSel) begin
                    px_data <= cam_data;    // Save first 8 bits
                end 
                // Second byte of the pixel (Low byte)
                else begin
                    wData <= {px_data, cam_data}; // Combine 2 bytes into 16-bit pixel
                    we    <= 1'b1;                // Send write pulse to memory
                end
            end
        end
    end

endmodule
