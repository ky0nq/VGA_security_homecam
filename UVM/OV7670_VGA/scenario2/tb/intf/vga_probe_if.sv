`timescale 1ns/1ps
//======================================================================
//  vga_probe_if : monitors internal signals of top_OV7670_VGA
//                 (inserted using bind)
//======================================================================
interface vga_probe_if (
  input logic       clk,
  input logic       reset,
  input logic       de,
  input logic       pix_tick,     // pclk (÷4) pulse inside VGA_Decoder
  input logic [9:0] x_pixel,
  input logic [9:0] y_pixel,
  input logic       h_sync,
  input logic       v_sync,
  input logic [3:0] red,
  input logic [3:0] green,
  input logic [3:0] blue
);
  // Sampling clocking block to prevent race conditions
  clocking cb @(posedge clk);
    input de, pix_tick, x_pixel, y_pixel, h_sync, v_sync, red, green, blue;
  endclocking
endinterface
