`ifndef ENV_CFG_SV
`define ENV_CFG_SV
//======================================================================
//  env_cfg
//======================================================================
class env_cfg extends uvm_object;
  `uvm_object_utils(env_cfg)
  bit scale2x       = 1'b0;
  int warmup_frames = 2;   
  function new(string name="env_cfg"); super.new(name); endfunction
endclass
`endif
