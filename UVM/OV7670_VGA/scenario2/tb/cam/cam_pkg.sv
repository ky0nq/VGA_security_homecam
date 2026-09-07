`ifndef CAM_PKG_SV
`define CAM_PKG_SV
//======================================================================
//  cam_pkg : 카메라(OV7670) 에이전트 패키지 (include 목록)
//======================================================================
package cam_pkg;
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  `include "defs.svh"

  `include "cam_cfg.sv"
  `include "cam_frame_item.sv"
  `include "cam_sequencer.sv"
  `include "cam_driver.sv"
  `include "cam_monitor.sv"
  `include "cam_agent.sv"
  `include "cam_seq_lib.sv"
endpackage
`endif
