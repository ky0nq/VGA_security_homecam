`timescale 1ns / 1ps

// ============================================================
// uart_decoder
//   lock_force : counter 모듈에서 오는 1클럭 펄스.
//     들어오면 forced_lock을 래치해서 unlock_en을 계속 0으로 고정하고,
//     rx_done(새 데이터 수신)이 다시 들어와야만 해제됨
//     -> lock_force가 펄스여도 잠금 상태가 다음 데이터 올 때까지 유지됨
//
//   줌 버튼(btn_l/r/d)은 "잠깐 눌렀다 떼면 그 영역으로 토글되고 유지"되는
//   방식이라, 레벨이 아니라 btn_u와 동일하게 edge detect해서 펄스로 냄.
//   "어느 영역이 선택됐는지" 상태 기억은 rom_reader_upscale이 담당함.
//
//   bit7은 현재 미사용
// ============================================================
module uart_decoder (
    input logic clk,
    input logic rst_n,

    input logic [7:0] rx_data,
    input logic        rx_done,
    input logic        lock_force,  // counter 모듈에서 오는 강제 잠금 트리거 (펄스)

    output logic zoom_en,      // bit0 (레벨, 스위치라 그대로)
    output logic effect_sel,   // bit1 (레벨, 스위치라 그대로)
    output logic btn_l,  // bit2 (줌 영역 토글, 1클럭 펄스로 변환됨)
    output logic btn_r,  // bit3 (줌 영역 토글, 1클럭 펄스로 변환됨)
    output logic btn_d,  // bit4 (줌 영역 토글, 1클럭 펄스로 변환됨)
    output logic btn_u_pulse,  // bit5 (필터 넘기기, 1클럭 펄스로 변환됨)
    output logic unlock_en     // bit6 (패턴 일치 결과, 레벨) - forced_lock으로 오버라이드됨
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
    // 레벨 신호 2개 (진짜 스위치라 그대로 통과)
    //============================================================
    assign zoom_en    = status_reg[0];
    assign effect_sel = status_reg[1];

    //============================================================
    // forced_lock 래치 : lock_force 펄스가 오면 잠금 유지,
    // rx_done(새 데이터)이 와야 해제
    //============================================================
    logic forced_lock;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            forced_lock <= 1'b0;
        end else if (rx_done) begin
            forced_lock <= 1'b0;       // 새 데이터 들어오면 강제 잠금 해제
        end else if (lock_force) begin
            forced_lock <= 1'b1;       // lock_force 펄스 들어오면 래치
        end
    end

    assign unlock_en = forced_lock ? 1'b0 : status_reg[6];

    //============================================================
    // bit2~5(btn_l/r/d/u) : 도착한 바이트에 그 비트가 1로 찍혀 있으면
    // 그 자체를 트리거로 씀. uart_packet_controller가 "진짜 눌린 그
    // 패킷에만" 1을 담아 보내고 보내자마자 비우는 방식이라, 이전 값과
    // 비교(edge detect)하지 않고 rx_done 순간의 값만 봐도 안전함
    //============================================================
    assign btn_l = rx_done & rx_data[2];
    assign btn_r = rx_done & rx_data[3];
    assign btn_d = rx_done & rx_data[4];
    assign btn_u_pulse = rx_done & rx_data[5];

endmodule