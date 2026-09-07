`timescale 1ns / 1ps

// Sends one byte over UART: start bit, 8 data bits, stop bit.

module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   =115200   // must match the baud rate on the other board
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic [7:0]  tx_data,
    input  logic        tx_start,
    output logic        tx_busy,

    output logic        tx        // UART TX pin
);

    localparam integer BIT_PERIOD = CLK_FREQ_HZ / BAUD_RATE;
    localparam int     CNT_WIDTH  = $clog2(BIT_PERIOD);

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [CNT_WIDTH-1:0] bit_cnt;
    logic [2:0]            data_idx; // 0-7
    logic [7:0]             shift_reg;

    assign tx_busy = (state != IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            data_idx  <= 0;
            shift_reg <= 8'b0;
            tx        <= 1'b1;   // line sits high when idle
        end else begin
            case (state)
                // wait here until someone asks us to send a byte
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        bit_cnt   <= 0;
                        data_idx  <= 0;
                        state     <= START;
                    end
                end

                // start bit = 0
                START: begin
                    tx <= 1'b0;
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 0;
                        state   <= DATA;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // send the 8 data bits, LSB first
                DATA: begin
                    tx <= shift_reg[data_idx];
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 0;
                        if (data_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            data_idx <= data_idx + 1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // stop bit = 1
                STOP: begin
                    tx <= 1'b1;
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= 0;
                        state   <= IDLE;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
