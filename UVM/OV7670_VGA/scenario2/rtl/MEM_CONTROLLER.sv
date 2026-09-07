`timescale 1ns / 1ps

// OV7670 캡처. pclk 도메인에서 돈다.
// RGB565 는 pclk 2번에 한 픽셀 (1st = 상위바이트, 2nd = 하위바이트).
// vsync 동안 포인터 리셋 -> 매 프레임 알아서 동기.
// 주소는 linear (y*H_ACT + x) 라 frame buffer 가 딱 H_ACT*V_ACT 깊이.
module MEM_CONTROLLER #(
    parameter int H_ACT      = 320,
    parameter int V_ACT      = 240,
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = $clog2(H_ACT * V_ACT)
)(
    input  logic                    pclk,
    input  logic                    reset,
    input  logic                    href,
    input  logic                    v_sync,
    input  logic [7:0]              pdata,

    output logic                    we,
    output logic [ADDR_WIDTH-1:0]   addr,
    output logic [DATA_WIDTH-1:0]   data
);

    localparam int MAX_PIXELS = H_ACT * V_ACT;

    logic                    byte_sel;   // 0 = 상위바이트 차례, 1 = 하위바이트 차례
    logic [7:0]              hi_byte;    // 먼저 받은 상위바이트 저장
    logic [ADDR_WIDTH-1:0]   pix_cnt;    // 프레임 내 픽셀 번호

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            byte_sel <= 1'b0;
            hi_byte  <= 8'd0;
            pix_cnt  <= '0;
            we       <= 1'b0;
            addr     <= '0;
            data     <= 16'd0;
        end else begin
            we <= 1'b0;   // 기본은 write 안 함

            if (v_sync) begin
                byte_sel <= 1'b0;
                pix_cnt  <= '0;
            end else if (href) begin
                if (!byte_sel) begin
                    // 상위바이트
                    hi_byte  <= pdata;
                    byte_sel <= 1'b1;
                end else begin
                    // 하위바이트 -> 한 픽셀 완성
                    byte_sel <= 1'b0;
                    if (pix_cnt < MAX_PIXELS) begin
                        we      <= 1'b1;
                        addr    <= pix_cnt;
                        data    <= {hi_byte, pdata};
                        pix_cnt <= pix_cnt + 1'b1;
                    end
                end
            end else begin
                byte_sel <= 1'b0;
            end
        end
    end
endmodule
