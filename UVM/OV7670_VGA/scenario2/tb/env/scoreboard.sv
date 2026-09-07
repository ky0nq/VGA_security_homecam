`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV
//======================================================================
//  scoreboard : 기대 vs 실제 VGA 프레임 비교 + SCCB 첫 write 체크
//======================================================================
class scoreboard extends uvm_component;
  `uvm_component_utils(scoreboard)
  uvm_analysis_imp_exp  #(vga_frame_txn, scoreboard) exp_imp;
  uvm_analysis_imp_act  #(vga_frame_txn, scoreboard) act_imp;
  uvm_analysis_imp_sccb #(sccb_txn,      scoreboard) sccb_imp;

  env_cfg       cfg;
  vga_frame_txn last_exp;
  int           n_act, n_match, n_sccb;
  sccb_txn      first_sccb, last_sccb;

  function new(string n, uvm_component p);
    super.new(n, p);
    exp_imp  = new("exp_imp",  this);
    act_imp  = new("act_imp",  this);
    sccb_imp = new("sccb_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", cfg))
      cfg = env_cfg::type_id::create("cfg");
  endfunction

  function void write_exp(vga_frame_txn e);
    last_exp = e;
  endfunction

  function void write_sccb(sccb_txn t);
    if (n_sccb == 0) first_sccb = t;
    last_sccb = t;
    n_sccb++;
  endfunction

  function void write_act(vga_frame_txn a);
    int miss;
    int first_i;
    int x, y;
    n_act++;
    if (last_exp == null) return;
    if (n_act <= cfg.warmup_frames) begin
      `uvm_info("SB", $sformatf("warm-up 프레임 #%0d 무시", n_act), UVM_MEDIUM)
      return;
    end
    miss    = 0;
    first_i = -1;
    foreach (a.seen[i]) begin
      if (!a.seen[i]) continue;
      if (a.r[i] !== last_exp.r[i] ||
          a.g[i] !== last_exp.g[i] ||
          a.b[i] !== last_exp.b[i]) begin
        if (first_i < 0) first_i = i;
        miss++;
      end
    end
    if (miss != 0) begin
      x = first_i % a.HD;
      y = first_i / a.HD;
      `uvm_error("SB", $sformatf(
        "VGA 프레임#%0d 불일치 %0d px : 첫 (%0d,%0d) got=%1h%1h%1h exp=%1h%1h%1h",
        n_act, miss, x, y,
        a.r[first_i], a.g[first_i], a.b[first_i],
        last_exp.r[first_i], last_exp.g[first_i], last_exp.b[first_i]))
    end
    else begin
      n_match++;
      `uvm_info("SB", $sformatf("VGA 프레임#%0d 일치 (OK)", n_act), UVM_LOW)
    end
  endfunction

  function void check_phase(uvm_phase phase);
    if (n_match == 0)
      `uvm_error("SB", "일치한 VGA 프레임이 하나도 없음")
    if (n_sccb == 0)
      `uvm_warning("SB", "SCCB write 관측 안 됨 (시뮬 시간이 짧으면 정상)")
    else begin
      `uvm_info("SB", $sformatf("SCCB write %0d 개  first={%02h,%02h} last={%02h,%02h}",
        n_sccb, first_sccb.addr, first_sccb.data, last_sccb.addr, last_sccb.data), UVM_LOW)
      if (first_sccb.id !== 8'h42)
        `uvm_error("SB", "첫 SCCB ID 바이트가 0x42 가 아님")
      if (first_sccb.addr !== 8'h12 || first_sccb.data !== 8'h80)
        `uvm_error("SB", "첫 SCCB write 가 COM7(0x12)=0x80 이 아님")
    end
  endfunction
endclass
`endif
