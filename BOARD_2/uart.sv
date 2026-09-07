`timescale 1ns / 1ps

// ============================================================
// uart
//   uart_rx + uart_tx만 묶은 순수 송수신 모듈 (디코더 없음)
//   rx_data/rx_done은 counter/decoder 등 뒷단 모듈이 직접 받아서 씀
//   tx_data/tx_start도 뒷단(counter)에서 만들어서 그대로 넣어주면 됨
// ============================================================
module uart #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200  // 상대 보드 송수신측이랑 반드시 일치해야 함
)(
    input  logic clk,
    input  logic rst_n,

    // ---- RX ----
    input  logic       rx,        // UART RX 핀 (외부 입력, 비동기)
    output logic [7:0] rx_data,
    output logic        rx_done,   // 1클럭 펄스

    // ---- TX ----
    input  logic [7:0] tx_data,
    input  logic        tx_start,  // 1클럭 펄스
    output logic        tx_busy,
    output logic        tx         // UART TX 핀
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