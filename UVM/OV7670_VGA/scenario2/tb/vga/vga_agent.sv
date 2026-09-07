`ifndef VGA_AGENT_SV
`define VGA_AGENT_SV
//======================================================================
//  vga_agent : PASSIVE (monitor 만)
//======================================================================
class vga_agent extends uvm_agent;
  `uvm_component_utils(vga_agent)
  vga_monitor mon;
  function new(string n, uvm_component p); super.new(n, p); endfunction
  function void build_phase(uvm_phase phase);
    mon = vga_monitor::type_id::create("mon", this);
  endfunction
endclass
`endif
