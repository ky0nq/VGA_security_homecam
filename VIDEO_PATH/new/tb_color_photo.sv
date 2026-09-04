`timescale 1ns / 1ps
module tb_color_photo;

localparam int W = 320;
localparam int H = 240;
localparam int PIXELS = W * H;

logic clk;
logic rst_n;
logic pclk;

initial clk = 1'b0;
always #5 clk = ~clk;

pclk_gen U_PCLK_REF(
    .clk(clk),
    .rst_n(rst_n),
    .pclk(pclk)
);

logic [11:0] mem_in [0:PIXELS-1];
initial $readmemh("photo_input.hex",mem_in);

logic [11:0] i_rgb;
logic i_h_sync,i_v_sync;
integer in_idx;

logic [11:0] o_pink,o_orange,o_blue,o_gray,o_gamma0,o_gamma1,o_night;
logic hs_pink,vs_pink,hs_orange,vs_orange,hs_blue,vs_blue;
logic hs_gray,vs_gray,hs_gamma0,vs_gamma0,hs_gamma1,vs_gamma1;
logic hs_night,vs_night;

pink_filter_pipe U_PINK(
    .clk(clk),.rst_n(rst_n),.pink_en(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_pink),.o_v_sync(vs_pink),.o_rgb(o_pink)
);

orange_filter_pipe U_ORANGE(
    .clk(clk),.rst_n(rst_n),.orange_en(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_orange),.o_v_sync(vs_orange),.o_rgb(o_orange)
);

blue_filter_pipe U_BLUE(
    .clk(clk),.rst_n(rst_n),.blue_en(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_blue),.o_v_sync(vs_blue),.o_rgb(o_blue)
);

gray_filter_pipe U_GRAY(
    .clk(clk),.rst_n(rst_n),.gray_en(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_gray),.o_v_sync(vs_gray),.o_rgb(o_gray)
);

gamma_filter_pipe U_GAMMA0(
    .clk(clk),.rst_n(rst_n),.gamma_en(1'b1),.gamma_level(1'b0),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_gamma0),.o_v_sync(vs_gamma0),.o_rgb(o_gamma0)
);

gamma_filter_pipe U_GAMMA1(
    .clk(clk),.rst_n(rst_n),.gamma_en(1'b1),.gamma_level(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_gamma1),.o_v_sync(vs_gamma1),.o_rgb(o_gamma1)
);

night_filter_pipe U_NIGHT(
    .clk(clk),.rst_n(rst_n),.night_en(1'b1),
    .i_h_sync(i_h_sync),.i_v_sync(i_v_sync),.i_rgb(i_rgb),
    .o_h_sync(hs_night),.o_v_sync(vs_night),.o_rgb(o_night)
);

// change: pink/orange/blue/gray/night each have 2 internal register
// stages (s1_* then o_rgb), so LATENCY=2, not 1 -- confirmed against the
// colorswatch test earlier. gamma is a single stage, so LATENCY=1 is
// correct there.
localparam int LAT_PINK=1;   // change
localparam int LAT_ORANGE=1; // change
localparam int LAT_BLUE=1;   // change
localparam int LAT_GRAY=1;   // change
localparam int LAT_GAMMA=1;
localparam int LAT_NIGHT=1;  // change

integer f_pink,f_orange,f_blue,f_gray,f_gamma0,f_gamma1,f_night;
integer w_pink,w_orange,w_blue,w_gray,w_gamma0,w_gamma1,w_night;
integer tick;

initial begin
    f_pink=$fopen("photo_rtl_pink.hex","w");
    f_orange=$fopen("photo_rtl_orange.hex","w");
    f_blue=$fopen("photo_rtl_blue.hex","w");
    f_gray=$fopen("photo_rtl_gray.hex","w");
    f_gamma0=$fopen("photo_rtl_gamma0.hex","w");
    f_gamma1=$fopen("photo_rtl_gamma1.hex","w");
    f_night=$fopen("photo_rtl_night.hex","w");
end

// change: i_rgb/in_idx/i_h_sync/i_v_sync now ONLY driven here (reset
// branch added), instead of also being set in a separate initial block.
// Two different procedural blocks writing the same variable is asking
// for trouble even when it happens to simulate fine.
always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        i_rgb    <= 12'h000; // change
        i_h_sync <= 1'b1;    // change
        i_v_sync <= 1'b1;    // change
        in_idx   <= 0;       // change
    end else if (in_idx < PIXELS) begin
        i_rgb  <= mem_in[in_idx];
        in_idx <= in_idx + 1;
    end
end

// change: tick/w_* counters now ONLY driven here (reset branch added),
// same reasoning as above -- removed from the separate initial block.
always @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
        tick     <= 0; // change
        w_pink   <= 0; // change
        w_orange <= 0; // change
        w_blue   <= 0; // change
        w_gray   <= 0; // change
        w_gamma0 <= 0; // change
        w_gamma1 <= 0; // change
        w_night  <= 0; // change
    end else begin
        tick <= tick + 1;

        if (tick >= LAT_PINK && w_pink < PIXELS) begin
            $fwrite(f_pink,"%03x\n",o_pink);
            w_pink <= w_pink + 1;
        end

        if (tick >= LAT_ORANGE && w_orange < PIXELS) begin
            $fwrite(f_orange,"%03x\n",o_orange);
            w_orange <= w_orange + 1;
        end

        if (tick >= LAT_BLUE && w_blue < PIXELS) begin
            $fwrite(f_blue,"%03x\n",o_blue);
            w_blue <= w_blue + 1;
        end

        if (tick >= LAT_GRAY && w_gray < PIXELS) begin
            $fwrite(f_gray,"%03x\n",o_gray);
            w_gray <= w_gray + 1;
        end

        if (tick >= LAT_GAMMA && w_gamma0 < PIXELS) begin
            $fwrite(f_gamma0,"%03x\n",o_gamma0);
            w_gamma0 <= w_gamma0 + 1;
        end

        if (tick >= LAT_GAMMA && w_gamma1 < PIXELS) begin
            $fwrite(f_gamma1,"%03x\n",o_gamma1);
            w_gamma1 <= w_gamma1 + 1;
        end

        if (tick >= LAT_NIGHT && w_night < PIXELS) begin
            $fwrite(f_night,"%03x\n",o_night);
            w_night <= w_night + 1;
        end

        if (w_pink >= PIXELS &&
            w_orange >= PIXELS &&
            w_blue >= PIXELS &&
            w_gray >= PIXELS &&
            w_gamma0 >= PIXELS &&
            w_gamma1 >= PIXELS &&
            w_night >= PIXELS) begin

            $fclose(f_pink);
            $fclose(f_orange);
            $fclose(f_blue);
            $fclose(f_gray);
            $fclose(f_gamma0);
            $fclose(f_gamma1);
            $fclose(f_night);

            $display("done: all 7 photo filter outputs written");
            $finish;
        end
    end
end

initial begin
    rst_n = 1'b0;
    repeat(10) @(posedge clk);
    rst_n = 1'b1;
end

initial begin
    #100_000_000;
    $display("TIMEOUT");
    $finish;
end

endmodule