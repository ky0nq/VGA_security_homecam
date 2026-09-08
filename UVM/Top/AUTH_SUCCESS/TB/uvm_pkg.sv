// Package of testbench classes and shared definitions.
`timescale 1ns/1ps

package dut_pkg;
	import uvm_pkg::*;
    `include "uvm_macros.svh"
    `include "../TB/uvm_report.sv"
    `include "../TB/uvm_define.svh"
    `include "../TB/seq/uvm_transaction.sv"
    `include "../TB/seq/uvm_sequence.sv"
    `include "../TB/components/uvm_coverage.sv"
    `include "../TB/components/uvm_sequencer.sv"
    `include "../TB/components/uvm_driver.sv"
    `include "../TB/components/uvm_monitor.sv"
    `include "../TB/components/uvm_scoreboard.sv"
    `include "../TB/components/uvm_auth_scoreboard.sv"
    `include "../TB/components/uvm_auth_coverage.sv"
    `include "../TB/components/uvm_agent.sv"
    `include "../TB/components/uvm_env.sv"
    `include "../TB/uvm_test.sv"
endpackage
