`ifndef SCCB_PKG_SV
`define SCCB_PKG_SV
//======================================================================
//  sccb_pkg : SCCB 에이전트 패키지 (include 목록)
//======================================================================
package sccb_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;

  `include "sccb_txn.sv"
  `include "sccb_monitor.sv"
  `include "sccb_agent.sv"
endpackage
`endif
