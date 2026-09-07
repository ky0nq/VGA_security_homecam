`ifndef CAM_MONITOR_SV
`define CAM_MONITOR_SV
//======================================================================
//  cam_monitor : frame reconstruction -> analysis_port
//======================================================================
class cam_monitor extends uvm_monitor;
  `uvm_component_utils(cam_monitor)
  virtual ov7670_if vif;
  uvm_analysis_port #(cam_frame_item) ap;

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual ov7670_if)::get(this, "", "cam_vif", vif))
      `uvm_fatal("CAMMON", "cam_vif 설정 안 됨")
  endfunction

  task run_phase(uvm_phase phase);
    bit       bsel = 1'b0;
    bit [7:0] hi   = 8'h00;
    int       idx  = 0;
    cam_frame_item f = cam_frame_item::type_id::create("f");
    forever begin
      @(vif.cbm);
      if (vif.cbm.vsync) begin
        bsel = 1'b0;
        idx  = 0;
      end
      else if (vif.cbm.href) begin
        if (!bsel) begin
          hi   = vif.cbm.data;
          bsel = 1'b1;
        end
        else begin
          bsel = 1'b0;
          if (idx < f.H*f.V) f.px[idx++] = {hi, vif.cbm.data};
          if (idx == f.H*f.V) begin
            ap.write(f);
            f   = cam_frame_item::type_id::create("f");
            idx = 0;
          end
        end
      end
      else begin
        bsel = 1'b0;
      end
    end
  endtask
endclass
`endif
