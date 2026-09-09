`timescale 1ns / 1ps

// =================================================================================
// Module: uart_tx
// Description: Standard 8N1 UART Transmitter (1 Start bit, 8 Data bits, 1 Stop bit).
// Features:
//   - Triggered by a 1-clock cycle tx_start pulse
//   - Transmits LSB first
//   - Asserts tx_busy signal during transmission
// Parameters:
//   - CLK_FREQ_HZ: System clock frequency (Default: 100 MHz)
//   - BAUD_RATE  : Transmission baud rate (Default: 115200 bps)
// =================================================================================

module uart_tx #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115200
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic [7:0] tx_data,
    input  logic       tx_start,
    output logic       tx_busy,
    output logic       tx_done,

    output logic       tx          // UART TX Output Pin
);

    localparam int BIT_PERIOD = CLK_FREQ_HZ / BAUD_RATE;
    localparam int CNT_WIDTH  = $clog2(BIT_PERIOD);

    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;

    state_t state;

    logic [CNT_WIDTH-1:0] bit_cnt;
    logic [2:0]           data_idx;
    logic [7:0]           shift_reg;

    assign tx_busy = (state != IDLE);

    // UART Transmitter Finite State Machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= '0;
            data_idx  <= 3'd0;
            shift_reg <= 8'd0;
            tx_done   <= 1'b0;
            tx        <= 1'b1;     // Line defaults to HIGH in IDLE state
        end else begin
            // Pulses for one clock when the complete stop bit has been sent.
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        bit_cnt   <= '0;
                        data_idx  <= 3'd0;
                        state     <= START;
                    end
                end

                // Start Bit (LOW)
                START: begin
                    tx <= 1'b0;
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= '0;
                        state   <= DATA;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end

                // 8 Data Bits (LSB First)
                DATA: begin
                    tx <= shift_reg[data_idx];
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= '0;
                        if (data_idx == 3'd7) begin
                            state <= STOP;
                        end else begin
                            data_idx <= data_idx + 1'b1;
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end

                // Stop Bit (HIGH)
                STOP: begin
                    tx <= 1'b1;
                    if (bit_cnt == BIT_PERIOD - 1) begin
                        bit_cnt <= '0;
                        state   <= IDLE;
                        tx_done <= 1'b1;
                    end else begin
                        bit_cnt <= bit_cnt + 1'b1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
