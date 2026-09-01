`timescale 1ns / 1ps

module auth_control_unit #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic       clk,
    input  logic       rst_n,

    // System Control Unit에서 전달
    input  logic       i_auth_start,
    input  logic       i_pattern_clear,

    // Grid Stabilizer 결과
    // 아래 신호들은 clk 도메인으로 CDC가 완료된 신호여야 함
    input  logic       i_grid_enter_pulse,
    input  logic       i_grid_valid,
    input  logic [3:0] i_grid_id,
    input  logic       i_marker_valid,

    // System Control Unit으로 전달
    output logic       o_unlock_pass,
    output logic       o_unlock_fail,

    // Board 1 Video Path 제어
    output logic       o_auth_active,
    output logic       o_path_clear,

    // 디버깅용
    output logic [1:0] o_state,
    output logic [2:0] o_pattern_index
);

    // =========================================================
    // 등록 패턴
    // 1 -> 2 -> 3 -> 6 -> 5 -> 8
    // =========================================================
    localparam integer PATTERN_LENGTH = 6;
    localparam logic [3:0] FINAL_GRID = 4'd8;

    function automatic logic [3:0] get_expected_grid(
        input logic [2:0] index
    );
        begin
            case (index)
                3'd0: get_expected_grid = 4'd1;
                3'd1: get_expected_grid = 4'd2;
                3'd2: get_expected_grid = 4'd3;
                3'd3: get_expected_grid = 4'd6;
                3'd4: get_expected_grid = 4'd5;
                3'd5: get_expected_grid = 4'd8;
                default: get_expected_grid = 4'd0;
            endcase
        end
    endfunction

    // =========================================================
    // FSM 상태
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE          = 2'b00,
        S_PATTERN_INPUT = 2'b01,
        S_FINAL_HOLD    = 2'b10
    } state_t;

    state_t state;

    // =========================================================
    // 마지막 Grid 1초 유지 타이머
    // =========================================================
    localparam integer HOLD_CYCLES = CLK_FREQ_HZ;

    localparam integer HOLD_COUNTER_WIDTH =
        (HOLD_CYCLES <= 1) ? 1 : $clog2(HOLD_CYCLES);

    localparam logic [HOLD_COUNTER_WIDTH-1:0] HOLD_COUNT_LAST =
        HOLD_CYCLES - 1;

    logic [HOLD_COUNTER_WIDTH-1:0] hold_count;
    logic [2:0] pattern_index;

    assign o_state         = state;
    assign o_pattern_index = pattern_index;

    // INPUT 또는 HOLD 상태에서 인증 기능 활성화
    always_comb begin
        o_auth_active = 1'b0;

        case (state)
            S_PATTERN_INPUT,
            S_FINAL_HOLD: o_auth_active = 1'b1;

            default: o_auth_active = 1'b0;
        endcase
    end

    // =========================================================
    // 인증 FSM
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= S_IDLE;
            pattern_index   <= 3'd0;
            hold_count      <= '0;

            o_unlock_pass   <= 1'b0;
            o_unlock_fail   <= 1'b0;
            o_path_clear    <= 1'b0;
        end
        else begin
            // 기본값: 출력 펄스는 1클럭만 유지
            o_unlock_pass <= 1'b0;
            o_unlock_fail <= 1'b0;
            o_path_clear  <= 1'b0;

            // -------------------------------------------------
            // 외부 Clear가 가장 높은 우선순위
            // 인증 중단 후 IDLE 복귀
            // -------------------------------------------------
            if (i_pattern_clear) begin
                state         <= S_IDLE;
                pattern_index <= 3'd0;
                hold_count    <= '0;
                o_path_clear  <= 1'b1;
            end

            // -------------------------------------------------
            // Start가 들어오면 새 인증 시작
            // 기존 진행 상태와 관계없이 처음부터 시작
            // -------------------------------------------------
            else if (i_auth_start) begin
                state         <= S_PATTERN_INPUT;
                pattern_index <= 3'd0;
                hold_count    <= '0;
                o_path_clear  <= 1'b1;
            end

            else begin
                case (state)

                    // =========================================
                    // 인증 대기
                    // =========================================
                    S_IDLE: begin
                        pattern_index <= 3'd0;
                        hold_count    <= '0;
                    end

                    // =========================================
                    // 패턴 입력 및 즉시 순차 비교
                    // =========================================
                    S_PATTERN_INPUT: begin
                        hold_count <= '0;

                        if (i_grid_enter_pulse && i_grid_valid) begin

                            // 현재 순서의 등록 Grid와 일치
                            if (i_grid_id ==
                                get_expected_grid(pattern_index)) begin

                                // 마지막 패턴 8번까지 일치
                                if (pattern_index ==
                                    PATTERN_LENGTH - 1) begin
                                    state         <= S_FINAL_HOLD;
                                    hold_count    <= '0;
                                end

                                // 다음 패턴 위치로 이동
                                else begin
                                    pattern_index <=
                                        pattern_index + 1'b1;
                                end
                            end

                            // 잘못된 Grid 진입
                            else begin
                                o_unlock_fail <= 1'b1;
                                o_path_clear  <= 1'b1;

                                pattern_index <= 3'd0;
                                hold_count    <= '0;

                                // 즉시 재입력을 위해 INPUT 유지
                                state <= S_PATTERN_INPUT;
                            end
                        end
                    end

                    // =========================================
                    // 마지막 Grid 8번에서 누적 1초 유지
                    // =========================================
                    S_FINAL_HOLD: begin

                        // 다른 Grid에 진입하면 즉시 실패
                        if (i_grid_enter_pulse &&
                            i_grid_valid &&
                            (i_grid_id != FINAL_GRID)) begin

                            o_unlock_fail <= 1'b1;
                            o_path_clear  <= 1'b1;

                            pattern_index <= 3'd0;
                            hold_count    <= '0;

                            // 즉시 재입력
                            state <= S_PATTERN_INPUT;
                        end

                        // 8번 Grid에서 파란색 마커가 검출됨
                        else if (i_marker_valid &&
                                 i_grid_valid &&
                                 (i_grid_id == FINAL_GRID)) begin

                            // 누적 1초 완료
                            if (hold_count >= HOLD_COUNT_LAST) begin
                                o_unlock_pass <= 1'b1;

                                // 성공과 동시에 경로 삭제
                                o_path_clear <= 1'b1;

                                state         <= S_IDLE;
                                pattern_index <= 3'd0;
                                hold_count    <= '0;
                            end

                            // 유지 시간 누적
                            else begin
                                hold_count <= hold_count + 1'b1;
                            end
                        end

                        // 마커 미검출
                        // 별도 대입하지 않아 기존 카운트 유지
                        else begin
                            hold_count <= hold_count;
                        end
                    end

                    default: begin
                        state         <= S_IDLE;
                        pattern_index <= 3'd0;
                        hold_count    <= '0;
                    end

                endcase
            end
        end
    end

endmodule
