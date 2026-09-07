`ifndef RESET_MID_TEST_SV
`define RESET_MID_TEST_SV
//======================================================================
//  reset_mid_test : SCCB write 도중 DUT reset 을 펄스한다.
//    목적 = I2C_Master FSM 의 "비-IDLE 상태 -> S_IDLE (async reset)"
//           천이 대표 1건을 커버. 나머지 reset 아크는 exclusion 처리.
//    package 안 클래스라 계층 직접참조가 안 되므로 uvm_hdl_force/release 사용.
//    (컴파일에 -debug_access+all 이 있어야 동작)
//======================================================================
class reset_mid_test extends base_test;
  `uvm_component_utils(reset_mid_test)
  function new(string n, uvm_component p); super.new(n, p); endfunction

  task run_phase(uvm_phase phase);
    solid_frame_seq seq = solid_frame_seq::type_id::create("seq");
    seq.color   = 16'h07E0;
    seq.n_frame = 6;                 // reset 교란 뒤 깨끗한 프레임 여유
    phase.raise_objection(this, "reset_mid_test");

    fork
      seq.start(env.cam.sqr);
      begin
        // START_DELAY(1 ms) 뒤 첫 write 진행 중 -> I2C_Master 는 S_BIT/S_ACK
        #1_050_000;                                    // ns = 1.05 ms
        `uvm_info("RSTMID", "pulse hdl_top.reset ~5 clk (mid SCCB write)", UVM_LOW)
        if (!uvm_hdl_force("hdl_top.reset", 1'b1))
          `uvm_error("RSTMID", "uvm_hdl_force(hdl_top.reset) 실패 - -debug_access 확인")
        #50;                                           // ~5 clk high
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
