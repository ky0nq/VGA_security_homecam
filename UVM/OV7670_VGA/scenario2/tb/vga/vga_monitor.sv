`ifndef VGA_MONITOR_SV
`define VGA_MONITOR_SV
//======================================================================
//  vga_monitor : collects active pixels from vga_probe_if (bind)
//                and publishes one VGA frame
//======================================================================
class vga_monitor extends uvm_monitor;
  `uvm_component_utils(vga_monitor)

  virtual vga_probe_if vif;
  uvm_analysis_port #(vga_frame_txn) ap;

  // RGB pipeline delay relative to de/x/y (in pix_tick units).
  // This does not matter for solid colors.
  // If the gradient is shifted along the x-axis, adjust to 0/1/2.
  int unsigned PIPE = 0;

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual vga_probe_if)::get(this, "", "vga_vif", vif))
      `uvm_fatal("VGAMON", "vga_vif is not configured")

    void'(uvm_config_db#(int unsigned)::get(this, "", "vga_pipe", PIPE));
  endfunction

  task run_phase(uvm_phase phase);
    typedef struct { bit de; int x; int y; } sample_t;
    sample_t      q [$];
    vga_frame_txn fr   = vga_frame_txn::type_id::create("fr");
    bit           vs_d = 1'b1;

    forever begin
      @(vif.cb);

      // Frame boundary: emit the frame on the falling edge of v_sync
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
