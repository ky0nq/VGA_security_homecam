`timescale 1ns / 1ps

// ============================================================
// video_path
//   VGA_CAM(SCCB+캡처+프레임버퍼+줌) -> GAUSS_FILTER / FILTER_APPLY
//   두 갈래로 나눠서 unlock_en으로 mux
//
//   unlock_en = 0 (패턴 불일치, 잠김) -> GAUSS_FILTER 결과 사용
//   unlock_en = 1 (패턴 일치, 잠금 해제) -> FILTER_APPLY 결과 사용
//     (이때만 zoom_en/btn_l/r/d, effect_sel/btn_u 필터 조작이 실제로 반영됨
//      - zoom은 rom_reader_upscale이 이미 그렇게 설계됨(zoom_en=0이면 무시),
//        필터 순환은 filter_control이 unlock_en=unlock_en으로 게이팅함)
//
//   UART 관련(uart_rx, uart_decoder)은 이 모듈 밖에서 처리하고,
//   이미 디코딩된 레벨/펄스 신호를 그대로 입력받음
// ============================================================

module video_path (
    input logic clk,      // 시스템 클럭
    input logic pclk,     // OV7670 카메라 픽셀 클럭
    input logic rst_n,

    // UART 디코더에서 이미 분리되어 들어오는 신호들
    input logic unlock_en,   // uart_decoder의 unlock_en
    input logic zoom_en,
    input logic effect_sel,
    input logic btn_l,
    input logic btn_r,
    input logic btn_d,
    input logic btn_u,         // uart_decoder의 btn_u_pulse (이미 1클럭 펄스)

    // OV7670 캡처 인터페이스
    input  logic       cam_href,
    input  logic       cam_vsync,
    input  logic [7:0] cam_data,
    output logic       xclk,       // OV7670 XCLK 핀

    // SCCB (OV7670 레지스터 초기화)
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    // 최종 출력 (vga_outreg로 이어짐)
    output logic        o_h_sync,
    output logic        o_v_sync,
    // output logic [11:0] o_rgb

    // 임시 출력~ 
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);
    // 이것도 나중에 삭제
    logic [11:0] o_rgb;

    //============================================================
    // VGA_CAM : SCCB + 캡처 + 프레임버퍼 + 줌/업스케일
    //============================================================
    logic        cam_h_sync;
    logic        cam_v_sync;
    logic [11:0] cam_rgb;

    vga_cam U_VGA_CAM (
        .clk        (clk),
        .pclk       (pclk),
        .rst_n      (rst_n),
        .zoom_en    (zoom_en),
        .zoom_r     (btn_r),
        .zoom_l     (btn_l),
        .zoom_d     (btn_d),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .cam_scl    (cam_scl),
        .cam_sda    (cam_sda),
        .cam_href   (cam_href),
        .cam_vsync  (cam_vsync),
        .cam_data   (cam_data),
        .o_h_sync   (cam_h_sync),
        .o_v_sync   (cam_v_sync),
        .o_rgb      (cam_rgb),
        .xclk       (xclk)
    );

    //============================================================
    // GAUSS_FILTER 갈래 (항상 계산)
    //============================================================
    logic        gauss_h_sync;
    logic        gauss_v_sync;
    logic [11:0] gauss_rgb;

    gauss_filter_pipe U_GAUSS_FILTER (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(cam_h_sync),
        .i_v_sync(cam_v_sync),
        .i_rgb   (cam_rgb),
        .o_h_sync(gauss_h_sync),
        .o_v_sync(gauss_v_sync),
        .o_rgb   (gauss_rgb)
    );

    //============================================================
    // FILTER_CONTROL + FILTER_APPLY 갈래 (항상 계산)
    //============================================================
    logic pink_en, orange_en, blue_en, gray_en;
    logic gamma_en, gamma_level, night_en;

    filter_control U_FILTER_CONTROL (
        .clk        (clk),
        .rst_n      (rst_n),
        .unlock_en  (unlock_en),
        .effect_sel (effect_sel),
        .btn_u_pulse(btn_u),
        .pink_en    (pink_en),
        .blue_en    (blue_en),
        .orange_en  (orange_en),
        .gray_en    (gray_en),
        .gamma_en   (gamma_en),
        .gamma_level(gamma_level),
        .night_en   (night_en)
    );

    logic        filter_h_sync;
    logic        filter_v_sync;
    logic [11:0] filter_rgb;

    filter_apply U_FILTER_APPLY (
        .clk       (clk),
        .rst_n     (rst_n),
        .i_h_sync  (cam_h_sync),
        .i_v_sync  (cam_v_sync),
        .i_rgb     (cam_rgb),
        .pink_en   (pink_en),
        .orange_en (orange_en),
        .blue_en   (blue_en),
        .gray_en   (gray_en),
        .gamma_en  (gamma_en),
        .gamma_level(gamma_level),
        .night_en  (night_en),
        .o_h_sync  (filter_h_sync),
        .o_v_sync  (filter_v_sync),
        .o_rgb     (filter_rgb)
    );

    //============================================================
    // 최종 MUX : unlock_en = 0 -> GAUSS, 1 -> FILTER_APPLY
    //============================================================
    assign o_rgb    = unlock_en ? filter_rgb    : gauss_rgb;
    assign o_h_sync = unlock_en ? filter_h_sync : gauss_h_sync;
    assign o_v_sync = unlock_en ? filter_v_sync : gauss_v_sync;


    //============================================================
    // 테스트용 - 나중에 주석처리~
    //============================================================
    assign o_rgb    = unlock_en ? filter_rgb    : gauss_rgb;
    assign o_h_sync = unlock_en ? filter_h_sync : gauss_h_sync;
    assign o_v_sync = unlock_en ? filter_v_sync : gauss_v_sync;

    assign {port_red, port_green, port_blue} = o_rgb;

endmodule