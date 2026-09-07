`ifndef SCCB_AGENT_SV
`define SCCB_AGENT_SV
//======================================================================
//  sccb_agent : PASSIVE (monitor 만)
//======================================================================
class sccb_agent extends uvm_agent;
  `uvm_component_utils(sccb_agent)
  sccb_monitor mon;
  function new(string n, uvm_component p); super.new(n, p); endfunction
  function void build_phase(uvm_phase phase);
    mon = sccb_monitor::type_id::create("mon", this);
  endfunction
endclass
`endif
