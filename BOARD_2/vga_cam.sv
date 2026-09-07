`timescale 1ns / 1ps

// ============================================================
// vga_cam
//   OV7670 SCCB 초기화 + 캡처(320x240) -> Frame Buffer -> 2x 업스케일
//   판독(zoom 포함) -> VGA 타이밍까지, "카메라"와 관련된 모든 걸 묶은 블록
//
//   내부 구성:
//     SCCB_setup_CNTL    : 전원 인가 후 자동으로 OV7670 레지스터 초기화(I2C)
//     OV7670_MemCNTL     : 카메라 픽셀(pclk 도메인) -> 프레임버퍼 write
//     framebuffer        : 320x240 RGB565 저장 (dual clock BRAM)
//     VGA_Decoder        : h_sync/v_sync/x_pixel/y_pixel/de 생성 (clk 도메인)
//     rom_reader_upscale : 2x 업스케일 + zoom 판독, RGB565->RGB444 변환
//
// ============================================================

module vga_cam #(
    parameter CLK_FREQ_HZ       = 100_000_000,
    parameter I2C_FREQ_HZ       = 100_000,
    parameter POWERUP_DELAY_MS  = 50
) (
    input logic clk,      // 시스템 클럭 (VGA 타이밍/프레임버퍼 read/SCCB 쪽)
    input logic pclk,     // OV7670 카메라 픽셀 클럭 (프레임버퍼 write 쪽)
    input logic rst_n,

    // Zoom 컨트롤
    input logic zoom_en,
    input logic zoom_r,
    input logic zoom_l,
    input logic zoom_d,

    // SCCB (OV7670 레지스터 초기화)
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    // OV7670 캡처 인터페이스
    input logic       cam_href,
    input logic       cam_vsync,
    input logic [7:0] cam_data,

    // 출력
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb,
    output logic        xclk       // OV7670 XCLK 핀 공급용
);

    localparam IMG_W = 320;
    localparam IMG_H = 240;
    localparam DW    = 16;
    localparam AW    = $clog2(IMG_W * IMG_H);

    localparam integer POWERUP_DELAY_CYCLES =
        (CLK_FREQ_HZ / 1000) * POWERUP_DELAY_MS;
    localparam integer POWERUP_CNT_WIDTH = $clog2(POWERUP_DELAY_CYCLES);

    //============================================================
    // Camera XCLK (FPGA clk → 25MHz)
    //============================================================
    pclk_gen U_CAM_CLK_GEN (
        .clk  (clk),
        .rst_n(rst_n),
        .pclk (xclk)
    );

    //============================================================
    // 전원 인가 후 자동으로 SCCB 초기화 1회 시작
    //============================================================
    logic [POWERUP_CNT_WIDTH-1:0] powerup_cnt;
    logic                         setup_start_auto;
    logic                         setup_started;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            powerup_cnt      <= '0;
            setup_start_auto <= 1'b0;
            setup_started    <= 1'b0;
        end else begin
            setup_start_auto <= 1'b0;
            if (!setup_started) begin
                if (powerup_cnt == POWERUP_DELAY_CYCLES - 1) begin
                    setup_start_auto <= 1'b1;
                    setup_started    <= 1'b1;
                end else begin
                    powerup_cnt <= powerup_cnt + 1'b1;
                end
            end
        end
    end

    SCCB_setup_CNTL #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(I2C_FREQ_HZ)
    ) U_SCCB_SETUP_CNTL (
        .clk        (clk),
        .rst_n      (rst_n),
        .setup_start(setup_start_auto),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .scl        (cam_scl),
        .sda        (cam_sda)
    );

    //============================================================
    // Internal Signal
    //============================================================
    logic              we;
    logic [    AW-1:0] wAddr;
    logic [    DW-1:0] wData;
    logic [    AW-1:0] rAddr;
    logic [    DW-1:0] rData;

    logic              de;
    logic [       9:0] x_pixel;
    logic [       9:0] y_pixel;
    logic              w_h_sync;
    logic              w_v_sync;

    //============================================================
    // OV7670 Memory Controller (pclk 도메인)
    //============================================================
    OV7670_MemCNTL #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DW   (DW)
    ) U_MEM_CNTL (
        .pclk     (pclk),
        .rst_n    (rst_n),
        .cam_href (cam_href),
        .cam_vsync(cam_vsync),
        .cam_data (cam_data),
        .we       (we),
        .wAddr    (wAddr),
        .wData    (wData)
    );

    //============================================================
    // Frame Buffer (write: pclk 도메인 / read: clk 도메인)
    //============================================================
    framebuffer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DW   (DW)
    ) U_FRAMEBUFFER (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (clk),
        .rAddr(rAddr),
        .rData(rData)
    );

    //============================================================
    // VGA Timing Generator (clk 도메인)
    //============================================================
    VGA_Decoder U_VGA_DEC (
        .clk    (clk),
        .rst_n  (rst_n),
        .h_sync (w_h_sync),
        .v_sync (w_v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    //============================================================
    // 2x 업스케일 + Zoom 판독
    //============================================================
    rom_reader_upscale U_READER_UPSCALE (
        .clk    (clk),
        .rst_n  (rst_n),
        .zoom_en(zoom_en),
        .zoom_r (zoom_r),
        .zoom_l (zoom_l),
        .zoom_d (zoom_d),
        .de     (de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (rAddr),
        .px_data(rData),
        .o_rgb  (o_rgb)
    );

    //============================================================
    // h_sync/v_sync : rom_reader_upscale의 dispArea_d와 동일하게 1클럭 지연
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;
            o_v_sync <= 1'b1;
        end else begin
            o_h_sync <= w_h_sync;
            o_v_sync <= w_v_sync;
        end
    end

endmodule