`timescale 1ns / 1ps

// =================================================================================
// Module: vga_outreg
// Description: Output pipeline register stage for VGA display signals.
//
// Purpose:
//   - Registers display outputs (HSYNC, VSYNC, RGB) immediately before FPGA I/O pads.
//   - Cuts long combinational paths from internal logic/BRAM read pipelines.
//   - Ensures clean, glitch-free output transitions aligned to the system clock.
//   - Aids static timing analysis (STA) setup/hold time closure on physical pins.
// =================================================================================

module vga_outreg (
    input  logic        clk,       // System / Pixel clock domain
    input  logic        rst_n,     // Active-low asynchronous reset

    // Unregistered Internal Inputs
    input  logic        i_h_sync,  // Incoming Horizontal Sync
    input  logic        i_v_sync,  // Incoming Vertical Sync
    input  logic [11:0] i_rgb,     // Incoming 12-bit Pixel Data (RGB444)

    // Registered Output Signals (Drives Physical FPGA I/O Pins)
    output logic        o_h_sync,  // Registered Horizontal Sync
    output logic        o_v_sync,  // Registered Vertical Sync
    output logic [11:0] o_rgb      // Registered 12-bit RGB Data
);

    // Synchronous Registering Stage
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;     // Idle active-low sync to high state
            o_v_sync <= 1'b1;     // Idle active-low sync to high state
            o_rgb    <= 12'h000;  // Blank video output during reset
        end else begin
            o_h_sync <= i_h_sync;
            o_v_sync <= i_v_sync;
            o_rgb    <= i_rgb;
        end
    end

endmodule
