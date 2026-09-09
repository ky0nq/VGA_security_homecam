`timescale 1ns / 1ps

// Board 1 system-level authentication and lockout controller.
module board1_control_unit #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer LOCKOUT_SECONDS = 60
)(
    input  logic clk,
    input  logic rst_n,

    // SW0
    // 0: IDLE
    // 1: activate auth mode
    input  logic i_auth_sw,

    input logic i_remote_relock,

    // Auth Path result: 1 clk pluse
    input  logic i_unlock_pass,
    input  logic i_unlock_fail,

    // Auth Path: 1 clk pluse 
    output logic o_auth_start,
    output logic o_pattern_clear,

    output logic o_unlock_state,

    // LOCKOUT High
    output logic o_alram
);

    // =========================================================
    // FSM State
    // =========================================================
    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_AUTH_TRACK = 2'd1,
        S_UNLOCKED   = 2'd2,
        S_LOCKOUT    = 2'd3
    } state_t;

    state_t c_state;

    // =========================================================
    // Fail Count
    // 3: LOCKOUT
    // =========================================================
    logic [1:0] fail_count_q;

    // =========================================================
    // Switch Synchronizer
    // =========================================================
    logic auth_sw_meta_q;
    logic auth_sw_sync_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auth_sw_meta_q <= 1'b0;
            auth_sw_sync_q <= 1'b0;
        end else begin
            auth_sw_meta_q <= i_auth_sw;
            auth_sw_sync_q <= auth_sw_meta_q;
        end
    end

    // =========================================================
    // 60sec LOCKOUT Timer
    // =========================================================
    localparam integer LOCKOUT_CLK_COUNT_WIDTH = (CLK_FREQ_HZ <= 1) ? 1 : $clog2(CLK_FREQ_HZ);

    localparam integer LOCKOUT_SEC_COUNT_WIDTH = (LOCKOUT_SECONDS <= 1) ? 1 : $clog2(LOCKOUT_SECONDS);

    logic [LOCKOUT_CLK_COUNT_WIDTH-1:0] lockout_clk_count_q;

    logic [LOCKOUT_SEC_COUNT_WIDTH-1:0] lockout_sec_count_q;

    // LOCKOUT -> LED ON
    assign o_alram = (c_state == S_LOCKOUT);

    assign o_unlock_state = (c_state == S_UNLOCKED);

    // =========================================================
    // Control FSM
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_state <= S_IDLE;

            fail_count_q <= 2'd0;

            lockout_clk_count_q <= '0;
            lockout_sec_count_q <= '0;

            o_auth_start    <= 1'b0;
            o_pattern_clear <= 1'b0;
        end else begin
            o_auth_start    <= 1'b0;
            o_pattern_clear <= 1'b0;

            case (c_state)

                // =============================================
                // IDLE
                // =============================================
                S_IDLE: begin
                    fail_count_q <= 2'd0;

                    lockout_clk_count_q <= '0;
                    lockout_sec_count_q <= '0;

                    // start when sw[0] == 1
                    if (auth_sw_sync_q) begin
                        c_state      <= S_AUTH_TRACK;
                        o_auth_start <= 1'b1;
                    end
                end

                // =============================================
                // AUTH TRACK
                // =============================================
                S_AUTH_TRACK: begin
                    lockout_clk_count_q <= '0;
                    lockout_sec_count_q <= '0;

                    // switch off
                    if (!auth_sw_sync_q) begin
                        c_state <= S_IDLE;
                        fail_count_q <= 2'd0;
                        o_pattern_clear <= 1'b1;
                    end

                    // pass
                    else if (i_unlock_pass) begin
                        c_state <= S_UNLOCKED;

                        fail_count_q <= 2'd0;
                    end

                    // fail
                    else if (i_unlock_fail) begin

                        // fail == 3
                        if (fail_count_q >= 2'd2) begin
                            c_state <= S_LOCKOUT;

                            fail_count_q <= 2'd3;

                            lockout_clk_count_q <= '0;
                            lockout_sec_count_q <= '0;

                            o_pattern_clear <= 1'b1;
                        end else begin
                            // fail < 2
                            fail_count_q <= fail_count_q + 1'b1;
                        end
                    end
                end

                // =============================================
                // UNLOCKED
                // =============================================
                S_UNLOCKED: begin
                    fail_count_q <= 2'd0;

                    lockout_clk_count_q <= '0;
                    lockout_sec_count_q <= '0;

                    if (i_remote_relock) begin
                        c_state         <= S_IDLE;
                        o_pattern_clear <= 1'b1;
                    end else if (!auth_sw_sync_q) begin
                        c_state         <= S_IDLE;
                        o_pattern_clear <= 1'b1;
                    end
                end

                // =============================================
                // LOCKOUT
                // =============================================
                S_LOCKOUT: begin
                    fail_count_q <= 2'd3;

                    // 1sec count
                    if (lockout_clk_count_q >= CLK_FREQ_HZ - 1) begin
                        lockout_clk_count_q <= '0;

                        // count 60 done
                        if (lockout_sec_count_q >= LOCKOUT_SECONDS - 1) begin
                            lockout_sec_count_q <= '0;
                            fail_count_q        <= 2'd0;

                            if (auth_sw_sync_q) begin
                                c_state      <= S_AUTH_TRACK;
                                o_auth_start <= 1'b1;
                            end else begin
                                c_state <= S_IDLE;
                            end
                        end else begin
                            lockout_sec_count_q <= lockout_sec_count_q + 1'b1;
                        end
                    end else begin
                        lockout_clk_count_q <= lockout_clk_count_q + 1'b1;
                    end
                end

                default: begin
                    c_state <= S_IDLE;

                    fail_count_q <= 2'd0;

                    lockout_clk_count_q <= '0;
                    lockout_sec_count_q <= '0;

                    o_auth_start    <= 1'b0;
                    o_pattern_clear <= 1'b1;
                end

            endcase
        end
    end

endmodule
