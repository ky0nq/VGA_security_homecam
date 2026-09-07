`ifndef V_SEQUENCER_SV
`define V_SEQUENCER_SV
//======================================================================
//  v_sequencer : virtual sequencer (cam_sequencer 핸들 보유)
//======================================================================
class v_sequencer extends uvm_sequencer;
  `uvm_component_utils(v_sequencer)
  cam_sequencer cam_sqr;
  function new(string n, uvm_component p); super.new(n, p); endfunction
endclass
`endif
