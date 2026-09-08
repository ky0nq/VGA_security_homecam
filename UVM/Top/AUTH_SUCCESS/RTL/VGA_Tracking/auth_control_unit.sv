`timescale 1ns / 1ps

module auth_control_unit #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic       clk,
    input  logic       rst_n,

    // From the system control unit
    input  logic       i_auth_start,
    input  logic       i_pattern_clear,

    // Grid stabilizer result
    // These signals must already be synchronized to clk.
    input  logic       i_grid_enter_pulse,
    input  logic       i_grid_valid,
    input  logic [3:0] i_grid_id,
    input  logic       i_marker_valid,

    // To the system control unit
    output logic       o_unlock_pass,
    output logic       o_unlock_fail,

    // Board 1 video-path control
    output logic       o_auth_active,
    output logic       o_path_clear,

    // Debug output
    output logic [1:0] o_state,
    output logic [2:0] o_pattern_index
);

    // =========================================================
    // Stored pattern
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
    // FSM states
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE          = 2'b00,
        S_PATTERN_INPUT = 2'b01,
        S_FINAL_HOLD    = 2'b10
    } state_t;

    state_t state;

    // =========================================================
    // One-second timer for the last grid
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

    // Enable authentication in INPUT or HOLD state.
    always_comb begin
        o_auth_active = 1'b0;

        case (state)
            S_PATTERN_INPUT,
            S_FINAL_HOLD: o_auth_active = 1'b1;

            default: o_auth_active = 1'b0;
        endcase
    end

    // =========================================================
    // Authentication FSM
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
            // Output pulses last one cycle.
            o_unlock_pass <= 1'b0;
            o_unlock_fail <= 1'b0;
            o_path_clear  <= 1'b0;

            // -------------------------------------------------
            // External clear has the highest priority.
            // Stop authentication and return to IDLE.
            // -------------------------------------------------
            if (i_pattern_clear) begin
                state         <= S_IDLE;
                pattern_index <= 3'd0;
                hold_count    <= '0;
                o_path_clear  <= 1'b1;
            end

            // -------------------------------------------------
            // Start a new attempt when start is asserted.
            // Always restart from the first step.
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
                    // Wait for authentication.
                    // =========================================
                    S_IDLE: begin
                        pattern_index <= 3'd0;
                        hold_count    <= '0;
                    end

                    // =========================================
                    // Read and compare each pattern entry.
                    // =========================================
                    S_PATTERN_INPUT: begin
                        hold_count <= '0;

                        if (i_grid_enter_pulse && i_grid_valid) begin

                            // Matches the expected grid.
                            if (i_grid_id ==
                                get_expected_grid(pattern_index)) begin

                                // Final entry, grid 8, matched.
                                if (pattern_index ==
                                    PATTERN_LENGTH - 1) begin
                                    state         <= S_FINAL_HOLD;
                                    hold_count    <= '0;
                                end

                                // Move to the next pattern entry.
                                else begin
                                    pattern_index <=
                                        pattern_index + 1'b1;
                                end
                            end

                            // Wrong grid entered
                            else begin
                                o_unlock_fail <= 1'b1;
                                o_path_clear  <= 1'b1;

                                pattern_index <= 3'd0;
                                hold_count    <= '0;

                                // Stay in INPUT for an immediate retry.
                                state <= S_PATTERN_INPUT;
                            end
                        end
                    end

                    // =========================================
                    // Accumulate one second on the final grid 8.
                    // =========================================
                    S_FINAL_HOLD: begin

                        // Fail immediately if another grid is entered.
                        if (i_grid_enter_pulse &&
                            i_grid_valid &&
                            (i_grid_id != FINAL_GRID)) begin

                            o_unlock_fail <= 1'b1;
                            o_path_clear  <= 1'b1;

                            pattern_index <= 3'd0;
                            hold_count    <= '0;

                            // Retry immediately.
                            state <= S_PATTERN_INPUT;
                        end

                        // Blue marker detected in grid 8
                        else if (i_marker_valid &&
                                 i_grid_valid &&
                                 (i_grid_id == FINAL_GRID)) begin

                            // One-second hold completed.
                            if (hold_count >= HOLD_COUNT_LAST) begin
                                o_unlock_pass <= 1'b1;

                                // Clear the path on success.
                                o_path_clear <= 1'b1;

                                state         <= S_IDLE;
                                pattern_index <= 3'd0;
                                hold_count    <= '0;
                            end

                            // Accumulate the hold time.
                            else begin
                                hold_count <= hold_count + 1'b1;
                            end
                        end

                        // Marker not detected; keep the current count.
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
