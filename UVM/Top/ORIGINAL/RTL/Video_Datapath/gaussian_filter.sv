`timescale 1ns / 1ps

// ============================================================
// box_blur_nxn_pipe
//   WIN x WIN 균일 평균(box blur). en 없이 항상 블러링만 출력.
//
//   !!! 합산을 2단 파이프라인으로 분리함 !!!
//   WIN*WIN(예: 400)개를 한 번에 더치는 대신,
//     1단계: 줄(row)별로 WIN개씩 부분합 계산 + 레지스터
//     2단계: 그 부분합 WIN개를 다시 더해 최종합 + 레지스터
//   으로 나눠서 한 클럭당 덧셈 개수를 WIN개 수준으로 줄임.
//   합성 시간이 오래 걸리거나 타이밍이 안 맞는 문제는 대부분
//   "한 클럭 안에 곱셈/덧셈을 너무 많이 우겨넣었을 때" 생기는데,
//   이렇게 단계를 나눠 레지스터로 끊어주는 게 표준적인 해결법
// ============================================================

module gauss_filter_pipe #(
    parameter int IMG_WIDTH = 800,  // 한 줄(H_Whole_line)당 pclk 틱 수
    parameter int WIN       = 16    // 윈도우 한 변의 길이 (3,5,7...20 등 자유)
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

    localparam int WEIGHT_SUM = WIN * WIN;
    // 합산이 2단계(row 부분합 + 최종합)로 늘어나서 +1
    localparam int LATENCY    = (WIN - 1) * IMG_WIDTH + WIN + 4;

    // ---------------- 로컬 pclk 생성 ----------------
    logic pclk;
    pclk_gen U_PCLK_GEN (
        .clk   (clk),
        .rst_n (rst_n),
        .pclk  (pclk)
    );

    // ---------------- Stage 0: 입력 레지스터 ----------------
    logic [11:0] rgb_in_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rgb_in_r <= '0;
        else if (pclk) rgb_in_r <= i_rgb;
    end

    // ---------------- row_stream[0..WIN-1] : 0=현재줄, WIN-1=WIN-1줄 위 ----------------
    logic [11:0] row_stream [0:WIN-1];
    assign row_stream[0] = rgb_in_r;

    genvar r;
    generate
        for (r = 1; r < WIN; r = r + 1) begin : gen_linebuf
            logic [11:0] line_buf [0:IMG_WIDTH-1];
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int k = 0; k < IMG_WIDTH; k = k + 1) line_buf[k] <= '0;
                end else if (pclk) begin
                    for (int k = IMG_WIDTH-1; k > 0; k = k - 1)
                        line_buf[k] <= line_buf[k-1];
                    line_buf[0] <= row_stream[r-1];
                end
            end
            assign row_stream[r] = line_buf[IMG_WIDTH-1];
        end
    endgenerate

    // ---------------- col_tap[row][col] : col=0 방금 ~ col=WIN-1 WIN-1칸 전 ----------------
    logic [11:0] col_tap [0:WIN-1][0:WIN-1];

    genvar rr;
    generate
        for (rr = 0; rr < WIN; rr = rr + 1) begin : gen_colshift
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int c = 0; c < WIN; c = c + 1) col_tap[rr][c] <= '0;
                end else if (pclk) begin
                    for (int c = WIN-1; c > 0; c = c - 1)
                        col_tap[rr][c] <= col_tap[rr][c-1];
                    col_tap[rr][0] <= row_stream[rr];
                end
            end
        end
    endgenerate

    // ---------------- 1단계 : 줄(row)별 부분합 (WIN개씩, 조합 -> 레지스터) ----------------
    logic [15:0] row_sum_r_c [0:WIN-1];
    logic [15:0] row_sum_g_c [0:WIN-1];
    logic [15:0] row_sum_b_c [0:WIN-1];
    logic [15:0] row_sum_r   [0:WIN-1];
    logic [15:0] row_sum_g   [0:WIN-1];
    logic [15:0] row_sum_b   [0:WIN-1];

    genvar rs;
    generate
        for (rs = 0; rs < WIN; rs = rs + 1) begin : gen_row_sum
            always_comb begin
                row_sum_r_c[rs] = '0;
                row_sum_g_c[rs] = '0;
                row_sum_b_c[rs] = '0;
                for (int c = 0; c < WIN; c = c + 1) begin
                    row_sum_r_c[rs] = row_sum_r_c[rs] + col_tap[rs][c][11:8];
                    row_sum_g_c[rs] = row_sum_g_c[rs] + col_tap[rs][c][7:4];
                    row_sum_b_c[rs] = row_sum_b_c[rs] + col_tap[rs][c][3:0];
                end
            end
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    row_sum_r[rs] <= '0;
                    row_sum_g[rs] <= '0;
                    row_sum_b[rs] <= '0;
                end else if (pclk) begin
                    row_sum_r[rs] <= row_sum_r_c[rs];
                    row_sum_g[rs] <= row_sum_g_c[rs];
                    row_sum_b[rs] <= row_sum_b_c[rs];
                end
            end
        end
    endgenerate

    // ---------------- 2단계 : row 부분합 WIN개를 최종 합산 (조합 -> 레지스터) ----------------
    logic [23:0] sum_r_c, sum_g_c, sum_b_c;
    logic [23:0] sum_r,   sum_g,   sum_b;

    always_comb begin
        sum_r_c = '0; sum_g_c = '0; sum_b_c = '0;
        for (int rs2 = 0; rs2 < WIN; rs2 = rs2 + 1) begin
            sum_r_c = sum_r_c + row_sum_r[rs2];
            sum_g_c = sum_g_c + row_sum_g[rs2];
            sum_b_c = sum_b_c + row_sum_b[rs2];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_r <= '0; sum_g <= '0; sum_b <= '0;
        end else if (pclk) begin
            sum_r <= sum_r_c;
            sum_g <= sum_g_c;
            sum_b <= sum_b_c;
        end
    end

    // ---------------- 정규화 + 출력 레지스터 ----------------
    function automatic logic [3:0] normalize(input logic [23:0] sum);
        logic [23:0] avg;
        avg = sum / WEIGHT_SUM;
        normalize = (avg > 24'd15) ? 4'hF : avg[3:0];
    endfunction

    logic [3:0] blur_r, blur_g, blur_b;
    assign blur_r = normalize(sum_r);
    assign blur_g = normalize(sum_g);
    assign blur_b = normalize(sum_b);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= '0;
        end else if (pclk) begin
            o_rgb <= {blur_r, blur_g, blur_b};
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