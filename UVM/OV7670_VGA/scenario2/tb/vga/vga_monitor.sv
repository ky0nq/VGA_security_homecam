`ifndef VGA_MONITOR_SV
`define VGA_MONITOR_SV
//======================================================================
//  vga_monitor : vga_probe_if(bind) 에서 active 픽셀을 모아 프레임 발행
//======================================================================
class vga_monitor extends uvm_monitor;
  `uvm_component_utils(vga_monitor)
  virtual vga_probe_if vif;
  uvm_analysis_port #(vga_frame_txn) ap;
  // de/x/y 대비 RGB 파이프라인 지연 (pix_tick 단위).
  // solid 색이면 무관. gradient 가 x축으로 밀리면 0/1/2 로 조정.
  int unsigned PIPE = 0;

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual vga_probe_if)::get(this, "", "vga_vif", vif))
      `uvm_fatal("VGAMON", "vga_vif 설정 안 됨")
    void'(uvm_config_db#(int unsigned)::get(this, "", "vga_pipe", PIPE));
  endfunction

  task run_phase(uvm_phase phase);
    typedef struct { bit de; int x; int y; } sample_t;
    sample_t      q [$];
    vga_frame_txn fr   = vga_frame_txn::type_id::create("fr");
    bit           vs_d = 1'b1;

    forever begin
      @(vif.cb);

      // 프레임 경계 : v_sync 하강 에지에서 emit
      if (vs_d && !vif.cb.v_sync) begin
        ap.write(fr);
        fr = vga_frame_txn::type_id::create("fr");
        q.delete();
      end
      vs_d = vif.cb.v_sync;

      if (vif.cb.pix_tick) begin
        q.push_back('{vif.cb.de, int'(vif.cb.x_pixel), int'(vif.cb.y_pixel)});
        if (q.size() > PIPE) begin
          sample_t s = q.pop_front();
          if (s.de && s.x < fr.HD && s.y < fr.VD) begin
            int i = s.y*fr.HD + s.x;
            fr.r[i]    = vif.cb.red;
            fr.g[i]    = vif.cb.green;
            fr.b[i]    = vif.cb.blue;
            fr.seen[i] = 1'b1;
          end
        end
      end
    end
  endtask
endclass
`endif
