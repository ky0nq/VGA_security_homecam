`ifndef CAM_DRIVER_SV
`define CAM_DRIVER_SV
//======================================================================
//  cam_driver : cam_frame_item -> OV7670 QVGA RGB565 timing
//======================================================================
class cam_driver extends uvm_driver #(cam_frame_item);
  `uvm_component_utils(cam_driver)
  virtual ov7670_if vif;
  cam_cfg           cfg;

  function new(string n, uvm_component p); super.new(n, p); endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual ov7670_if)::get(this, "", "cam_vif", vif))
      `uvm_fatal("CAMDRV", "cam_vif 설정 안 됨")
    if (!uvm_config_db#(cam_cfg)::get(this, "", "cam_cfg", cfg))
      cfg = cam_cfg::type_id::create("cfg");
  endfunction

  task run_phase(uvm_phase phase);
    vif.scale2x = cfg.scale2x;
    vif.cb.href  <= 1'b0;
    vif.cb.vsync <= 1'b0;
    vif.cb.data  <= 8'h00;
    forever begin
      cam_frame_item f;
      seq_item_port.get_next_item(f);
      drive_frame(f);
      seq_item_port.item_done();
    end
  endtask

  task drive_frame(cam_frame_item f);
    @(vif.cb); vif.cb.vsync <= 1'b1; vif.cb.href <= 1'b0;
    repeat (cfg.vsync_len) @(vif.cb);
    vif.cb.vsync <= 1'b0;
    repeat (cfg.vs_gap) @(vif.cb);

    for (int y = 0; y < f.V; y++) begin
      vif.cb.href <= 1'b1;
      for (int x = 0; x < f.H; x++) begin
        bit [15:0] p = f.px[y*f.H + x];
        vif.cb.data <= p[15:8]; @(vif.cb);   // 1st byte (hi)
        vif.cb.data <= p[7:0];  @(vif.cb);   // 2nd byte (lo) -> DUT write
      end
      vif.cb.href <= 1'b0;
      repeat (cfg.hblank) @(vif.cb);
    end
    repeat (cfg.frame_gap) @(vif.cb);
  endtask
endclass
`endif
