`timescale 1ns / 1ps

// Picks which filter is on based on the button, but only while unlock_en is high.

module filter_control (
    input logic clk,
    input logic rst_n,
    input logic unlock_en,    // from uart_decoder, tells us the pattern matched
    input logic effect_sel,   // no longer used, see effect_sel_i below
    input logic btn_u_pulse,  // from uart_decoder, already a clean 1-clock pulse

    // Color group -- unused now, tied to 0 below (demo only keeps gray)
    output logic pink_en,
    output logic blue_en,
    output logic orange_en,
    output logic gray_en,

    output logic gamma_en,
    output logic gamma_level,  // 0 = brighter, 1 = even brighter (only used when gamma_en)
    output logic night_en,

    // Current effect encoded for the on-screen UI:
    // 0 NORMAL, 1 PINK, 2 BLUE, 3 ORANGE, 4 GRAY,
    // 5 BRIGHT, 6 BRIGHTER, 7 NIGHT
    output logic [3:0] o_filter_id
);

    logic effect_sel_i;
    assign effect_sel_i = 1'b1;

    // ignore the button while locked
    logic btn_pulse;
    assign btn_pulse = btn_u_pulse & unlock_en;

    //============================================================
    // color_state : kept but unused now (effect_sel_i is always 1,
    // so this branch never runs -- pink/blue/orange never turn on)
    //============================================================
    logic [2:0] color_state;

    // DEMO CHANGE: tone_state now cycles 0..4 (was 0..3) to fit gray in:
    // plain -> gray -> gamma(dim) -> gamma(bright) -> night -> plain
    logic [2:0] tone_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            color_state <= 3'd0;
            tone_state  <= 3'd0;
        end else if (btn_pulse) begin
            if (!effect_sel_i) begin
                color_state <= (color_state == 3'd4) ? 3'd0 : color_state + 3'd1;
            end else begin
                tone_state <= (tone_state == 3'd4) ? 3'd0 : tone_state + 3'd1;
            end
        end
    end

    //============================================================
    // turn the state numbers into the actual enable bits
    //============================================================
    assign pink_en   = (~effect_sel_i) && (color_state == 3'd1);
    assign blue_en   = (~effect_sel_i) && (color_state == 3'd2);
    assign orange_en = (~effect_sel_i) && (color_state == 3'd3);
    // DEMO CHANGE: gray now lives in the tone_state cycle (state 1), not
    // the unused color_state cycle
    // assign gray_en = (~effect_sel_i) && (color_state == 3'd4);
    assign gray_en    = effect_sel_i && (tone_state == 3'd1);

    // DEMO CHANGE: gamma states shifted from 1/2 to 2/3, night from 3 to 4
    assign gamma_en    = effect_sel_i && (tone_state == 3'd2 || tone_state == 3'd3);
    assign gamma_level = (tone_state == 3'd3);
    assign night_en    = effect_sel_i && (tone_state == 3'd4);

    always_comb begin
        o_filter_id = 4'd0;

        if (unlock_en) begin
            if (!effect_sel_i) begin
                case (color_state)
                    3'd1: o_filter_id = 4'd1;
                    3'd2: o_filter_id = 4'd2;
                    3'd3: o_filter_id = 4'd3;
                    3'd4: o_filter_id = 4'd4;
                    default: o_filter_id = 4'd0;
                endcase
            end else begin
                case (tone_state)
                    3'd1: o_filter_id = 4'd4;
                    3'd2: o_filter_id = 4'd5;
                    3'd3: o_filter_id = 4'd6;
                    3'd4: o_filter_id = 4'd7;
                    default: o_filter_id = 4'd0;
                endcase
            end
        end
    end

endmodule
