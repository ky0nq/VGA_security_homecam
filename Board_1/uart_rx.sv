`timescale 1ns / 1ps

// Receives one byte over UART: start bit, 8 data bits, stop bit.

module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,        // UART RX pin, comes from outside so it is not synced yet

    output logic [7:0]  rx_data,
    output logic        rx_done    // 1-clock pulse
);

    localparam integer BIT_PERIOD   = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF_PERIOD  = BIT_PERIOD / 2;
    localparam int     CNT_WIDTH    = $clog2(BIT_PERIOD);

    // ---------------- 2-flop sync for the rx pin ----------------
    logic rx_sync0, rx_sync1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    // ---------------- state machine ----------------
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [CNT_WIDTH-1:0] bit_cnt;   // how far we are into the current bit
    logic [2:0]            data_idx; // which data bit (0-7) we are on
    logic [7:0]             shift_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            data_idx  <= 0;
            shift_reg <= 8'b0;
            rx_data   <= 8'b0;
            rx_done   <= 1'b0;
        end else begin
            rx_done <= 1'b0; // default 0 every clock, only set for 1 clock when a byte finishes

            case (state)
                // wait for the falling edge of the start bit
                IDLE: begin
                    bit_cnt <= 0;
                    if (!rx_sync1) begin
                        state <= START;
                    end
                end

                // check the middle of the start bit again, in case it was just noise
                START: begin
                    if (bit_cnt == HALF_PERIOD - 1) begin
                        if (!rx_sync1) begin
                            bit_cnt  <= 0;
                            data_idx <= 0;
                            state    <= DATA;
                        end else begin
                            state <= IDLE; // was noise, go back and wait again
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // sample each of the 8 data bits in the middle of its period, LSB first
                DATA: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt          <= 0;
                        shift_reg[data_idx] <= rx_sync1;
                        if (data_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            data_idx <= data_idx + 1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // wait out the stop bit, then the byte is done
                STOP: begin
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        rx_data <= shift_reg;
                        rx_done <= 1'b1;
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
