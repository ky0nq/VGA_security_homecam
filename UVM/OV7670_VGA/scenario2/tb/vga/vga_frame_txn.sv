`ifndef VGA_FRAME_TXN_SV
`define VGA_FRAME_TXN_SV
//======================================================================
//  vga_frame_txn : 관측된 VGA 한 프레임 (active 영역)
//======================================================================
class vga_frame_txn extends uvm_sequence_item;
  int       HD = `VGA_HACT;
  int       VD = `VGA_VACT;
  bit [3:0] r [];
  bit [3:0] g [];
  bit [3:0] b [];
  bit       seen [];
  `uvm_object_utils(vga_frame_txn)
  function new(string name="vga_frame_txn");
    super.new(name);
    r    = new[HD*VD];
    g    = new[HD*VD];
    b    = new[HD*VD];
    seen = new[HD*VD];
  endfunction
endclass
`endif
