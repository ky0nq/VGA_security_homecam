`ifndef OV7670_VGA_ENV_SV
`define OV7670_VGA_ENV_SV
//======================================================================
//  ov7670_vga_env : agent 3 + predictor + scoreboard + v_sequencer
//======================================================================
class ov7670_vga_env extends uvm_env;
  `uvm_component_utils(ov7670_vga_env)
  env_cfg       cfg;
  cam_agent     cam;
  sccb_agent    sccb;
  vga_agent     vga;
  predictor     pred;
  scoreboard    sb;
  cov_collector cov;
  v_sequencer   v_sqr;

  function new(string n, uvm_component p); super.new(n, p); endfunction

  function void build_phase(uvm_phase phase);
    cam_cfg ccfg;
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", cfg))
      cfg = env_cfg::type_id::create("cfg");
    uvm_config_db#(env_cfg)::set(this, "sb", "env_cfg", cfg);

    ccfg = cam_cfg::type_id::create("ccfg");
    ccfg.scale2x = cfg.scale2x;
    uvm_config_db#(cam_cfg)::set(this, "cam", "cam_cfg", ccfg);

    cam   = cam_agent    ::type_id::create("cam",   this);
    sccb  = sccb_agent   ::type_id::create("sccb",  this);
    vga   = vga_agent    ::type_id::create("vga",   this);
    pred  = predictor    ::type_id::create("pred",  this);
    sb    = scoreboard   ::type_id::create("sb",    this);
    cov   = cov_collector::type_id::create("cov",   this);
    v_sqr = v_sequencer  ::type_id::create("v_sqr", this);

    pred.scale2x    = cfg.scale2x;
    cov.cfg_scale2x = cfg.scale2x;
  endfunction

  function void connect_phase(uvm_phase phase);
    cam.mon.ap.connect(pred.cam_imp);
    pred.exp_ap.connect(sb.exp_imp);
    vga.mon.ap.connect(sb.act_imp);
    sccb.mon.ap.connect(sb.sccb_imp);
    
    // functional coverage : port sharing
    
    cam.mon.ap.connect(cov.cam_imp);
    vga.mon.ap.connect(cov.act_imp);
    sccb.mon.ap.connect(cov.sccb_imp);
    v_sqr.cam_sqr = cam.sqr;
  endfunction
endclass
`endif
