`timescale 1ns / 1ps

module blue_threshold #(
    parameter logic [4:0] B_MIN     = 5'd18,
    parameter logic [5:0] BR_MARGIN = 6'd5,
    parameter logic [5:0] BG_MARGIN = 6'd3
) (
    input  logic        i_valid,
    input  logic [15:0] i_rgb565,
    output logic        o_is_blue
);

    logic [4:0] red;
    logic [4:0] green;
    logic [4:0] blue;

    logic [5:0] red_ext;
    logic [5:0] green_ext;
    logic [5:0] blue_ext;

    // RGB565 분리
    assign red = i_rgb565[15:11];
    assign green = i_rgb565[10:6];  // 6비트 Green의 하위 1비트 제거
    assign blue = i_rgb565[4:0];

    // 비교 연산을 위한 비트 확장
    assign red_ext = {1'b0, red};
    assign green_ext = {1'b0, green};
    assign blue_ext = {1'b0, blue};

    // 파란색 검출 조건
    always_comb begin
        o_is_blue = 1'b0;

        if (i_valid &&
            (blue >= B_MIN) &&
            (blue_ext >= red_ext + BR_MARGIN) &&
            (blue_ext >= green_ext + BG_MARGIN)) begin
            o_is_blue = 1'b1;
        end
    end

endmodule
