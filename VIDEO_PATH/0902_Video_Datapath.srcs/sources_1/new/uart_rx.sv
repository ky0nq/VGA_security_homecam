`timescale 1ns / 1ps

// ============================================================
// uart_rx
// ============================================================
module uart_rx #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE   = 9600  
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       rx,        // UART RX 핀 (외부 입력, 비동기)

    output logic [7:0]  rx_data,
    output logic        rx_done    // 1클럭 펄스
);

    localparam integer BIT_PERIOD   = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer HALF_PERIOD  = BIT_PERIOD / 2;
    localparam int     CNT_WIDTH    = $clog2(BIT_PERIOD);

    // ---------------- 2-FF 동기화 (비동기 rx 핀) ----------------
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

    // ---------------- FSM ----------------
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t state;

    logic [CNT_WIDTH-1:0] bit_cnt;   // 현재 비트 구간 안에서의 클럭 카운트
    logic [2:0]            data_idx; // 0~7, 몇 번째 데이터 비트인지
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
            rx_done <= 1'b0; // 기본값: 매 클럭 0, DATA→STOP 전이 시 1클럭만 세팅

            case (state)
                // start bit(0)의 하강 에지를 기다림
                IDLE: begin
                    bit_cnt <= 0;
                    if (!rx_sync1) begin
                        state <= START;
                    end
                end

                // start bit 한가운데서 다시 한 번 0인지 확인(노이즈 방지)
                START: begin
                    if (bit_cnt == HALF_PERIOD - 1) begin
                        if (!rx_sync1) begin
                            bit_cnt  <= 0;
                            data_idx <= 0;
                            state    <= DATA;
                        end else begin
                            state <= IDLE; // 노이즈였음, 취소
                        end
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end

                // 데이터 8비트, 각 비트 구간의 한가운데서 샘플링, LSB부터
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

                // stop bit(1) 구간 다 지나면 완료 처리
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