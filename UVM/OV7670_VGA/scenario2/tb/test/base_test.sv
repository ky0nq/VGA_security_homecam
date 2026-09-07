`ifndef BASE_TEST_SV
`define BASE_TEST_SV
//======================================================================
//  base_test : solid green frame
//======================================================================
class base_test extends uvm_test;
  `uvm_component_utils(base_test)
  ov7670_vga_env env;
  env_cfg        cfg;

  function new(string n, uvm_component p); super.new(n, p); endfunction

  function void build_phase(uvm_phase phase);
    cfg = env_cfg::type_id::create("cfg");
    configure(cfg);
    uvm_config_db#(env_cfg)::set(this, "env", "env_cfg", cfg);
    env = ov7670_vga_env::type_id::create("env", this);
  endfunction
  
  // Overridden by derived tests
  virtual function void configure(env_cfg c);
    c.scale2x       = 1'b0;
    c.warmup_frames = 2;
  endfunction

  task run_phase(uvm_phase phase);
    solid_frame_seq seq = solid_frame_seq::type_id::create("seq");
    seq.color   = 16'h07E0;   // R=0 G=63 B=0
    seq.n_frame = 4;
    phase.raise_objection(this, "base_test");
    seq.start(env.cam.sqr);
    repeat (3) wait_one_vga_frame();
    phase.drop_objection(this, "base_test");
  endtask

  task wait_one_vga_frame();
    @(negedge env.vga.mon.vif.v_sync);
  endtask
endclass
`endif
