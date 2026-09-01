`timescale 1ns / 1ps

// ============================================================
// gauss_filter_pipe (5x5 버전)
//   5x5 균일 평균(box blur) - 25개 픽셀을 다 더해서 25로 나눔
//   항상 블러링된 결과만 출력함 (en 없음, 원본 통과 기능 없음)
//   -> unlock_en에 따라 이 모듈 결과를 쓸지 말지는 상위 MUX가 결정
// ============================================================

module gauss_filter_pipe #(
    parameter int IMG_WIDTH = 800   // 한 줄(H_Whole_line)당 pclk 틱 수
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,      // {R[3:0], G[3:0], B[3:0]}

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);

    localparam int WEIGHT_SUM = 25; // 5x5 균일 평균

    // ---------------- 로컬 pclk 생성 ----------------
    logic pclk;
    pclk_gen U_PCLK_GEN (
        .clk   (clk),
        .rst_n (rst_n),
        .pclk  (pclk)
    );

    // 전체 파이프라인 지연(픽셀 단위, pclk 기준)
    // 라인버퍼 4개(각 IMG_WIDTH) + 입력레지스터(1) + 컬럼시프트/합산/출력(~5)
    localparam int LATENCY = 4 * IMG_WIDTH + 8;

    // ---------------- Stage 0: 입력 레지스터 ----------------
    logic [11:0] rgb_in_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rgb_in_r <= '0;
        else if (pclk) rgb_in_r <= i_rgb;
    end

    // ---------------- 라인 버퍼 1~4 (한 줄씩 지연, 총 4줄 위까지) ----------------
    logic [11:0] line_buf1 [0:IMG_WIDTH-1];
    logic [11:0] line_buf2 [0:IMG_WIDTH-1];
    logic [11:0] line_buf3 [0:IMG_WIDTH-1];
    logic [11:0] line_buf4 [0:IMG_WIDTH-1];
    logic [11:0] row1_stream, row2_stream, row3_stream, row4_stream;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < IMG_WIDTH; i++) line_buf1[i] <= '0;
        end else if (pclk) begin
            for (int i = IMG_WIDTH-1; i > 0; i--) line_buf1[i] <= line_buf1[i-1];
            line_buf1[0] <= rgb_in_r;
        end
    end
    assign row1_stream = line_buf1[IMG_WIDTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < IMG_WIDTH; i++) line_buf2[i] <= '0;
        end else if (pclk) begin
            for (int i = IMG_WIDTH-1; i > 0; i--) line_buf2[i] <= line_buf2[i-1];
            line_buf2[0] <= row1_stream;
        end
    end
    assign row2_stream = line_buf2[IMG_WIDTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < IMG_WIDTH; i++) line_buf3[i] <= '0;
        end else if (pclk) begin
            for (int i = IMG_WIDTH-1; i > 0; i--) line_buf3[i] <= line_buf3[i-1];
            line_buf3[0] <= row2_stream;
        end
    end
    assign row3_stream = line_buf3[IMG_WIDTH-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < IMG_WIDTH; i++) line_buf4[i] <= '0;
        end else if (pclk) begin
            for (int i = IMG_WIDTH-1; i > 0; i--) line_buf4[i] <= line_buf4[i-1];
            line_buf4[0] <= row3_stream;
        end
    end
    assign row4_stream = line_buf4[IMG_WIDTH-1];

    // ---------------- 5-tap column shift (row별 5개씩) ----------------
    logic [11:0] r0_c0, r0_c1, r0_c2, r0_c3, r0_c4; // 현재 라인
    logic [11:0] r1_c0, r1_c1, r1_c2, r1_c3, r1_c4; // 1줄 위
    logic [11:0] r2_c0, r2_c1, r2_c2, r2_c3, r2_c4; // 2줄 위
    logic [11:0] r3_c0, r3_c1, r3_c2, r3_c3, r3_c4; // 3줄 위
    logic [11:0] r4_c0, r4_c1, r4_c2, r4_c3, r4_c4; // 4줄 위

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {r0_c0,r0_c1,r0_c2,r0_c3,r0_c4} <= '0;
            {r1_c0,r1_c1,r1_c2,r1_c3,r1_c4} <= '0;
            {r2_c0,r2_c1,r2_c2,r2_c3,r2_c4} <= '0;
            {r3_c0,r3_c1,r3_c2,r3_c3,r3_c4} <= '0;
            {r4_c0,r4_c1,r4_c2,r4_c3,r4_c4} <= '0;
        end else if (pclk) begin
            r0_c4<=r0_c3; r0_c3<=r0_c2; r0_c2<=r0_c1; r0_c1<=r0_c0; r0_c0<=rgb_in_r;
            r1_c4<=r1_c3; r1_c3<=r1_c2; r1_c2<=r1_c1; r1_c1<=r1_c0; r1_c0<=row1_stream;
            r2_c4<=r2_c3; r2_c3<=r2_c2; r2_c2<=r2_c1; r2_c1<=r2_c0; r2_c0<=row2_stream;
            r3_c4<=r3_c3; r3_c3<=r3_c2; r3_c2<=r3_c1; r3_c1<=r3_c0; r3_c0<=row3_stream;
            r4_c4<=r4_c3; r4_c3<=r4_c2; r4_c2<=r4_c1; r4_c1<=r4_c0; r4_c0<=row4_stream;
        end
    end

    // ---------------- 채널별 25칸 합산 ----------------
    function automatic logic [19:0] sum25(
        input logic [3:0] a0,a1,a2,a3,a4,
        input logic [3:0] b0,b1,b2,b3,b4,
        input logic [3:0] c0,c1,c2,c3,c4,
        input logic [3:0] d0,d1,d2,d3,d4,
        input logic [3:0] e0,e1,e2,e3,e4
    );
        sum25 = a0+a1+a2+a3+a4 + b0+b1+b2+b3+b4 + c0+c1+c2+c3+c4
              + d0+d1+d2+d3+d4 + e0+e1+e2+e3+e4;
    endfunction

    logic [19:0] sum_r_c, sum_g_c, sum_b_c;
    logic [19:0] sum_r,   sum_g,   sum_b;

    assign sum_r_c = sum25(r0_c0[11:8],r0_c1[11:8],r0_c2[11:8],r0_c3[11:8],r0_c4[11:8],
                            r1_c0[11:8],r1_c1[11:8],r1_c2[11:8],r1_c3[11:8],r1_c4[11:8],
                            r2_c0[11:8],r2_c1[11:8],r2_c2[11:8],r2_c3[11:8],r2_c4[11:8],
                            r3_c0[11:8],r3_c1[11:8],r3_c2[11:8],r3_c3[11:8],r3_c4[11:8],
                            r4_c0[11:8],r4_c1[11:8],r4_c2[11:8],r4_c3[11:8],r4_c4[11:8]);
    assign sum_g_c = sum25(r0_c0[7:4],r0_c1[7:4],r0_c2[7:4],r0_c3[7:4],r0_c4[7:4],
                            r1_c0[7:4],r1_c1[7:4],r1_c2[7:4],r1_c3[7:4],r1_c4[7:4],
                            r2_c0[7:4],r2_c1[7:4],r2_c2[7:4],r2_c3[7:4],r2_c4[7:4],
                            r3_c0[7:4],r3_c1[7:4],r3_c2[7:4],r3_c3[7:4],r3_c4[7:4],
                            r4_c0[7:4],r4_c1[7:4],r4_c2[7:4],r4_c3[7:4],r4_c4[7:4]);
    assign sum_b_c = sum25(r0_c0[3:0],r0_c1[3:0],r0_c2[3:0],r0_c3[3:0],r0_c4[3:0],
                            r1_c0[3:0],r1_c1[3:0],r1_c2[3:0],r1_c3[3:0],r1_c4[3:0],
                            r2_c0[3:0],r2_c1[3:0],r2_c2[3:0],r2_c3[3:0],r2_c4[3:0],
                            r3_c0[3:0],r3_c1[3:0],r3_c2[3:0],r3_c3[3:0],r3_c4[3:0],
                            r4_c0[3:0],r4_c1[3:0],r4_c2[3:0],r4_c3[3:0],r4_c4[3:0]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_r <= '0; sum_g <= '0; sum_b <= '0;
        end else if (pclk) begin
            sum_r <= sum_r_c;
            sum_g <= sum_g_c;
            sum_b <= sum_b_c;
        end
    end

    // ---------------- 25로 나누기 + 출력 레지스터 ----------------
    function automatic logic [3:0] normalize(input logic [19:0] sum);
        logic [19:0] avg;
        avg = sum / WEIGHT_SUM;
        normalize = (avg > 20'd15) ? 4'hF : avg[3:0];
    endfunction

    logic [3:0] blur_r, blur_g, blur_b;
    assign blur_r = normalize(sum_r);
    assign blur_g = normalize(sum_g);
    assign blur_b = normalize(sum_b);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= '0;
        end else if (pclk) begin
            o_rgb <= {blur_r, blur_g, blur_b};   // 항상 블러 결과만 출력
        end
    end

    // ---------------- h_sync / v_sync 지연 ----------------
    logic [LATENCY-1:0] h_sync_d, v_sync_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_d <= {LATENCY{1'b1}};
            v_sync_d <= {LATENCY{1'b1}};
        end else if (pclk) begin
            h_sync_d <= {h_sync_d[LATENCY-2:0], i_h_sync};
            v_sync_d <= {v_sync_d[LATENCY-2:0], i_v_sync};
        end
    end

    assign o_h_sync = h_sync_d[LATENCY-1];
    assign o_v_sync = v_sync_d[LATENCY-1];

endmodule
