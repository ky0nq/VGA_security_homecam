`ifndef CAM_CFG_SV
`define CAM_CFG_SV
//======================================================================
//  cam_cfg : cam agent setting
//======================================================================
class cam_cfg extends uvm_object;
  `uvm_object_utils(cam_cfg)
  bit scale2x   = 1'b0;
  int vsync_len = 8;    
  int vs_gap    = 4;    
  int hblank    = 6;  
  int frame_gap = 16;   
  function new(string name="cam_cfg"); super.new(name); endfunction
endclass
`endif
