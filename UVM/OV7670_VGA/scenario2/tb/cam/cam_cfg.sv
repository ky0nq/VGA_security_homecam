`ifndef CAM_CFG_SV
`define CAM_CFG_SV
//======================================================================
//  cam_cfg : 카메라 에이전트 설정
//======================================================================
class cam_cfg extends uvm_object;
  `uvm_object_utils(cam_cfg)
  bit scale2x   = 1'b0;
  int vsync_len = 8;    // vsync 유지 pclk 수
  int vs_gap    = 4;    // vsync 해제 후 첫 href 까지
  int hblank    = 6;    // 행 사이 href low
  int frame_gap = 16;   // 프레임 사이
  function new(string name="cam_cfg"); super.new(name); endfunction
endclass
`endif
