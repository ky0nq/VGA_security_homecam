`timescale 1ns / 1ps

module grid_overlay #(
    parameter integer LINE_THICKNESS = 2,
    parameter logic [11:0] LINE_COLOR = 12'hFFF
)(
    input  logic        i_enable,
    input  logic        i_de,
    input  logic [9:0]  i_vga_x,
    input  logic [9:0]  i_vga_y,
    input  logic [11:0] i_rgb,

    output logic [11:0] o_rgb
);

    localparam integer SCREEN_WIDTH  = 640;
    localparam integer SCREEN_HEIGHT = 480;

    // grid_mapper의 320×240 영역 경계값을 2배 확대
    localparam integer VERTICAL_LINE_1 = 212;
    localparam integer VERTICAL_LINE_2 = 426;

    localparam integer HORIZONTAL_LINE_1 = 160;
    localparam integer HORIZONTAL_LINE_2 = 320;

    logic outer_border;
    logic vertical_grid_line;
    logic horizontal_grid_line;
    logic grid_line;

    always_comb begin
        // 화면 외곽 테두리
        outer_border =
            (i_vga_x < LINE_THICKNESS) ||
            (i_vga_x >= SCREEN_WIDTH - LINE_THICKNESS) ||
            (i_vga_y < LINE_THICKNESS) ||
            (i_vga_y >= SCREEN_HEIGHT - LINE_THICKNESS);

        // 3열을 구분하는 세로선
        vertical_grid_line =
            (
                (i_vga_x >= VERTICAL_LINE_1) &&
                (i_vga_x < VERTICAL_LINE_1 + LINE_THICKNESS)
            )
            ||
            (
                (i_vga_x >= VERTICAL_LINE_2) &&
                (i_vga_x < VERTICAL_LINE_2 + LINE_THICKNESS)
            );

        // 3행을 구분하는 가로선
        horizontal_grid_line =
            (
                (i_vga_y >= HORIZONTAL_LINE_1) &&
                (i_vga_y < HORIZONTAL_LINE_1 + LINE_THICKNESS)
            )
            ||
            (
                (i_vga_y >= HORIZONTAL_LINE_2) &&
                (i_vga_y < HORIZONTAL_LINE_2 + LINE_THICKNESS)
            );

        grid_line =
            outer_border         ||
            vertical_grid_line   ||
            horizontal_grid_line;

        // 기본적으로 원본 영상 출력
        o_rgb = i_rgb;

        if (i_enable && i_de && grid_line)
            o_rgb = LINE_COLOR;
    end

endmodule