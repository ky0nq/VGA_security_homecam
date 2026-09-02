`timescale 1ns / 1ps

// ============================================================
// uart_decoder

//   bit7은 현재 미사용
// ============================================================
module uart_decoder (
    input logic clk,
    input logic rst_n,

    input logic [7:0] rx_data,
    input logic        rx_done,

    output logic zoom_en,      // bit0
    output logic effect_sel,   // bit1
    output logic btn_l,        // bit2 (줌 영역 2)
    output logic btn_r,        // bit3 (줌 영역 3)
    output logic btn_d,        // bit4 (줌 영역 4)
    output logic btn_u_pulse,  // bit5 (필터 넘기기, 1클럭 펄스로 변환됨)
    output logic unlock_en     // bit6 (패턴 일치 결과, 레벨)
);

    //============================================================
    // 최신 바이트 유지 (rx_done일 때만 갱신, 평소엔 hold)
    //============================================================
    logic [7:0] status_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 8'b0;
        end else if (rx_done) begin
            status_reg <= rx_data;
        end
        // rx_done=0인 클럭엔 그대로 유지
    end

    //============================================================
    // 레벨 신호 5개
    //============================================================
    assign zoom_en    = status_reg[0];
    assign effect_sel = status_reg[1];
    assign btn_l      = status_reg[2];
    assign btn_r      = status_reg[3];
    assign btn_d      = status_reg[4];
    assign unlock_en  = status_reg[6];

    //============================================================
    // bit5(btn_u)만 edge detect → 1클럭 펄스
    //============================================================
    logic btn_u_level_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_u_level_d <= 1'b0;
        end else begin
            btn_u_level_d <= status_reg[5];
        end
    end

    assign btn_u_pulse = status_reg[5] & ~btn_u_level_d;

endmodule