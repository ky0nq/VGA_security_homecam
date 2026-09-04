`timescale 1ns / 1ps

// Testbench for gauss_filter_pipe (box blur).
// Reads gaussian_input.hex, feeds it in pixel by pixel, and dumps every
// output pixel to gaussian_rtl_output.hex in the same format so it can be
// compared against gaussian_golden.hex with compare_rtl.py.
//
// IMG_WIDTH is set to 320 here (not 800) because this test feeds the raw
// photo directly with no VGA blanking gaps - it is testing gauss_filter_pipe
// on its own, not wired into the real video_path.

module tb_gauss_filter;

    localparam IMG_W = 320;
    localparam IMG_H = 240;
    localparam WIN   = 16;
    localparam PIXELS = IMG_W * IMG_H;

    // the RTL always delays the pixel stream by this many pclk ticks before
    // the output lines up with the input again - see gauss_filter_pipe.sv
    localparam LATENCY = (WIN - 1) * IMG_W + WIN - 4;
    // localparam LATENCY = 100;

    logic clk;
    logic rst_n;

    initial clk = 0;
    always #5 clk = ~clk;   // 100MHz

    // ---------------- load the input picture ----------------
    logic [11:0] mem_in [0:PIXELS-1];
    initial $readmemh("gaussian_input.hex", mem_in);

    // ---------------- reference pclk, same divide-by-4 as the DUT uses ----
    // Instantiating the same pclk_gen here, off the same clk/rst_n, keeps it
    // in lockstep with the pclk_gen the DUT builds internally.
    logic pclk;
    pclk_gen U_PCLK_REF (
        .clk  (clk),
        .rst_n(rst_n),
        .pclk (pclk)
    );

    // ---------------- feed pixels in, one per pclk tick ----------------
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

    // ---------------- DUT ----------------
    logic o_h_sync, o_v_sync;
    logic [11:0] o_rgb;

    gauss_filter_pipe #(
        .IMG_WIDTH(IMG_W),
        .WIN      (WIN)
    ) DUT (
        .clk     (clk),
        .rst_n   (rst_n),
        .i_h_sync(1'b1),   // not needed for a pixel-value-only comparison
        .i_v_sync(1'b1),
        .i_rgb   (i_rgb),
        .o_h_sync(o_h_sync),
        .o_v_sync(o_v_sync),
        .o_rgb   (o_rgb)
    );

    // ---------------- capture output, skipping the first LATENCY samples
    // so gaussian_rtl_output.hex lines up 1-for-1 with gaussian_golden.hex
    integer fout;
    integer tick_count;
    integer written;

    initial begin
        fout = $fopen("gaussian_rtl_output.hex", "w");
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count <= 0;
            written    <= 0;
        end else if (pclk) begin
            tick_count <= tick_count + 1;
            if (tick_count >= LATENCY && written < PIXELS) begin
                $fwrite(fout, "%03x\n", o_rgb);
                written <= written + 1;
                if (written == PIXELS - 1) begin
                    $fclose(fout);
                    $display("done: wrote %0d pixels to gaussian_rtl_output.hex", PIXELS);
                    $finish;
                end
            end
        end
    end

    // ---------------- reset + safety timeout ----------------
    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
    end

    initial begin
        #200_000_000;  // 200ms sim time safety net, in case something stalls
        $display("TIMEOUT - something is stuck, check pclk/rst_n");
        $finish;
    end

endmodule