`timescale 1ns / 1ps

// ============================================================
// uart_tx
//   표준 8N1(start 1 + data 8 + stop 1, parity 없음) UART 송신기
//   tx_start : 1클럭 펄스로 전송 시작 요청
//   tx_busy  : 전송 중이면 1 (전송 중엔 tx_start 무시됨)
// ============================================================
module uart_tx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   =115200   // 상대 보드 수신측이랑 반드시 일치해야 함
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic [7:0]  tx_data,
    input  logic        tx_start,
    output logic        tx_busy,

    output logic        tx        // UART TX 핀
);

    localparam integer BIT_PERIOD = CLK_FREQ_HZ / BAUD_RATE;
    localparam int     CNT_WIDTH  = $clog2(BIT_PERIOD);

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [CNT_WIDTH-1:0] bit_cnt;
    logic [2:0]            data_idx; // 0~7
    logic [7:0]             shift_reg;

    assign tx_busy = (state != IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            data_idx  <= 0;
            shift_reg <= 8'b0;
            tx        <= 1'b1;   // idle 상태는 항상 1 (UART 라인 idle level)
        end else begin
            case (state)
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

                // 데이터 8비트, LSB부터
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