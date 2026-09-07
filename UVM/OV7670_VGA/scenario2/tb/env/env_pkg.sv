`ifndef ENV_PKG_SV
`define ENV_PKG_SV
//======================================================================
//  env_pkg : predictor + scoreboard + env (include 목록)
//======================================================================
package env_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  import cam_pkg::*;
  import sccb_pkg::*;
  import vga_pkg::*;
  `include "defs.svh"

  `include "analysis_imps.svh"    // uvm_analysis_imp_decl (클래스보다 먼저)
  `include "env_cfg.sv"
  `include "predictor.sv"
  `include "scoreboard.sv"
  `include "cov_collector.sv"
  `include "v_sequencer.sv"
  `include "ov7670_vga_env.sv"
endpackage
`endif
