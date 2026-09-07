`timescale 1ns/1ps
//======================================================================
// ov7670_if : camera pixel stream (driven by the testbench) + scale2x
//======================================================================
interface ov7670_if (input logic pclk);
  logic       href    = 1'b0;
  logic       vsync   = 1'b0;
  logic [7:0] data    = 8'h00;
  logic       scale2x = 1'b0;

  // DUT(MEM_CONTROLLER)는 posedge pclk 에서 샘플 -> negedge 에 구동
  clocking cb @(negedge pclk);
    default output #0;
    output href, vsync, data;
  endclocking

  // 모니터는 DUT 와 동일하게 posedge pclk 에서 관측
  clocking cbm @(posedge pclk);
    input href, vsync, data;
  endclocking

  modport DRV (clocking cb,  output scale2x);
  modport MON (clocking cbm, input  scale2x);
endinterface
