`timescale 1ns/1ps
//======================================================================
//  Inserts a monitoring interface inside top_OV7670_VGA.
//  (VGA_Decoder does not expose de / pixel coordinates / pixel tick
//   to the top-level output ports.)
//======================================================================
bind top_OV7670_VGA vga_probe_if u_vga_probe (
  .clk      (clk),
  .reset    (reset),
  .de       (w_de),
  .pix_tick (U_VGA_DECODER.pclk),   // Internal pclk wire of the VGA_Decoder wrapper
  .x_pixel  (w_x),
  .y_pixel  (w_y),
  .h_sync   (h_sync),
  .v_sync   (v_sync),
  .red      (port_red),
  .green    (port_green),
  .blue     (port_blue)
);
