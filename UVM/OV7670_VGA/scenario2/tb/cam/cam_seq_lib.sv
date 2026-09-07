`ifndef CAM_SEQ_LIB_SV
`define CAM_SEQ_LIB_SV
//======================================================================
//  cam sequence library
//======================================================================
class solid_frame_seq extends uvm_sequence #(cam_frame_item);
  `uvm_object_utils(solid_frame_seq)
  bit [15:0] color   = 16'h07E0;   // R=0 G=63 B=0
  int        n_frame = 4;
  function new(string name="solid_frame_seq"); super.new(name); endfunction
  task body();
    repeat (n_frame) begin
      cam_frame_item f = cam_frame_item::type_id::create("f");
      f.fill_solid(color);
      start_item(f); finish_item(f);
    end
  endtask
endclass

class gradient_frame_seq extends uvm_sequence #(cam_frame_item);
  `uvm_object_utils(gradient_frame_seq)
  int n_frame = 4;
  function new(string name="gradient_frame_seq"); super.new(name); endfunction
  task body();
    repeat (n_frame) begin
      cam_frame_item f = cam_frame_item::type_id::create("f");
      f.fill_gradient();
      start_item(f); finish_item(f);
    end
  endtask
endclass
`endif
