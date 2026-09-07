`ifndef TEST_PKG_SV
`define TEST_PKG_SV
//======================================================================
//  test_pkg : 테스트 라이브러리 (include 목록)
//    실행 :  ./simv +UVM_TESTNAME=base_test
//======================================================================
package test_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import cam_pkg::*;
  import env_pkg::*;
  `include "defs.svh"

  `include "base_test.sv"
  `include "scale2x_test.sv"
  `include "gradient_test.sv"
  `include "reset_mid_test.sv"
endpackage
`endif
