`timescale 1ns / 1ps

// Counts seconds using the clock and sends a pulse if no rx_done comes in for 10 seconds.

module counter_10s #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx_done,      // from uart, new data resets the counter

    output logic        done_10s,  // 1-clock pulse when we hit 10 seconds
    output logic [7:0] data_10s   // 8'h80 for that one clock, 8'h00 otherwise
);

    localparam integer TICK_CYCLES = CLK_FREQ_HZ;      // 1 second worth of clocks
    localparam int      TICK_WIDTH  = $clog2(TICK_CYCLES);

    //============================================================
    // make a 1Hz tick
    //============================================================
    logic [TICK_WIDTH-1:0] tick_cnt;
    logic                   tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= '0;
            tick     <= 1'b0;
        end else if (tick_cnt == TICK_CYCLES - 1) begin
            tick_cnt <= '0;
            tick     <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick     <= 1'b0;
        end
    end

    //============================================================
    // second counter, 0 to 10, reset by rx_done, stops counting at 10
    //============================================================
    logic [3:0] sec_cnt;
    logic        reach_10; // true only the exact tick that pushes sec_cnt from 9 to 10

    assign reach_10 = tick && (sec_cnt == 4'd9);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt <= 4'd0;
        end else if (rx_done) begin
            sec_cnt <= 4'd0;            // new data came in, start over
        end else if (tick && sec_cnt < 4'd10) begin
            sec_cnt <= sec_cnt + 4'd1;  // stop at 10, do not wrap around
        end
    end

    //============================================================
    // at the moment we hit 10 seconds: done_10s pulses and data_10s = 8'h80
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_10s <= 1'b0;
            data_10s <= 8'h00;
        end else begin
            done_10s <= reach_10;
            data_10s <= reach_10 ? 8'h80 : 8'h00;
        end
    end

endmodule
