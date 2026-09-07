`timescale 1ns/1ps
//======================================================================
//  top_OV7670_VGA 내부에 관측 인터페이스를 삽입한다.
//  ( VGA_Decoder 가 de / 픽셀좌표 / 픽셀틱을 밖으로 안 내보내므로 )
//======================================================================
bind top_OV7670_VGA vga_probe_if u_vga_probe (
  .clk      (clk),
  .reset    (reset),
  .de       (w_de),
  .pix_tick (U_VGA_DECODER.pclk),   // VGA_Decoder wrapper 내부 pclk 와이어
  .x_pixel  (w_x),
  .y_pixel  (w_y),
  .h_sync   (h_sync),
  .v_sync   (v_sync),
  .red      (port_red),
  .green    (port_green),
  .blue     (port_blue)
);
