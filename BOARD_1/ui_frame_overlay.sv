`timescale 1ns / 1ps

// 카메라 영상 위에 테두리 + 우측 상단 라벨(흰 바탕 / 검은 글자)만 그린다.
//
// 파이프라인 2단 : ROM 주소 레지스터 1단 + ROM 읽기 1단.
// (주소를 레지스터로 끊지 않으면 좌표 연산이 BRAM 주소까지 이어져 100MHz가 빠듯하다)
// 따라서 o_rgb는 i_rgb 대비 2클럭 지연이고, wrapper가 sync도 2클럭 늦춘다.

module ui_frame_overlay #(
    parameter int          LABEL_ID     = 0,        // 0=단말기, 1=홈캠
    parameter int          LABEL_W      = 78,       // 글자 실제 폭 (gen_labels.py가 알려줌)
    parameter int          BORDER_PX    = 4,        // 테두리 두께
    parameter logic [11:0] BORDER_COLOR = 12'hFFF,  // 테두리 색
    parameter int          MARGIN       = 8,        // 화면 가장자리 ~ 라벨 박스
    parameter int          PAD          = 6         // 박스 안쪽 여백
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_de,
    input  logic [9:0]  i_x,
    input  logic [9:0]  i_y,
    input  logic [11:0] i_rgb,

    // label ROM
    output logic        o_label_sel,
    output logic [6:0]  o_label_x,
    output logic [4:0]  o_label_y,
    input  logic        i_label_pixel,

    output logic [11:0] o_rgb
);

    localparam int SCREEN_W = 640;
    localparam int SCREEN_H = 480;
    localparam int LABEL_H  = 32;

    localparam int BOX_W  = LABEL_W + 2 * PAD;
    localparam int BOX_H  = LABEL_H + 2 * PAD;
    localparam int BOX_X0 = SCREEN_W - MARGIN - BOX_W;
    localparam int BOX_Y0 = MARGIN;
    localparam int TXT_X0 = BOX_X0 + PAD;
    localparam int TXT_Y0 = BOX_Y0 + PAD;

    localparam logic [11:0] C_WHITE = 12'hFFF;
    localparam logic [11:0] C_BLACK = 12'h000;

    localparam logic [1:0] K_PASS  = 2'd0;   // 카메라 영상 그대로
    localparam logic [1:0] K_FILL  = 2'd1;   // 단색
    localparam logic [1:0] K_LABEL = 2'd2;   // 흰 바탕 + 검은 글자

    //============================================================
    // 픽셀 판정 (조합)
    //============================================================
    logic [1:0]  kind;
    logic [11:0] fill;
    logic        lbl_sel_c;
    logic [6:0]  lbl_x_c;
    logic [4:0]  lbl_y_c;

    logic in_border, in_box, in_text;

    always_comb begin
        in_border = (i_x < BORDER_PX) || (i_x >= SCREEN_W - BORDER_PX) ||
                    (i_y < BORDER_PX) || (i_y >= SCREEN_H - BORDER_PX);

        in_box    = (i_x >= BOX_X0) && (i_x < BOX_X0 + BOX_W) &&
                    (i_y >= BOX_Y0) && (i_y < BOX_Y0 + BOX_H);

        in_text   = (i_x >= TXT_X0) && (i_x < TXT_X0 + LABEL_W) &&
                    (i_y >= TXT_Y0) && (i_y < TXT_Y0 + LABEL_H);

        lbl_sel_c = LABEL_ID[0];
        lbl_x_c   = in_text ? 7'(i_x - TXT_X0) : 7'd0;
        lbl_y_c   = in_text ? 5'(i_y - TXT_Y0) : 5'd0;

        kind = K_PASS;
        fill = C_BLACK;

        if (!i_de) begin
            kind = K_FILL;
            fill = C_BLACK;              // 블랭킹 구간은 반드시 0
        end else if (in_border) begin
            kind = K_FILL;
            fill = BORDER_COLOR;
        end else if (in_box) begin
            if (in_text) begin
                kind = K_LABEL;          // ROM 응답에 따라 검정/흰색
            end else begin
                kind = K_FILL;
                fill = C_WHITE;          // 박스 여백
            end
        end
    end

    //============================================================
    // Stage 1 : ROM 주소 레지스터
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_label_sel <= 1'b0;
            o_label_x   <= 7'd0;
            o_label_y   <= 5'd0;
        end else begin
            o_label_sel <= lbl_sel_c;
            o_label_x   <= lbl_x_c;
            o_label_y   <= lbl_y_c;
        end
    end

    //============================================================
    // 판정 결과는 2단 지연 (주소 레지스터 + ROM 읽기)
    //============================================================
    logic [1:0]  kind_q1, kind_q2;
    logic [11:0] fill_q1, fill_q2, rgb_q1, rgb_q2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kind_q1 <= K_FILL;  kind_q2 <= K_FILL;
            fill_q1 <= C_BLACK; fill_q2 <= C_BLACK;
            rgb_q1  <= C_BLACK; rgb_q2  <= C_BLACK;
        end else begin
            kind_q1 <= kind;    kind_q2 <= kind_q1;
            fill_q1 <= fill;    fill_q2 <= fill_q1;
            rgb_q1  <= i_rgb;   rgb_q2  <= rgb_q1;
        end
    end

    //============================================================
    // Stage 2 : ROM 응답과 정렬해 최종 색 결정
    //============================================================
    always_comb begin
        case (kind_q2)
            K_FILL:  o_rgb = fill_q2;
            K_LABEL: o_rgb = i_label_pixel ? C_BLACK : C_WHITE;
            default: o_rgb = rgb_q2;
        endcase
    end

endmodule
