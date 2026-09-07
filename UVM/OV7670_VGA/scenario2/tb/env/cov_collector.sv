`ifndef COV_COLLECTOR_SV
`define COV_COLLECTOR_SV
//======================================================================
//  cov_collector : functional coverage
//    Connected to the analysis ports of cam_monitor / vga_monitor / sccb_monitor
//    (The same ports are shared with the scoreboard/predictor - analysis supports 1:N)
//
//  Notes
//   - cg_config(scale2x) has only one value per run.
//     -> 100% coverage is achieved after merging the base and scale2x runs.
//   - The cross coverage (27 bins) in cg_cam_color is fully covered
//     only by gradient_test. (solid fills only one bin)
//======================================================================
class cov_collector extends uvm_component;
  `uvm_component_utils(cov_collector)

  uvm_analysis_imp_cam  #(cam_frame_item, cov_collector) cam_imp;
  uvm_analysis_imp_act  #(vga_frame_txn,  cov_collector) act_imp;
  uvm_analysis_imp_sccb #(sccb_txn,       cov_collector) sccb_imp;

  bit       cfg_scale2x;      // Set by the environment

  // ---- scratch sample ----
  bit [4:0] s_r, s_b;
  bit [5:0] s_g;
  int       s_x, s_y;
  bit [7:0] s_reg, s_val;

  //------------------------------------------------ config
  covergroup cg_config;
    option.per_instance = 1;
    cp_scale2x : coverpoint cfg_scale2x { bins x1 = {0}; bins x2 = {1}; }
  endgroup

  //------------------------------------------------ 
  covergroup cg_cam_color;
    option.per_instance = 1;
    cp_r : coverpoint s_r { bins lo = {[0:7]};  bins mid = {[8:23]};  bins hi = {[24:31]}; }
    cp_g : coverpoint s_g { bins lo = {[0:15]}; bins mid = {[16:47]}; bins hi = {[48:63]}; }
    cp_b : coverpoint s_b { bins lo = {[0:7]};  bins mid = {[8:23]};  bins hi = {[24:31]}; }
    x_rgb : cross cp_r, cp_g, cp_b;    // Covered only by gradient_test
  endgroup

  //------------------------------------------------ VGA output region × scale2x
  covergroup cg_vga_region;
    option.per_instance = 1;
    cp_xr : coverpoint s_x {
      bins x0    = {0};
      bins x_in  = {[1:318]};
      bins x_end = {319};
      bins x_out = {[320:639]};       // Black region when scale2x = 0
    }
    cp_yr : coverpoint s_y {
      bins y0    = {0};
      bins y_in  = {[1:238]};
      bins y_end = {239};
      bins y_out = {[240:479]};
    }
    cp_s2x : coverpoint cfg_scale2x { bins x1 = {0}; bins x2 = {1}; }
    x_region : cross cp_xr, cp_yr, cp_s2x;   // 4×4×2 = 32, covered by merging two runs
  endgroup

  //------------------------------------------------ SCCB
  covergroup cg_sccb;
    option.per_instance = 1;
    cp_reg : coverpoint s_reg {
      bins COM7    = {8'h12};
      bins COM3    = {8'h0C};
      bins COM8    = {8'h13};
      bins COM10   = {8'h15};
      bins COM14   = {8'h3E};
      bins COM15   = {8'h40};
      bins CLKRC   = {8'h11};
      bins MVFP    = {8'h1E};
      bins SCALING = {[8'h70:8'h73], 8'hA2};
      bins others  = default;
    }
    cp_soft_reset : coverpoint ((s_reg == 8'h12) && (s_val == 8'h80)) { bins yes = {1}; }
  endgroup

  //------------------------------------------------
  function new(string n, uvm_component p);
    super.new(n, p);
    cam_imp  = new("cam_imp",  this);
    act_imp  = new("act_imp",  this);
    sccb_imp = new("sccb_imp", this);
    cg_config     = new();
    cg_cam_color  = new();
    cg_vga_region = new();
    cg_sccb       = new();
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    cg_config.sample();
  endfunction

  // ----- Camera frame: densely sampled on an 8×8 grid to fill the color cross -----
  function void write_cam(cam_frame_item f);
    for (int gy = 0; gy < 8; gy++)
      for (int gx = 0; gx < 8; gx++) begin
        int x = gx * (f.H / 8);
        int y = gy * (f.V / 8);
        bit [15:0] p = f.px[y*f.H + x];
        s_r = p[15:11]; s_g = p[10:5]; s_b = p[4:0];
        cg_cam_color.sample();
      end
  endfunction

  // ----- VGA frame: nested loop over representative x/y values,
  //       sampling only pixels that were actually observed (seen) -----
  function void write_act(vga_frame_txn a);
    int xs [4] = '{0, 160, 319, 500};      // x0 / x_in / x_end / x_out
    int ys [4] = '{0, 120, 239, 300};      // y0 / y_in / y_end / y_out
    foreach (xs[xi])
      foreach (ys[yi]) begin
        int idx = ys[yi]*a.HD + xs[xi];
        if ((idx < a.HD*a.VD) && a.seen[idx]) begin
          s_x = xs[xi];
          s_y = ys[yi];
          cg_vga_region.sample();
        end
      end
  endfunction

  function void write_sccb(sccb_txn t);
    s_reg = t.addr; s_val = t.data;
    cg_sccb.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf(
      "config=%0.1f%%  cam_color=%0.1f%%  vga_region=%0.1f%%  sccb=%0.1f%%",
      cg_config.get_inst_coverage(),  cg_cam_color.get_inst_coverage(),
      cg_vga_region.get_inst_coverage(), cg_sccb.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
`endif
