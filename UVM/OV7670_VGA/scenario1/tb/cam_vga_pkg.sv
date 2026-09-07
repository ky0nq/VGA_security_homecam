`timescale 1ns/1ps
package cam_vga_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "cam_vga_seq_item.sv"
    `include "cam_vga_sequence.sv"
    `include "cam_vga_driver.sv"
    `include "cam_vga_monitor.sv"
    `include "cam_vga_agent.sv"
    `include "cam_vga_scoreboard.sv"
    `include "cam_vga_coverage.sv"
    `include "cam_vga_sccb.sv"
    `include "cam_vga_env.sv"
    `include "cam_vga_test.sv"
    `include "cam_vga_sccb_fault_test.sv"
endpackage
