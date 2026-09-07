`ifndef RESET_MID_TEST_SV
`define RESET_MID_TEST_SV
//======================================================================
//  reset_mid_test : pulses the DUT reset during an SCCB write.
//    Purpose = cover one representative transition of the I2C_Master FSM
//              from a non-IDLE state -> S_IDLE by asynchronous reset.
//              The remaining reset arcs are handled as exclusions.
//    Since the class is defined inside a package, direct hierarchical
//    references are not allowed, so uvm_hdl_force/release is used.
//    (Requires compilation with -debug_access+all)
//======================================================================
class reset_mid_test extends base_test;
  `uvm_component_utils(reset_mid_test)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  task run_phase(uvm_phase phase);
    solid_frame_seq seq = solid_frame_seq::type_id::create("seq");
    seq.color   = 16'h07E0;
    seq.n_frame = 6;                 // Allow enough clean frames after reset disturbance

    phase.raise_objection(this, "reset_mid_test");

    fork
      seq.start(env.cam.sqr);
      begin
        // During the first write after START_DELAY (1 ms)
        // -> I2C_Master is expected to be in S_BIT/S_ACK
        #1_050_000;                                    // ns = 1.05 ms

        `uvm_info("RSTMID",
          "pulse hdl_top.reset ~5 clk (mid SCCB write)",
          UVM_LOW)

        if (!uvm_hdl_force("hdl_top.reset", 1'b1))
          `uvm_error("RSTMID",
            "uvm_hdl_force(hdl_top.reset) failed - check -debug_access")

        #50;                                           // Keep reset high for ~5 clocks
        void'(uvm_hdl_force("hdl_top.reset", 1'b0));
        #10;
        void'(uvm_hdl_release("hdl_top.reset"));
      end
    join

    repeat (4) wait_one_vga_frame();
    phase.drop_objection(this, "reset_mid_test");
  endtask
endclass
`endif
