`timescale 1ns / 1ps

// Puts the uart_rx and uart_tx modules together in one place.

module uart #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200  // must match the baud rate on the other board
)(
    input  logic clk,
    input  logic rst_n,

    // ---- RX ----
    input  logic       rx,        // UART RX pin, comes in from outside so it is not synced yet
    output logic [7:0] rx_data,
    output logic        rx_done,   // 1-clock pulse

    // ---- TX ----
    input  logic [7:0] tx_data,
    input  logic        tx_start,  // 1-clock pulse
    output logic        tx_busy,
    output logic        tx         // UART TX pin
);

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
