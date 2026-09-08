`timescale 1ns / 1ps

// module gray_filter(
//     input logic [11:0] i_rgb,
//     output logic [11:0] o_rgb
// );
//     logic [11:0] y;

//     assign y = (77 * i_rgb[11:8]) +  (150 * i_rgb[7:4]) +  (29 * i_rgb[3:0]);
//     assign o_rgb = {y[11:8], y[11:8], y[11:8]}; // 256 곱해서 상위 4-bit
// endmodule

module gray_filter_pipe (
    input logic clk,
    input logic rst_n,
    input logic gray_en,
    input logic i_h_sync,
    input logic i_v_sync,
    input logic [11:0] i_rgb,

    output logic o_h_sync,
    output logic o_v_sync,
    output logic [11:0] o_rgb
);
    localparam LATENCY = 2;

    // Stage 1 : multiply
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
    // State 2 : add, shift, mux
    logic [11:0] y_sum;
    logic [ 3:0] gray;

    assign y_sum = s1_r + s1_g + s1_b;
    assign gray  = y_sum[11:8];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_rgb <= 0;
        end else begin  
            o_rgb <= gray_en ? {gray, gray, gray} : s1_rgb;
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
