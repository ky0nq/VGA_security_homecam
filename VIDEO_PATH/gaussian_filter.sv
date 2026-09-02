`timescale 1ns / 1ps

// Blurs the picture by averaging a WIN x WIN block of pixels around each pixel.

module gauss_filter_pipe #(
    parameter int IMG_WIDTH = 800,  // pclk ticks per line (H_Whole_line)
    parameter int WIN       = 16    // size of one side of the average window
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
    // +4 because the sum is split into 2 pipeline stages (row sum, then total sum)
    localparam int LATENCY    = (WIN - 1) * IMG_WIDTH + WIN + 4;

    // ---------------- make our own pixel clock enable ----------------
    logic pclk;
    pclk_gen U_PCLK_GEN (
        .clk   (clk),
        .rst_n (rst_n),
        .pclk  (pclk)
    );

    // ---------------- Stage 0: grab the incoming pixel ----------------
    logic [11:0] rgb_in_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rgb_in_r <= '0;
        else if (pclk) rgb_in_r <= i_rgb;
    end

    // row_stream[0] is the current line, row_stream[WIN-1] is WIN-1 lines above it
    logic [11:0] row_stream [0:WIN-1];
    assign row_stream[0] = rgb_in_r;

    // one line buffer per extra row we need, each one delays by a full line
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

    // col_tap[row][0] is the newest pixel on that row, col_tap[row][WIN-1] is WIN-1 pixels ago
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

    // ---------------- Stage 1 : add up WIN pixels per row, one adder per row ----------------
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
            // register the row sum so we don't try to add everything in one clock
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

    // ---------------- Stage 2 : add the WIN row sums into one final total ----------------
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

    // ---------------- divide by the pixel count and register the output ----------------
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

    // ---------------- delay h_sync / v_sync to match the pixel delay above ----------------
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
