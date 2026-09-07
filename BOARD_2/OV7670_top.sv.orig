`timescale 1ns / 1ps

// ============================================================
// OV7670_top
//   uart_link(통신+10초 타임아웃+디코딩) -> video_path(카메라+필터체인)
//   -> vga_outreg(채널분리+최종 출력 레지스터) -> 물리 VGA 핀
// ============================================================

module OV7670_top #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input logic clk,
    input logic rst_n,

    // UART (트래킹 보드와 통신)
    input  logic uart_rx,
    output logic uart_tx,

    // OV7670 캡처 인터페이스
    input  logic       pclk,       // OV7670이 실제로 내보내는 픽셀 클럭 (물리 핀)
    input  logic       cam_href,
    input  logic       cam_vsync,
    input  logic [7:0] cam_data,
    output logic       xclk,

    // SCCB (OV7670 레지스터 초기화)
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    output logic unlock_en,   // uart_link의 unlock_en

    // VGA 출력
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);

    //============================================================
    // uart_link : 통신 + 10초 무응답 감지 + 비트 디코딩
    //============================================================
    // logic unlock_en;
    logic zoom_en;
    logic effect_sel;
    logic btn_l, btn_r, btn_d;
    logic btn_u_pulse;

    uart_link #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) U_UART_LINK (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx         (uart_rx),
        .tx         (uart_tx),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l      (btn_l),
        .btn_r      (btn_r),
        .btn_d      (btn_d),
        .btn_u_pulse(btn_u_pulse),
        .unlock_en  (unlock_en)
    );

    //============================================================
    // video_path : SCCB + 캡처 + 프레임버퍼 + 줌 + 필터 체인
    //============================================================
    logic        vp_h_sync;
    logic        vp_v_sync;
    logic [11:0] vp_rgb;

    video_path U_VIDEO_PATH (
        .clk        (clk),
        .pclk       (pclk),       // 카메라 물리 PCLK 핀 그대로 전달
        .rst_n      (rst_n),
        .unlock_en  (unlock_en),
        .zoom_en    (zoom_en),
        .effect_sel (effect_sel),
        .btn_l      (btn_l),
        .btn_r      (btn_r),
        .btn_d      (btn_d),
        .btn_u      (btn_u_pulse),
        .cam_href   (cam_href),
        .cam_vsync  (cam_vsync),
        .cam_data   (cam_data),
        .xclk       (xclk),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .cam_scl    (cam_scl),
        .cam_sda    (cam_sda),
        .o_h_sync   (vp_h_sync),
        .o_v_sync   (vp_v_sync),
        .o_rgb      (vp_rgb)
    );

    //============================================================
    // vga_outreg : 채널 분리(RGB444 -> 4/4/4) + 최종 출력 레지스터
    //============================================================
    logic [11:0] out_rgb;

    vga_outreg U_VGA_OUTREG (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(vp_h_sync),
        .i_v_sync(vp_v_sync),
        .i_rgb   (vp_rgb),
        .o_h_sync(h_sync),
        .o_v_sync(v_sync),
        .o_rgb   (out_rgb)
    );

    assign {port_red, port_green, port_blue} = out_rgb;

endmodule