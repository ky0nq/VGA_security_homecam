`timescale 1ns / 1ps

// Button Debounce + One-shot Pulse (active-high)

module btn_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 10
) (
    input  logic clk,
    input  logic rst_n,
    input  logic btn_in,      
    output logic btn_pulse    
);

    localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer DBW = $clog2(DEBOUNCE_CYCLES);

    logic btn_sync0, btn_sync1;
    logic btn_stable;
    logic btn_stable_d;
    logic [DBW-1:0] debounce_cnt;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync0 <= 1'b0;
            btn_sync1 <= 1'b0;
        end else begin
            btn_sync0 <= btn_in;
            btn_sync1 <= btn_sync0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            debounce_cnt <= '0;
            btn_stable   <= 1'b0;
        end else if (btn_sync1 != btn_stable) begin
            if (debounce_cnt == DEBOUNCE_CYCLES - 1) begin
                btn_stable   <= btn_sync1;
                debounce_cnt <= '0;
            end else begin
                debounce_cnt <= debounce_cnt + 1'b1;
            end
        end else begin
            debounce_cnt <= '0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_stable_d <= 1'b0;
        end else begin
            btn_stable_d <= btn_stable;
        end
    end

    assign btn_pulse = btn_stable & ~btn_stable_d;

endmodule
