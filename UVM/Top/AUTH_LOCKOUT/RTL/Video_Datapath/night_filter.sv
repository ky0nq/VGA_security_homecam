`timescale 1ns / 1ps

// Night Vision : 밝기를 크게 부스트(감마 0.5)한 뒤 Green 채널에 집중,
// R/B는 거의 꺼서 야간투시경(이미지 인텐시파이어) 특유의 녹색 단색 화면을 만든다.
module night_filter_pipe (
    input logic clk,
    input logic rst_n,
    input logic night_en,
    input logic i_h_sync,
    input logic i_v_sync,
    input logic [11:0] i_rgb,

    output logic o_h_sync,
    output logic o_v_sync,
    output logic [11:0] o_rgb
);
    localparam LATENCY = 2;

    localparam logic [3:0] LUT_BOOST[0:15] = '{
        4'd0, 4'd4, 4'd5, 4'd7, 4'd8, 4'd9, 4'd9, 4'd10,
        4'd11, 4'd12, 4'd12, 4'd13, 4'd13, 4'd14, 4'd14, 4'd15
    };

    // Stage 1 : multiply (밝기 계산용)
    logic [11:0] s1_r, s1_g, s1_b, s1_rgb;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_r   <= 0;
            s1_g   <= 0;
            s1_b   <= 0;
            s1_rgb <= 0;
        end else begin
            s1_r   <= 8'd77 * i_rgb[11:8];
            s1_g   <= 8'd150 * i_rgb[7:4];
            s1_b   <= 8'd29 * i_rgb[3:0];
            s1_rgb <= i_rgb;
        end
    end

    // Stage 2 : add, shift → 밝기값을 부스트 후 녹색 단색으로 매핑, mux
    logic [11:0] y_sum;
    logic [ 3:0] gray;
    logic [ 3:0] night_r, night_g, night_b;

    assign y_sum = s1_r + s1_g + s1_b;
    assign gray  = y_sum[11:8];

    assign night_r = gray >> 3;        // gray * 0.125 (거의 0)
    assign night_g = LUT_BOOST[gray];  // 저조도 부스트 (감마 0.5)
    assign night_b = gray >> 3;        // gray * 0.125 (거의 0)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= 0;
        end else begin
            o_rgb <= night_en ? {night_r, night_g, night_b} : s1_rgb;
        end
    end

    logic [LATENCY-1:0] h_sync_d, v_sync_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_sync_d <= {LATENCY{1'b1}};
            v_sync_d <= {LATENCY{1'b1}};
        end
        else begin
            h_sync_d <= {h_sync_d[LATENCY-2:0], i_h_sync};
            v_sync_d <= {v_sync_d[LATENCY-2:0], i_v_sync};
        end
    end

    assign o_h_sync = h_sync_d[LATENCY-1];
    assign o_v_sync = v_sync_d[LATENCY-1];

endmodule
