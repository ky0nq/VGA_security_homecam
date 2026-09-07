`ifndef CAM_AGENT_SV
`define CAM_AGENT_SV
//======================================================================
//  cam_agent : ACTIVE (driver + sequencer + monitor)
//======================================================================
class cam_agent extends uvm_agent;
  `uvm_component_utils(cam_agent)
  cam_driver    drv;
  cam_monitor   mon;
  cam_sequencer sqr;
  cam_cfg       cfg;

  function new(string n, uvm_component p); super.new(n, p); endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(cam_cfg)::get(this, "", "cam_cfg", cfg))
      cfg = cam_cfg::type_id::create("cfg");
    uvm_config_db#(cam_cfg)::set(this, "drv", "cam_cfg", cfg);

    mon = cam_monitor::type_id::create("mon", this);
    if (get_is_active() == UVM_ACTIVE) begin
      drv = cam_driver   ::type_id::create("drv", this);
      sqr = cam_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE)
      drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
`endif
