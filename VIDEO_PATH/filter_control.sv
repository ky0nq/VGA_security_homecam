`timescale 1ns / 1ps

// Effect Selector
//
// effect_sel = 0 (Color) : btn_u_pulse 들어올 때마다 5상태 순환
//   기본화면 -> pink -> blue -> orange -> gray -> 기본화면 ...
//
// effect_sel = 1 (Gamma/Night) : btn_u_pulse 들어올 때마다 4상태 순환
//   원본 -> 밝게 -> 더밝게 -> night -> 원본 ...
//
// unlock_en = 0 (패턴 불일치, 잠김) 이면 btn_u_pulse를 무시함
//   (GAUSS/SHARP는 이 모듈 관할이 아니라 상위에서 별도로 mux 처리)
//
// btn_u_pulse는 uart_decoder에서 이미 edge detect되어 1클럭 펄스로
// 들어오므로, 여기서는 디바운스/edge detect를 따로 하지 않음
//
module filter_control (
    input logic clk,
    input logic rst_n,
    input logic unlock_en,    // uart_decoder의 unlock_en (패턴 일치 결과)
    input logic effect_sel,   // uart_decoder의 effect_sel
    input logic btn_u_pulse,  // uart_decoder의 btn_u_pulse (이미 1클럭 펄스)

    // Color Effect (effect_sel = 0), one-hot, 전부 0 = 기본화면(통과)
    output logic pink_en,
    output logic blue_en,
    output logic orange_en,
    output logic gray_en,

    // Gamma / Night Effect (effect_sel = 1)
    output logic gamma_en,
    output logic gamma_level,  // 0 = 밝게, 1 = 더밝게 (gamma_en일 때만 유효)
    output logic night_en
);

    // unlock_en일 때만 버튼 펄스가 유효함
    logic btn_pulse;
    assign btn_pulse = btn_u_pulse & unlock_en;

    //============================================================
    // Color / Gamma-Night State Counter
    //============================================================
    logic [2:0] color_state;  // 0..4 : 기본/pink/blue/orange/gray
    logic [1:0] tone_state;  // 0..3 : 원본/밝게/더밝게/night

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            color_state <= 3'd0;
            tone_state  <= 2'd0;
        end else if (btn_pulse) begin
            if (!effect_sel) begin
                color_state <= (color_state == 3'd4) ? 3'd0 : color_state + 3'd1;
            end else begin
                tone_state <= (tone_state == 2'd3) ? 2'd0 : tone_state + 2'd1;
            end
        end
    end

    //============================================================
    // Enable Decode
    //============================================================
    assign pink_en   = (~effect_sel) && (color_state == 3'd1);
    assign blue_en   = (~effect_sel) && (color_state == 3'd2);
    assign orange_en = (~effect_sel) && (color_state == 3'd3);
    assign gray_en   = (~effect_sel) && (color_state == 3'd4);

    assign gamma_en    = effect_sel && (tone_state == 2'd1 || tone_state == 2'd2);
    assign gamma_level = (tone_state == 2'd2);
    assign night_en    = effect_sel && (tone_state == 2'd3);

endmodule