`timescale 1ns/1ps
//======================================================================
//  vga_probe_if : top_OV7670_VGA 내부 신호 관측 (bind 로 삽입)
//======================================================================
interface vga_probe_if (
  input logic       clk,
  input logic       reset,
  input logic       de,
  input logic       pix_tick,     // VGA_Decoder 내부 pclk(÷4) 펄스
  input logic [9:0] x_pixel,
  input logic [9:0] y_pixel,
  input logic       h_sync,
  input logic       v_sync,
  input logic [3:0] red,
  input logic [3:0] green,
  input logic [3:0] blue
);
  // race 방지용 샘플링 클로킹 블록
  clocking cb @(posedge clk);
    input de, pix_tick, x_pixel, y_pixel, h_sync, v_sync, red, green, blue;
  endclocking
endinterface
