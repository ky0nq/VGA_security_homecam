`timescale 1ns / 1ps
module top_OV7670_VGA (
    input  logic        clk,            // 100MHz
    input  logic        reset,
    input  logic        scale2x,        // 1 = 2배 확대(풀스크린), 0 = 원본 좌상단

    // OV7670
    output logic        ov7670_xclk,    // 카메라로 주는 클럭
    input  logic        ov7670_pclk,    // 카메라에서 오는 픽셀 클럭
    input  logic        ov7670_href,
    input  logic        ov7670_vsync,
    input  logic [7:0]  ov7670_data,    // D[7:0]
    output logic        ov7670_sioc,    // SCCB clock (SIO_C)
    inout  wire         ov7670_siod,    // SCCB data  (SIO_D, open-drain)
//  RESET#, PWDN 는 카메라 모듈에서 3V3 / GND 로 고정

    // VGA
    output logic        h_sync,
    output logic        v_sync,
    output logic [3:0]  port_red,
    output logic [3:0]  port_green,
    output logic [3:0]  port_blue
);

    localparam int H_ACT      = 320;
    localparam int V_ACT      = 240;
    localparam int ADDR_WIDTH = $clog2(320*240);

    // 카메라 클럭 (100MHz/4 = 25MHz)
    OV7670_XCLK_gen #(.DIV(4)) U_XCLK (
        .clk   (clk),
        .reset (reset),
        .xclk  (ov7670_xclk)
    );

    // SCCB 레지스터 초기화
    logic w_sccb_busy, w_sccb_done;

    SCCB_Controller #(
        .CLK_HZ(100_000_000), .SCL_HZ(100_000)
    ) U_SCCB_CONTROLLER (          // 파워업하면 알아서 한 번 돎
        .clk    (clk),
        .reset  (reset),
        .o_busy (w_sccb_busy),
        .o_done (w_sccb_done),
        .sioc   (ov7670_sioc),
        .siod   (ov7670_siod)
    );

    // 캡처 (pclk 도메인)
    logic                    w_we;
    logic [ADDR_WIDTH-1:0]   w_waddr;
    logic [15:0]             w_wdata;

    MEM_CONTROLLER #(
        .H_ACT(H_ACT), .V_ACT(V_ACT), .ADDR_WIDTH(ADDR_WIDTH)
    ) U_MEM_CONTROLLER (
        .pclk   (ov7670_pclk),
        .reset  (reset),
        .href   (ov7670_href),
        .v_sync (ov7670_vsync),
        .pdata  (ov7670_data),
        .we     (w_we),
        .addr   (w_waddr),
        .data   (w_wdata)
    );

    // frame buffer (write=pclk, read=clk)
    logic [ADDR_WIDTH-1:0]   w_raddr;
    logic [15:0]             w_rdata;

    Frame_Buffer #(
        .DATA_WIDTH(16), .ADDR_WIDTH(ADDR_WIDTH), .DEPTH(H_ACT*V_ACT)
    ) U_FRAME_BUFFER (
        .wclk  (ov7670_pclk),
        .we    (w_we),
        .waddr (w_waddr),
        .wdata (w_wdata),
        .rclk  (clk),
        .raddr (w_raddr),
        .rdata (w_rdata)
    );

    // VGA 타이밍 (clk 도메인)
    logic       w_h_sync, w_v_sync, w_de;
    logic [9:0] w_x, w_y;

    VGA_Decoder U_VGA_DECODER (
        .clk    (clk),
        .reset  (reset),
        .h_sync (w_h_sync),
        .v_sync (w_v_sync),
        .x_pixel(w_x),
        .y_pixel(w_y),
        .de     (w_de)
    );

    // read side
    logic [11:0] w_rgb;

    Frame_Reader #(
        .H_ACT(H_ACT), .V_ACT(V_ACT), .ADDR_WIDTH(ADDR_WIDTH)
    ) U_FRAME_READER (
        .clk     (clk),
        .reset   (reset),
        .scale2x (scale2x),
        .de      (w_de),
        .x_pixel (w_x),
        .y_pixel (w_y),
        .rd_addr (w_raddr),
        .rd_data (w_rdata),
        .o_rgb   (w_rgb)
    );

    // 출력 레지스터
    logic [11:0] w_rgb_r;

    VGA_OutReg U_VGA_OUTREG (
        .clk     (clk),
        .reset   (reset),
        .i_h_sync(w_h_sync),
        .i_v_sync(w_v_sync),
        .i_rgb   (w_rgb),
        .o_h_sync(h_sync),
        .o_v_sync(v_sync),
        .o_rgb   (w_rgb_r)
    );

    assign {port_red, port_green, port_blue} = w_rgb_r;

endmodule
