`timescale 1ns / 1ps

// ============================================================
// uart_link
//   uart(rx+tx) + counter_10s(10초 무응답 감지) + uart_decoder(비트 분해)
//   를 묶어서, 물리 rx/tx 핀만 연결하면 최종 디코딩된 신호들이
//   바로 나오는 최상위 통신 블록
//
//   흐름:
//     rx 핀 -> uart -> rx_data/rx_done
//                        │              └─▶ uart_decoder ──▶ zoom_en 등, unlock_en
//                        └─▶ counter_10s ──▶ done_10s ──┬─▶ (lock_force로) uart_decoder
//                                        └─▶ data_10s ──┼─▶ (tx_data로)   uart -> tx 핀
//                                                        └─▶ (tx_start로) uart -> tx 핀
// ============================================================

module uart_link #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx,    // UART RX 핀
    output logic tx,    // UART TX 핀

    output logic zoom_en,
    output logic effect_sel,
    output logic btn_l,
    output logic btn_r,
    output logic btn_d,
    output logic btn_u_pulse,
    output logic unlock_en    // forced_lock까지 반영된 최종값
);

    //============================================================
    // uart : rx+tx 물리 계층
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
    // counter_10s : 10초 무응답 감지
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

    assign tx_data  = data_10s;   // counter_10s가 만든 바이트를 그대로 TX 데이터로
    assign tx_start = done_10s;   // "10초 도달" 이벤트를 TX 트리거로도 그대로 사용

    //============================================================
    // uart_decoder : 비트 분해 + forced_lock 반영
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