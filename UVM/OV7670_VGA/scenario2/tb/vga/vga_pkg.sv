`ifndef VGA_PKG_SV
`define VGA_PKG_SV
//======================================================================
//  vga_pkg : VGA 출력 에이전트 패키지 (include 목록)
//======================================================================
package vga_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  `include "defs.svh"

  `include "vga_frame_txn.sv"
  `include "vga_monitor.sv"
  `include "vga_agent.sv"
endpackage
`endif
