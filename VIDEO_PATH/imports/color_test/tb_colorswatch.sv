`timescale 1ns / 1ps

// Tests all 7 point filters (pink/orange/blue/gray/gamma-level0/gamma-level1
// /night) in a single simulation run, feeding all of them the SAME
// colorswatch_input.hex (every RGB444 value, 4096 of them, once each).
//
// Each of these filters is a simple 1-2 stage pipe with NO neighbor-pixel
// lookback (unlike the gaussian blur), so there's no LATENCY/alignment
// headache here -- each filter's own fixed small delay is skipped below.

module tb_colorswatch;

    localparam W = 64;
    localparam H = 64;
    localparam PIXELS = W * H;

    logic clk;
    logic rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic pclk;
    pclk_gen U_PCLK_REF (.clk(clk), .rst_n(rst_n), .pclk(pclk));

    logic [11:0] mem_in [0:PIXELS-1];
    initial $readmemh("colorswatch_input.hex", mem_in);

    integer in_idx;
    logic [11:0] i_rgb;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_idx <= 0;
            i_rgb  <= 12'h000;
        end else if (pclk && in_idx < PIXELS) begin
            i_rgb  <= mem_in[in_idx];
            in_idx <= in_idx + 1;
        end
    end

    // ================= instantiate every filter, always enabled =========
    logic [11:0] o_pink, o_orange, o_blue, o_gray, o_gamma0, o_gamma1, o_night;
    // each filter gets its OWN dummy sync wires -- sharing one pair across
    // all 7 instances meant 7 different modules were all driving the same
    // wire at once (a real multi-driver conflict, likely the source of the X)
    logic hs_pink, vs_pink, hs_orange, vs_orange, hs_blue, vs_blue,
          hs_gray, vs_gray, hs_gamma0, vs_gamma0, hs_gamma1, vs_gamma1,
          hs_night, vs_night;

    pink_filter_pipe U_PINK (
        .clk(clk), .rst_n(rst_n), .pink_en(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_pink), .o_v_sync(vs_pink), .o_rgb(o_pink)
    );

    orange_filter_pipe U_ORANGE (
        .clk(clk), .rst_n(rst_n), .orange_en(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_orange), .o_v_sync(vs_orange), .o_rgb(o_orange)
    );

    blue_filter_pipe U_BLUE (
        .clk(clk), .rst_n(rst_n), .blue_en(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_blue), .o_v_sync(vs_blue), .o_rgb(o_blue)
    );

    gray_filter_pipe U_GRAY (
        .clk(clk), .rst_n(rst_n), .gray_en(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_gray), .o_v_sync(vs_gray), .o_rgb(o_gray)
    );

    gamma_filter_pipe U_GAMMA0 (
        .clk(clk), .rst_n(rst_n), .gamma_en(1'b1), .gamma_level(1'b0),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_gamma0), .o_v_sync(vs_gamma0), .o_rgb(o_gamma0)
    );

    gamma_filter_pipe U_GAMMA1 (
        .clk(clk), .rst_n(rst_n), .gamma_en(1'b1), .gamma_level(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_gamma1), .o_v_sync(vs_gamma1), .o_rgb(o_gamma1)
    );

    night_filter_pipe U_NIGHT (
        .clk(clk), .rst_n(rst_n), .night_en(1'b1),
        .i_h_sync(1'b1), .i_v_sync(1'b1), .i_rgb(i_rgb),
        .o_h_sync(hs_night), .o_v_sync(vs_night), .o_rgb(o_night)
    );

    // ================= capture: each filter skips its OWN latency ========
    // each filter's own internal stages, PLUS 1 for the testbench's own
    // i_rgb feed register (i_rgb <= mem_in[in_idx] above) which adds a
    // cycle of delay before the DUT even sees the pixel
    localparam LAT_PINK   = 1;
    localparam LAT_ORANGE = 1;
    localparam LAT_BLUE   = 1;
    localparam LAT_GRAY   = 1;
    localparam LAT_GAMMA  = 1;
    localparam LAT_NIGHT  = 1;

    integer f_pink, f_orange, f_blue, f_gray, f_gamma0, f_gamma1, f_night;
    integer tick, w_pink, w_orange, w_blue, w_gray, w_gamma0, w_gamma1, w_night;

    initial begin
        f_pink   = $fopen("colorswatch_rtl_pink.hex",   "w");
        f_orange = $fopen("colorswatch_rtl_orange.hex", "w");
        f_blue   = $fopen("colorswatch_rtl_blue.hex",   "w");
        f_gray   = $fopen("colorswatch_rtl_gray.hex",   "w");
        f_gamma0 = $fopen("colorswatch_rtl_gamma0.hex", "w");
        f_gamma1 = $fopen("colorswatch_rtl_gamma1.hex", "w");
        f_night  = $fopen("colorswatch_rtl_night.hex",  "w");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 0;
            w_pink <= 0; w_orange <= 0; w_blue <= 0; w_gray <= 0;
            w_gamma0 <= 0; w_gamma1 <= 0; w_night <= 0;
        end else if (pclk) begin
            tick <= tick + 1;

            if (tick >= LAT_PINK && w_pink < PIXELS) begin
                $fwrite(f_pink, "%03x\n", o_pink); w_pink <= w_pink + 1;
            end
            if (tick >= LAT_ORANGE && w_orange < PIXELS) begin
                $fwrite(f_orange, "%03x\n", o_orange); w_orange <= w_orange + 1;
            end
            if (tick >= LAT_BLUE && w_blue < PIXELS) begin
                $fwrite(f_blue, "%03x\n", o_blue); w_blue <= w_blue + 1;
            end
            if (tick >= LAT_GRAY && w_gray < PIXELS) begin
                $fwrite(f_gray, "%03x\n", o_gray); w_gray <= w_gray + 1;
            end
            if (tick >= LAT_GAMMA && w_gamma0 < PIXELS) begin
                $fwrite(f_gamma0, "%03x\n", o_gamma0); w_gamma0 <= w_gamma0 + 1;
            end
            if (tick >= LAT_GAMMA && w_gamma1 < PIXELS) begin
                $fwrite(f_gamma1, "%03x\n", o_gamma1); w_gamma1 <= w_gamma1 + 1;
            end
            if (tick >= LAT_NIGHT && w_night < PIXELS) begin
                $fwrite(f_night, "%03x\n", o_night); w_night <= w_night + 1;
            end

            if (w_pink == PIXELS && w_orange == PIXELS && w_blue == PIXELS &&
                w_gray == PIXELS && w_gamma0 == PIXELS && w_gamma1 == PIXELS &&
                w_night == PIXELS) begin
                $fclose(f_pink); $fclose(f_orange); $fclose(f_blue);
                $fclose(f_gray); $fclose(f_gamma0); $fclose(f_gamma1);
                $fclose(f_night);
                $display("done: all 7 filter outputs written");
                $finish;
            end
        end
    end

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        #10_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule