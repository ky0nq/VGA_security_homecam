`ifndef GRADIENT_TEST_SV
`define GRADIENT_TEST_SV
//======================================================================
//  gradient_test : 그라디언트 프레임 (PIPE 튜닝 확인용)
//======================================================================
class gradient_test extends base_test;
  `uvm_component_utils(gradient_test)
  function new(string n, uvm_component p); super.new(n, p); endfunction

  task run_phase(uvm_phase phase);
    gradient_frame_seq seq = gradient_frame_seq::type_id::create("seq");
    seq.n_frame = 4;
    phase.raise_objection(this, "gradient_test");
    seq.start(env.cam.sqr);
    repeat (3) wait_one_vga_frame();
    phase.drop_objection(this, "gradient_test");
  endtask
endclass
`endif
