`timescale 1ns / 1ps

// =================================================================================
// Module: uart
// Description: Top-level wrapper instantiating UART Receiver (uart_rx) and 
//              Transmitter (uart_tx) without internal decoding.
// Parameters:
//   - CLK_FREQ_HZ: System clock frequency in Hz (Default: 100 MHz)
//   - BAUD_RATE  : Communication baud rate in bps (Default: 115200 bps)
// =================================================================================

module uart #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115200
)(
    input  logic       clk,
    input  logic       rst_n,

    // UART RX Interface
    input  logic       rx,        // Asynchronous UART RX pin
    output logic [7:0] rx_data,   // Received byte data
    output logic       rx_done,   // 1-clock pulse indicating valid received data

    // UART TX Interface
    input  logic [7:0] tx_data,   // Byte data to transmit
    input  logic       tx_start,  // 1-clock pulse trigger for transmission
    output logic       tx_busy,   // Transmission active indicator
    output logic       tx         // UART TX pin
);

    // UART Receiver Instance
    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART_RX (
        .clk    (clk),
        .rst_n  (rst_n),
        .rx     (rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // UART Transmitter Instance
    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART_TX (
        .clk     (clk),
        .rst_n   (rst_n),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx_busy (tx_busy),
        .tx      (tx)
    );

endmodule
