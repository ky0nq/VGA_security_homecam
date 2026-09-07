`timescale 1ns / 1ps

module Frame_Reader #(
    parameter int H_ACT      = 320,
    parameter int V_ACT      = 240,
    parameter int ADDR_WIDTH = 17
)(
    input  logic                    clk,       
    input  logic                    reset,
    input  logic                    scale2x,
    input  logic                    de,
    input  logic [9:0]              x_pixel,
    input  logic [9:0]              y_pixel,
    output logic [ADDR_WIDTH-1:0]   rd_addr,
    input  logic [15:0]             rd_data, 
    output logic [11:0]             o_rgb
);

    logic [9:0] src_x, src_y;
    logic       disp, disp_d;

    always_comb begin
        if (scale2x) begin
            src_x = x_pixel >> 1;
            src_y = y_pixel >> 1;
        end else begin
            src_x = x_pixel;
            src_y = y_pixel;
        end
    end

    assign disp    = de && (src_x < H_ACT) && (src_y < V_ACT);
    assign rd_addr = disp ? (src_y * H_ACT + src_x) : '0;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) disp_d <= 1'b0;
        else       disp_d <= disp;
    end

    assign o_rgb = disp_d ? {rd_data[15:12], rd_data[10:7], rd_data[4:1]} : 12'd0;
endmodule
