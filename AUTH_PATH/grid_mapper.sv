`timescale 1ns / 1ps

module grid_mapper #(
    parameter integer IMG_WIDTH  = 320,
    parameter integer IMG_HEIGHT = 240,
    parameter integer X_WIDTH    = $clog2(IMG_WIDTH),
    parameter integer Y_WIDTH    = $clog2(IMG_HEIGHT)
)(
    input  logic               i_blob_valid,
    input  logic [X_WIDTH-1:0] i_center_x,
    input  logic [Y_WIDTH-1:0] i_center_y,

    output logic               o_grid_valid,
    output logic [3:0]         o_grid_id
);

    localparam integer X_BOUNDARY_1 = IMG_WIDTH / 3;
    localparam integer X_BOUNDARY_2 = (IMG_WIDTH * 2) / 3;

    localparam integer Y_BOUNDARY_1 = IMG_HEIGHT / 3;
    localparam integer Y_BOUNDARY_2 = (IMG_HEIGHT * 2) / 3;

    logic [1:0] grid_column;
    logic [1:0] grid_row;

    always_comb begin
        grid_column = 2'd0;
        grid_row    = 2'd0;

        o_grid_valid = 1'b0;
        o_grid_id    = 4'd0;

        if (i_blob_valid &&
            (i_center_x < IMG_WIDTH) &&
            (i_center_y < IMG_HEIGHT)) begin

            o_grid_valid = 1'b1;

            // 중심 좌표의 열 위치 판정
            if (i_center_x < X_BOUNDARY_1)
                grid_column = 2'd0;
            else if (i_center_x < X_BOUNDARY_2)
                grid_column = 2'd1;
            else
                grid_column = 2'd2;

            // 중심 좌표의 행 위치 판정
            if (i_center_y < Y_BOUNDARY_1)
                grid_row = 2'd0;
            else if (i_center_y < Y_BOUNDARY_2)
                grid_row = 2'd1;
            else
                grid_row = 2'd2;

            // 왼쪽 위부터 오른쪽 아래까지 Grid 번호 1~9
            case ({grid_row, grid_column})
                4'b0000: o_grid_id = 4'd1;
                4'b0001: o_grid_id = 4'd2;
                4'b0010: o_grid_id = 4'd3;

                4'b0100: o_grid_id = 4'd4;
                4'b0101: o_grid_id = 4'd5;
                4'b0110: o_grid_id = 4'd6;

                4'b1000: o_grid_id = 4'd7;
                4'b1001: o_grid_id = 4'd8;
                4'b1010: o_grid_id = 4'd9;

                default: o_grid_id = 4'd0;
            endcase
        end
    end

endmodule
