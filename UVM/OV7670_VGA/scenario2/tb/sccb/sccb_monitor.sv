`ifndef SCCB_MONITOR_SV
`define SCCB_MONITOR_SV
//======================================================================
//  sccb_monitor : decodes START -> [8-bit + ACK]x3 -> STOP
//======================================================================
class sccb_monitor extends uvm_monitor;
  `uvm_component_utils(sccb_monitor)
  virtual sccb_if vif;
  uvm_analysis_port #(sccb_txn) ap;

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual sccb_if)::get(this, "", "sccb_vif", vif))
      `uvm_fatal("SCCBMON", "sccb_vif is not configured")
  endfunction

  task run_phase(uvm_phase phase);
    forever collect_write();
  endtask

  task collect_write();
    bit [7:0] b [3];

    // START : SIOD falling edge while SIOC is high
    @(negedge vif.siod);
    if (vif.sioc !== 1'b1) return;          // Data bit transition -> retry

    for (int i = 0; i < 3; i++) begin
      for (int k = 0; k < 8; k++) begin
        @(posedge vif.sioc);
        b[i][7-k] = vif.siod;
      end
      @(posedge vif.sioc);                  // 9th clock (ACK)
    end

    // STOP : SIOD rising edge while SIOC is high
    @(posedge vif.siod iff (vif.sioc === 1'b1));

    begin
      sccb_txn t = sccb_txn::type_id::create("t");
      t.id   = b[0];
      t.addr = b[1];
      t.data = b[2];
      ap.write(t);
      `uvm_info("SCCBMON", t.convert2string(), UVM_HIGH)
    end
  endtask
endclass
`endif
