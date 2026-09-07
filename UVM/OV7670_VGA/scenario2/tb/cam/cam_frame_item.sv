`ifndef CAM_FRAME_ITEM_SV
`define CAM_FRAME_ITEM_SV
//======================================================================
//  cam_frame_item : camera one frame (RGB565)
//======================================================================
class cam_frame_item extends uvm_sequence_item;
  int        H = `CAM_H;
  int        V = `CAM_V;
  bit [15:0] px [];    // px[y*H + x] , RGB565 = {R[4:0],G[5:0],B[4:0]}
  `uvm_object_utils(cam_frame_item)

  function new(string name="cam_frame_item");
    super.new(name);
    px = new[H*V];
  endfunction

  function void fill_solid(bit [15:0] c);
    foreach (px[i]) px[i] = c;
  endfunction

  function void fill_gradient();
    for (int y = 0; y < V; y++)
      for (int x = 0; x < H; x++) begin
        bit [4:0] r = x[4:0];
        bit [5:0] g = y[5:0];
        bit [4:0] b = (x + y);
        px[y*H + x] = {r, g, b};
      end
  endfunction
endclass
`endif
