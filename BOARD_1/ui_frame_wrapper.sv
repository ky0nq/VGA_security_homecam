`timescale 1ns / 1ps

// 두 보드 공통으로 쓰는 UI 블록.
// VGA 파이프라인 맨 끝(최종 출력 레지스터 직전)에 그대로 끼워 넣으면 된다.
//
//   ... -> ui_frame_wrapper -> (vga_outreg) -> VGA 핀
//
// 들어오는 h_sync/v_sync로 좌표를 복원하므로 앞단 지연이 몇 클럭이든 상관없다.
//
//   보드1(Board A, 트래킹) : LABEL_ID=0, LABEL_W=78  -> "단말기"
//   보드2(Board B, 홈캠)   : LABEL_ID=1, LABEL_W=52  -> "홈캠"

module ui_frame_wrapper #(
    parameter int          LABEL_ID     = 0,
    parameter int          LABEL_W      = 78,
    parameter int          BORDER_PX    = 4,
    parameter logic [11:0] BORDER_COLOR = 12'hFFF,
    parameter string       LABEL_MEM    = "ui_labels.mem"
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    logic       de;
    logic [9:0] x, y;

    vga_sync_tracker U_TRACKER (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(i_h_sync),
        .i_v_sync(i_v_sync),
        .o_de    (de),
        .o_x     (x),
        .o_y     (y)
    );

    logic       label_sel, label_pixel;
    logic [6:0] label_x;
    logic [4:0] label_y;

    ui_label_rom #(.MEM_FILE(LABEL_MEM)) U_LABEL_ROM (
        .clk    (clk),
        .i_label(label_sel),
        .i_x    (label_x),
        .i_y    (label_y),
        .o_pixel(label_pixel)
    );

    ui_frame_overlay #(
        .LABEL_ID    (LABEL_ID),
        .LABEL_W     (LABEL_W),
        .BORDER_PX   (BORDER_PX),
        .BORDER_COLOR(BORDER_COLOR)
    ) U_OVERLAY (
        .clk          (clk),
        .rst_n        (rst_n),
        .i_de         (de),
        .i_x          (x),
        .i_y          (y),
        .i_rgb        (i_rgb),
        .o_label_sel  (label_sel),
        .o_label_x    (label_x),
        .o_label_y    (label_y),
        .i_label_pixel(label_pixel),
        .o_rgb        (o_rgb)
    );

    // 오버레이가 2클럭 지연시키므로 sync도 같이 지연
    logic h_sync_q1, v_sync_q1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_q1 <= 1'b1;
            v_sync_q1 <= 1'b1;
            o_h_sync  <= 1'b1;
            o_v_sync  <= 1'b1;
        end else begin
            h_sync_q1 <= i_h_sync;
            v_sync_q1 <= i_v_sync;
            o_h_sync  <= h_sync_q1;
            o_v_sync  <= v_sync_q1;
        end
    end

endmodule
