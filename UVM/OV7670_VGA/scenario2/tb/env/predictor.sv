`ifndef PREDICTOR_SV
`define PREDICTOR_SV
//======================================================================
//  predictor : 카메라 프레임 + scale2x -> 기대 VGA 프레임 (RGB565 -> RGB444)
//======================================================================
class predictor extends uvm_component;
  `uvm_component_utils(predictor)
  uvm_analysis_imp_cam #(cam_frame_item, predictor) cam_imp;
  uvm_analysis_port    #(vga_frame_txn)             exp_ap;
  bit scale2x = 1'b0;

  function new(string n, uvm_component p);
    super.new(n, p);
    cam_imp = new("cam_imp", this);
    exp_ap  = new("exp_ap",  this);
  endfunction

  function void write_cam(cam_frame_item f);
    vga_frame_txn e = vga_frame_txn::type_id::create("e");
    for (int y = 0; y < e.VD; y++)
      for (int x = 0; x < e.HD; x++) begin
        int sx = scale2x ? (x >> 1) : x;
        int sy = scale2x ? (y >> 1) : y;
        int i  = y*e.HD + x;
        if (sx < f.H && sy < f.V) begin
          bit [15:0] p = f.px[sy*f.H + sx];
          e.r[i] = p[15:12];
          e.g[i] = p[10:7];
          e.b[i] = p[4:1];
        end
        else begin
          e.r[i] = 4'h0; e.g[i] = 4'h0; e.b[i] = 4'h0;
        end
        e.seen[i] = 1'b1;
      end
    exp_ap.write(e);
  endfunction
endclass
`endif
