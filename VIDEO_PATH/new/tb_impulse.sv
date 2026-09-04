`timescale 1ns / 1ps

// Objective LATENCY measurement testbench.
// Feeds impulse_input.hex (all zero except one bright pixel at index 0)
// into gauss_filter_pipe, and dumps EVERY output tick from the very start
// (no skipping, no guessing) to impulse_output.hex. Since the input is
// zero everywhere except one point, the output is exactly zero until the
// bright pixel's effect first reaches it -- find that line number in
// Python with measure_latency.py and that number IS the true LATENCY,
// directly measured, no image-content ambiguity possible.

module tb_impulse;

    localparam IMG_W = 320;
    localparam IMG_H = 240;
    localparam WIN   = 16;
    localparam PIXELS = IMG_W * IMG_H;

    // just needs to run comfortably longer than any plausible LATENCY
    localparam CAPTURE_TOTAL = 10000;

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz

    logic [11:0] mem_in [0:PIXELS-1];
    initial $readmemh("impulse_input.hex", mem_in);

    logic pclk;
    pclk_gen U_PCLK_REF (
        .clk  (clk),
        .rst_n(rst_n),
        .pclk (pclk)
    );

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

    logic o_h_sync, o_v_sync;
    logic [11:0] o_rgb;

    gauss_filter_pipe #(
        .IMG_WIDTH(IMG_W),
        .WIN      (WIN)
    ) DUT (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(1'b1),
        .i_v_sync(1'b1),
        .i_rgb   (i_rgb),
        .o_h_sync(o_h_sync),
        .o_v_sync(o_v_sync),
        .o_rgb   (o_rgb)
    );

    integer fout;
    integer captured;

    initial begin
        fout = $fopen("impulse_output.hex", "w");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            captured <= 0;
        end else if (pclk) begin
            if (captured < CAPTURE_TOTAL) begin
                $fwrite(fout, "%03x\n", o_rgb);
                captured <= captured + 1;
                if (captured == CAPTURE_TOTAL - 1) begin
                    $fclose(fout);
                    $display("done: wrote %0d samples to impulse_output.hex", CAPTURE_TOTAL);
                    $finish;
                end
            end
        end
    end

    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        #10_000_000; // 10ms safety net
        $display("TIMEOUT - something is stuck");
        $finish;
    end

endmodule