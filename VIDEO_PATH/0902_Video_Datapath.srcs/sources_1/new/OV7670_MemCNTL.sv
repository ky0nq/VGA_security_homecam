`timescale 1ns / 1ps

module OV7670_MemCNTL #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter DW    = 16,
    parameter AW    = $clog2(IMG_W * IMG_H)
) (
    input  logic        pclk,
    input  logic        rst_n,
    input  logic        cam_href,
    input  logic        cam_vsync,
    input  logic [ 7:0] cam_data,
    output logic        we,
    output logic [AW-1:0] wAddr,
    output logic [DW-1:0] wData
);

    logic byteSel;
    logic [7:0] px_data;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            we <= 1'b0;
            wAddr <= 0;
            wData <= 0;
            byteSel <= 1'b0;
            px_data <= 0;
        end else begin
            we <= 1'b0;  // 1 pulse setting
            if (we)
                wAddr <= wAddr + 1'b1;  // pixel을 적을 주소 업데이트
            if (cam_vsync) begin // cam_vsync는 새로운 frame (0, 0) 주소지 가야하는 경우
                wAddr <= 0;
                byteSel <= 1'b0;
            end else if (!cam_href) begin
                // Start every active line from the first RGB565 byte.
                // This prevents a partial/odd previous line from swapping the
                // high and low bytes at the left edge of the next line.
                byteSel <= 1'b0;
            end else begin // 기존에 frame 이라면 그대로 pixel wData merge
                byteSel <= ~byteSel;
                if (!byteSel) begin
                    px_data <= cam_data;
                end else begin
                    wData <= {px_data, cam_data};
                    we <= 1'b1;
                end
            end
        end
    end

endmodule
