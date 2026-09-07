`timescale 1ns / 1ps

// 들어오는 h_sync/v_sync만 보고 화면 좌표(x, y, de)를 복원한다.
//
// video_path의 gauss / filter 갈래는 픽셀과 sync를 함께 지연시키므로,
// 도착한 sync를 기준으로 좌표를 다시 만들면 앞단 파이프라인 지연이
// 몇 클럭이든 자동으로 정렬된다. 덕분에 기존 모듈을 하나도 안 고치고
// 파이프라인 맨 끝에 UI를 끼워넣을 수 있음.
//
// 타이밍은 프로젝트의 vga_decoder.sv와 동일한 640x480@60 규격.

module vga_sync_tracker (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       i_h_sync,
    input  logic       i_v_sync,

    output logic       o_de,
    output logic [9:0] o_x,
    output logic [9:0] o_y
);

    localparam int H_TOTAL   = 800;
    localparam int V_TOTAL   = 525;
    localparam int H_VISIBLE = 640;
    localparam int V_VISIBLE = 480;

    // h_sync는 h_count 656~751 구간에서 low -> 752에서 상승
    localparam int H_SYNC_END = 752;
    // v_sync는 v_count 490~491 구간에서 low -> 492에서 상승
    localparam int V_SYNC_END = 492;

    logic h_sync_q, v_sync_q;
    logic h_rise, v_rise;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_q <= 1'b1;
            v_sync_q <= 1'b1;
        end else begin
            h_sync_q <= i_h_sync;
            v_sync_q <= i_v_sync;
        end
    end

    assign h_rise = i_h_sync & ~h_sync_q;
    assign v_rise = i_v_sync & ~v_sync_q;

    // 픽셀 틱(25MHz). h_sync 상승마다 위상을 다시 맞춰 라인 단위로 자기보정된다.
    logic [1:0] phase;
    logic       tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      phase <= 2'd0;
        else if (h_rise) phase <= 2'd0;
        else             phase <= phase + 2'd1;
    end

    assign tick = (phase == 2'd3);

    logic [9:0] x_cnt, y_cnt;
    logic       line_end;

    assign line_end = tick && (x_cnt == H_TOTAL - 1);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)      x_cnt <= 10'd0;
        else if (h_rise) x_cnt <= 10'(H_SYNC_END);
        else if (tick)   x_cnt <= (x_cnt == H_TOTAL - 1) ? 10'd0 : x_cnt + 10'd1;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)        y_cnt <= 10'd0;
        else if (v_rise)   y_cnt <= 10'(V_SYNC_END);
        else if (line_end) y_cnt <= (y_cnt == V_TOTAL - 1) ? 10'd0 : y_cnt + 10'd1;
    end

    assign o_x  = x_cnt;
    assign o_y  = y_cnt;
    assign o_de = (x_cnt < H_VISIBLE) && (y_cnt < V_VISIBLE);

endmodule
