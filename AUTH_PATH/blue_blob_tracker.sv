`timescale 1ns / 1ps

module blue_blob_tracker #(
    parameter integer IMG_WIDTH       = 320,
    parameter integer IMG_HEIGHT      = 240,
    parameter integer X_WIDTH         = $clog2(IMG_WIDTH),
    parameter integer Y_WIDTH         = $clog2(IMG_HEIGHT),
    parameter integer COUNT_WIDTH     = $clog2(IMG_WIDTH * IMG_HEIGHT + 1),
    parameter integer MIN_BLUE_PIXELS = 50
)(
    input  logic                   i_pclk,
    input  logic                   i_rst_n,

    input  logic                   i_frame_sync,
    input  logic                   i_pixel_valid,
    input  logic                   i_is_blue,

    output logic                   o_blob_valid,
    output logic [X_WIDTH-1:0]     o_center_x,
    output logic [Y_WIDTH-1:0]     o_center_y,
    output logic [X_WIDTH-1:0]     o_min_x,
    output logic [X_WIDTH-1:0]     o_max_x,
    output logic [Y_WIDTH-1:0]     o_min_y,
    output logic [Y_WIDTH-1:0]     o_max_y,
    output logic [COUNT_WIDTH-1:0] o_blue_count
);

    logic [X_WIDTH-1:0] pixel_x;
    logic [Y_WIDTH-1:0] pixel_y;

    logic [X_WIDTH-1:0] min_x_acc;
    logic [X_WIDTH-1:0] max_x_acc;
    logic [Y_WIDTH-1:0] min_y_acc;
    logic [Y_WIDTH-1:0] max_y_acc;

    logic [COUNT_WIDTH-1:0] blue_count_acc;

    logic frame_sync_d;
    logic frame_seen;
    logic frame_start;

    // VSYNC 상승 에지 검출
    assign frame_start = i_frame_sync & ~frame_sync_d;

    always_ff @(posedge i_pclk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            frame_sync_d <= 1'b0;
            frame_seen   <= 1'b0;

            pixel_x <= '0;
            pixel_y <= '0;

            min_x_acc <= IMG_WIDTH - 1;
            max_x_acc <= '0;
            min_y_acc <= IMG_HEIGHT - 1;
            max_y_acc <= '0;

            blue_count_acc <= '0;

            o_blob_valid <= 1'b0;
            o_center_x   <= '0;
            o_center_y   <= '0;
            o_min_x      <= '0;
            o_max_x      <= '0;
            o_min_y      <= '0;
            o_max_y      <= '0;
            o_blue_count <= '0;
        end else begin
            frame_sync_d <= i_frame_sync;

            // 새로운 프레임 시작
            if (frame_start) begin
                // 이전 프레임 결과 출력
                if (frame_seen &&
                    (blue_count_acc >= MIN_BLUE_PIXELS)) begin

                    o_blob_valid <= 1'b1;

                    // Bounding Box의 중앙 좌표 계산
                    o_center_x <= (
                        {1'b0, min_x_acc} +
                        {1'b0, max_x_acc}
                    ) >> 1;

                    o_center_y <= (
                        {1'b0, min_y_acc} +
                        {1'b0, max_y_acc}
                    ) >> 1;

                    o_min_x      <= min_x_acc;
                    o_max_x      <= max_x_acc;
                    o_min_y      <= min_y_acc;
                    o_max_y      <= max_y_acc;
                    o_blue_count <= blue_count_acc;
                end else begin
                    o_blob_valid <= 1'b0;
                    o_center_x   <= '0;
                    o_center_y   <= '0;
                    o_min_x      <= '0;
                    o_max_x      <= '0;
                    o_min_y      <= '0;
                    o_max_y      <= '0;
                    o_blue_count <= '0;
                end

                // 새 프레임 누적값 초기화
                pixel_x <= '0;
                pixel_y <= '0;

                min_x_acc <= IMG_WIDTH - 1;
                max_x_acc <= '0;
                min_y_acc <= IMG_HEIGHT - 1;
                max_y_acc <= '0;

                blue_count_acc <= '0;
                frame_seen     <= 1'b1;
            end else if (i_pixel_valid) begin
                // 파란색 픽셀의 범위 및 개수 누적
                if (i_is_blue) begin
                    if (blue_count_acc == 0) begin
                        min_x_acc <= pixel_x;
                        max_x_acc <= pixel_x;
                        min_y_acc <= pixel_y;
                        max_y_acc <= pixel_y;
                    end else begin
                        if (pixel_x < min_x_acc)
                            min_x_acc <= pixel_x;

                        if (pixel_x > max_x_acc)
                            max_x_acc <= pixel_x;

                        if (pixel_y < min_y_acc)
                            min_y_acc <= pixel_y;

                        if (pixel_y > max_y_acc)
                            max_y_acc <= pixel_y;
                    end

                    blue_count_acc <= blue_count_acc + 1'b1;
                end

                // 현재 픽셀 좌표 증가
                if (pixel_x == IMG_WIDTH - 1) begin
                    pixel_x <= '0;

                    if (pixel_y == IMG_HEIGHT - 1)
                        pixel_y <= '0;
                    else
                        pixel_y <= pixel_y + 1'b1;
                end else begin
                    pixel_x <= pixel_x + 1'b1;
                end
            end
        end
    end

endmodule
