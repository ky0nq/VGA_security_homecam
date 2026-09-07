```systemverilog
`timescale 1ns/1ps
`include "defs.svh"
//======================================================================
//  hdl_top : generates clk/reset/pclk + instantiates DUT
//            + binds interfaces + calls run_test()
//======================================================================
module hdl_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import test_pkg::*;

  // ---- clocks / reset ----
  logic clk   = 1'b0;
  logic pclk  = 1'b0;
  logic reset = 1'b1;

  always #5              clk  = ~clk;    // 100 MHz
  always #(`CAM_PCLK/2)  pclk = ~pclk;   // Camera PCLK (simulation only)

  initial begin
    reset = 1'b1;
    repeat (20) @(posedge clk);
    reset = 1'b0;
  end

  // ---- interfaces ----
  ov7670_if cam_if    (.pclk(pclk));
  sccb_if   sccb_if_i ();

  // ---- DUT ----
  logic       hs, vs;
  logic [3:0] pr, pg, pb;
  logic       xclk_o;

  top_OV7670_VGA dut (
    .clk         (clk),
    .reset       (reset),
    .scale2x     (cam_if.scale2x),
    .ov7670_xclk (xclk_o),
    .ov7670_pclk (pclk),
    .ov7670_href (cam_if.href),
    .ov7670_vsync(cam_if.vsync),
    .ov7670_data (cam_if.data),
    .ov7670_sioc (sccb_if_i.sioc),
    .ov7670_siod (sccb_if_i.siod),
    .h_sync      (hs),
    .v_sync      (vs),
    .port_red    (pr),
    .port_green  (pg),
    .port_blue   (pb)
  );

  // ---- config_db : distribute virtual interfaces ----
  initial begin
    uvm_config_db#(virtual ov7670_if   )::set(null, "*", "cam_vif",  cam_if);
    uvm_config_db#(virtual sccb_if     )::set(null, "*", "sccb_vif", sccb_if_i);
    uvm_config_db#(virtual vga_probe_if)::set(null, "*", "vga_vif",  dut.u_vga_probe);
    run_test();
  end

  // ---- waveform dump (optional) : ./simv +DUMP   (Verdi FSDB) ----
  initial if ($test$plusargs("DUMP")) begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpvars(0, hdl_top, "+all");
  end

  // ---- safety timeout ----
  initial begin
    #(200_000_000);   // 200 ms
    `uvm_fatal("TIMEOUT", "Simulation timeout")
  end
endmodule
```
