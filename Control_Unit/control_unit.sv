`timescale 1ns / 1ps

module control_unit (
    input  logic clk,
    input  logic rst_n,

    input  logic i_auth_sw,
    input  logic i_unlock_pass,
    input  logic i_unlock_fail,

    output logic o_auth_start,
    output logic o_pattern_clear,
    output logic o_unlock_en,
    output logic o_alarm
);

    typedef enum logic [1:0] {
        S_IDLE       = 2'd0,
        S_LOCKED     = 2'd1,
        S_AUTH_TRACK = 2'd2,
        S_UNLOCKED   = 2'd3
    } state_t;

    state_t c_state;

    logic [1:0] fail_count;
    logic       lockout_active;
    logic [32:0] lockout_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_state           <= S_IDLE;
            fail_count      <= 2'd0;
            lockout_active  <= 1'b0;
            lockout_count   <= 33'b0;
            o_auth_start      <= 1'b0;
            o_pattern_clear   <= 1'b1;
            o_unlock_en       <= 1'b0;
            o_alarm           <= 1'b0;
        end else if (lockout_active) begin
            c_state           <= S_IDLE;
            fail_count      <= 2'd3;
            o_auth_start      <= 1'b0;
            o_pattern_clear   <= 1'b1;
            o_unlock_en       <= 1'b0;
            o_alarm           <= 1'b1;

            if (lockout_count >= 33'd5_999_999_999) begin
                lockout_active <= 1'b0;
                lockout_count  <= 33'b0;
                fail_count     <= 2'd0;
                o_alarm          <= 1'b0;
            end else begin
                lockout_count <= lockout_count + 33'b1;
            end
        end else begin
            lockout_active <= 1'b0;
            lockout_count  <= 33'b0;
            o_unlock_en      <= 1'b0;
            o_alarm          <= 1'b0;

            case (c_state)
                S_IDLE: begin
                    o_auth_start    <= 1'b0;
                    o_pattern_clear <= 1'b1;
                    fail_count    <= 2'd0;

                    if (i_auth_sw) begin
                        c_state <= S_IDLE;
                    end else begin
                        c_state         <= S_LOCKED;
                        o_pattern_clear <= 1'b0;
                    end
                end

                S_LOCKED: begin
                    o_auth_start    <= 1'b0;
                    o_pattern_clear <= 1'b0;
                    fail_count    <= 2'd0;

                    if (i_auth_sw) begin
                        c_state         <= S_AUTH_TRACK;
                        o_pattern_clear <= 1'b1; 
                    end else begin
                        c_state <= S_LOCKED;
                    end
                end

                S_AUTH_TRACK: begin
                    c_state         <= S_AUTH_TRACK;
                    o_auth_start    <= 1'b1;
                    o_pattern_clear <= 1'b0;

                    if (i_unlock_fail) begin
                        o_auth_start    <= 1'b0;
                        o_pattern_clear <= 1'b1; 

                        if (fail_count >= 2'd2) begin
                            fail_count     <= 2'd3;
                            lockout_active <= 1'b1;
                            lockout_count  <= 33'b0;
                            c_state          <= S_IDLE;
                            o_alarm          <= 1'b1;
                        end else begin
                            fail_count <= fail_count + 2'd1;
                            c_state      <= S_AUTH_TRACK;
                        end
                    end else if (i_unlock_pass) begin
                        fail_count    <= 2'd0;
                        c_state         <= S_UNLOCKED;
                        o_auth_start    <= 1'b0;
                        o_pattern_clear <= 1'b1;
                        o_unlock_en     <= 1'b1; 
                    end
                    else begin
                        c_state         <= S_AUTH_TRACK;
                        fail_count    <= fail_count;
                        o_auth_start    <= 1'b1;
                        o_pattern_clear <= 1'b0;
                    end
                end

                S_UNLOCKED: begin
                    c_state         <= S_IDLE;
                    fail_count    <= 2'd0;
                    o_auth_start    <= 1'b0;
                    o_pattern_clear <= 1'b1;
                    o_unlock_en     <= 1'b0;
                end

                default: begin
                    c_state           <= S_IDLE;
                    fail_count      <= 2'd0;
                    lockout_active  <= 1'b0;
                    lockout_count   <= 33'b0;
                    o_auth_start      <= 1'b0;
                    o_pattern_clear   <= 1'b1;
                    o_unlock_en       <= 1'b0;
                    o_alarm           <= 1'b0;
                end
            endcase
        end
    end

endmodule


