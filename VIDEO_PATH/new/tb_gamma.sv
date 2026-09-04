`timescale 1ns / 1ps

// Minimal, standalone test for JUST gamma_filter_pipe -- no other
// modules, no shared testbench, nothing that could get cached wrong.
// Feeds a few known values and prints them straight to the console.

module tb_gamma;

    logic clk;
    logic rst_n;
    initial clk = 0;
    always #5 clk = ~clk;

    logic gamma_en;
    logic gamma_level;
    logic [11:0] i_rgb;
    logic o_h_sync, o_v_sync;
    logic [11:0] o_rgb;

    gamma_filter_pipe DUT (
        .clk(clk), .rst_n(rst_n),
        .gamma_en(gamma_en), .gamma_level(gamma_level),
        .i_h_sync(1'b1), .i_v_sync(1'b1),
        .i_rgb(i_rgb),
        .o_h_sync(o_h_sync), .o_v_sync(o_v_sync), .o_rgb(o_rgb)
    );

    initial begin
        gamma_en    = 1'b1;
        gamma_level = 1'b0;
        i_rgb       = 12'h000;
        rst_n       = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        i_rgb = 12'hFFF;
        @(posedge clk);
        @(posedge clk);
        $display("i_rgb=fff -> o_rgb=%h  (expect fff, since fff means brightness 15 -> LUT_G07[15]=15)", o_rgb);

        i_rgb = 12'h000;
        @(posedge clk);
        @(posedge clk);
        $display("i_rgb=000 -> o_rgb=%h  (expect 000)", o_rgb);

        i_rgb = 12'h555;
        @(posedge clk);
        @(posedge clk);
        $display("i_rgb=555 -> o_rgb=%h  (expect nonzero, R=G=B=5 -> LUT_G07[5]=7 -> 777)", o_rgb);

        $finish;
    end

endmodule