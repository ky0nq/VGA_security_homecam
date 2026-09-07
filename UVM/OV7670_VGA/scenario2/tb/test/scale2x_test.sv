`ifndef SCALE2X_TEST_SV
`define SCALE2X_TEST_SV
//======================================================================
//  scale2x_test : scale2x = 1
//======================================================================
class scale2x_test extends base_test;
  `uvm_component_utils(scale2x_test)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function void configure(env_cfg c);
    super.configure(c);
    c.scale2x = 1'b1;
  endfunction
endclass
`endif
