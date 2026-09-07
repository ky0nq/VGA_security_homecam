`ifndef SCCB_TXN_SV
`define SCCB_TXN_SV
//======================================================================
//  sccb_txn : SCCB 3바이트 write 한 건
//======================================================================
class sccb_txn extends uvm_sequence_item;
  bit [7:0] id;      // 0x42
  bit [7:0] addr;    // 레지스터 주소
  bit [7:0] data;    // 값
  `uvm_object_utils(sccb_txn)
  function new(string name="sccb_txn"); super.new(name); endfunction
  function string convert2string();
    return $sformatf("SCCB id=%02h addr=%02h data=%02h", id, addr, data);
  endfunction
endclass
`endif
