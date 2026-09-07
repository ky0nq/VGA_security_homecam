`timescale 1ns / 1ps

// Puts uart, counter_10s, and uart_decoder together into one communication block.

module uart_link #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx,    // UART RX pin
    output logic tx,    // UART TX pin

    output logic zoom_en,
    output logic effect_sel,
    output logic btn_l,
    output logic btn_r,
    output logic btn_d,
    output logic btn_u_pulse,
    output logic unlock_en    // final value, already includes the forced_lock check
);

    //============================================================
    // uart : the raw byte send/receive layer
    //============================================================
    logic [7:0] rx_data;
    logic        rx_done;
    logic [7:0] tx_data;
    logic        tx_start;
    logic        tx_busy;

    uart #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx      (rx),
        .rx_data (rx_data),
        .rx_done (rx_done),
        .tx_data (tx_data),
        .tx_start(tx_start),
        .tx_busy (tx_busy),
        .tx      (tx)
    );

    //============================================================
    // counter_10s : watches for 10 seconds of silence
    //============================================================
    logic       done_10s;
    logic [7:0] data_10s;

    counter_10s #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_COUNTER_10S (
        .clk     (clk),
        .rst_n   (rst_n),
        .rx_done (rx_done),
        .done_10s(done_10s),
        .data_10s(data_10s)
    );

    assign tx_data  = data_10s;   // send whatever counter_10s built as the TX byte
    assign tx_start = done_10s;   // and use the same "10s reached" pulse to trigger it

    //============================================================
    // uart_decoder : splits the byte into signals, applies forced_lock
    //============================================================
    uart_decoder U_UART_DECODER (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .lock_force (done_10s),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l(btn_l),
        .btn_r(btn_r),
        .btn_d(btn_d),
        .btn_u_pulse(btn_u_pulse),
        .unlock_en  (unlock_en)
    );

endmodule
