`timescale 1ns / 1ps

// =================================================================================
// Module: counter_10s
// Description: Counts up to 10 seconds (resets on rx_done) and outputs a 1-clock
//              pulse (done_10s) and status byte (8'h80) upon reaching 10 seconds.
// =================================================================================

module counter_10s #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       rx_done,     // Resets counter on new UART reception

    output logic       done_10s,    // 1-clock pulse when 10-second timeout is reached
    output logic [7:0] data_10s     // Outputs 8'h80 on timeout, 8'h00 otherwise
);

    localparam integer TICK_CYCLES = CLK_FREQ_HZ;
    localparam int     TICK_WIDTH  = $clog2(TICK_CYCLES);

    // 1Hz Tick Generator
    logic [TICK_WIDTH-1:0] tick_cnt;
    logic                  tick;

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

    // Second Counter (0 to 10)
    logic [3:0] sec_cnt;
    logic       reach_10;

    assign reach_10 = tick && (sec_cnt == 4'd9);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt <= 4'd0;
        end else if (rx_done) begin
            sec_cnt <= 4'd0;
        end else if (tick && sec_cnt < 4'd10) begin
            sec_cnt <= sec_cnt + 4'd1;
        end
    end

    // Timeout Output Generation
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
