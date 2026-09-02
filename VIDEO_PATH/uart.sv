`timescale 1ns / 1ps

// ============================================================
// uart
// ============================================================
module uart #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600   // 트래킹 보드 송신측이랑 반드시 일치해야 함
)(
    input  logic clk,
    input  logic rst_n,
    input  logic rx,            // UART RX 핀 (외부 입력, 비동기)

    output logic zoom_en,       // bit0
    output logic effect_sel,    // bit1
    output logic btn_l,         // bit2 (줌 방향, 레벨)
    output logic btn_r,         // bit3 (줌 방향, 레벨)
    output logic btn_d,         // bit4 (줌 방향, 레벨)
    output logic btn_u_pulse,   // bit5 (필터 넘기기, 1클럭 펄스)
    output logic unlock_en      // bit6 (패턴 일치 결과, 레벨)
);

    logic [7:0] rx_data;
    logic       rx_done;

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

    uart_decoder U_UART_DECODER (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_data    (rx_data),
        .rx_done    (rx_done),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l      (btn_l),
        .btn_r      (btn_r),
        .btn_d      (btn_d),
        .btn_u_pulse(btn_u_pulse),
        .unlock_en  (unlock_en)
    );

endmodule