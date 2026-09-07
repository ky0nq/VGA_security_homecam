`timescale 1ns / 1ps

// Runs the camera setup: waits after power on, then starts the setup FSM and I2C master.

module SCCB_setup_CNTL #(
    parameter CLK_FREQ_HZ = 100_000_000,
    parameter I2C_FREQ_HZ = 100_000
) (
    input logic clk,
    input logic rst_n,

    input logic setup_start,

    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,

    output logic scl,
    inout  wire  sda
);

    // wires between the two inner blocks
    logic       i2c_start;

    logic [7:0] dev_addr;
    logic [7:0] reg_addr;
    logic [7:0] reg_data;

    logic       i2c_busy;
    logic       i2c_done;
    logic       i2c_ack_error;

    // decides which register to send next
    OV7670_setup_CNTL #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_OV7670_SETUP_CNTL (
        .clk        (clk),
        .rst_n      (rst_n),
        .setup_start(setup_start),

        // I2C Master -> Setup Controller
        .i2c_busy     (i2c_busy),
        .i2c_done     (i2c_done),
        .i2c_ack_error(i2c_ack_error),

        // Setup Controller -> I2C Master
        .i2c_start(i2c_start),
        .dev_addr (dev_addr),
        .reg_addr (reg_addr),
        .reg_data (reg_data),

        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error)
    );

    // actually sends the byte over SCCB
    I2C_master #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(I2C_FREQ_HZ)
    ) U_I2C_MASTER (
        .clk  (clk),
        .rst_n(rst_n),
        .start(i2c_start),

        .dev_addr(dev_addr),
        .reg_addr(reg_addr),
        .reg_data(reg_data),

        .busy     (i2c_busy),
        .done     (i2c_done),
        .ack_error(i2c_ack_error),

        .scl(scl),
        .sda(sda)
    );

endmodule
