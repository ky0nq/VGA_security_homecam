`timescale 1ns / 1ps

// Picks which filter is on based on the button, but only while unlock_en is high.

module filter_control (
    input logic clk,
    input logic rst_n,
    input logic unlock_en,    // from uart_decoder, tells us the pattern matched
    input logic effect_sel,   // from uart_decoder, picks color group or tone group
    input logic btn_u_pulse,  // from uart_decoder, already a clean 1-clock pulse

    // Color group (effect_sel = 0), one-hot, all 0 means the plain picture
    output logic pink_en,
    output logic blue_en,
    output logic orange_en,
    output logic gray_en,

    // Gamma / Night group (effect_sel = 1)
    output logic gamma_en,
    output logic gamma_level,  // 0 = brighter, 1 = even brighter (only used when gamma_en)
    output logic night_en
);

    // ignore the button while locked
    logic btn_pulse;
    assign btn_pulse = btn_u_pulse & unlock_en;

    //============================================================
    // color_state cycles 0..4 : plain / pink / blue / orange / gray
    // tone_state cycles 0..3  : plain / bright / brighter / night
    //============================================================
    logic [2:0] color_state;
    logic [1:0] tone_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            color_state <= 3'd0;
            tone_state  <= 2'd0;
        end else if (btn_pulse) begin
            if (!effect_sel) begin
                color_state <= (color_state == 3'd4) ? 3'd0 : color_state + 3'd1;
            end else begin
                tone_state <= (tone_state == 2'd3) ? 2'd0 : tone_state + 2'd1;
            end
        end
    end

    //============================================================
    // turn the state numbers into the actual enable bits
    //============================================================
    assign pink_en   = (~effect_sel) && (color_state == 3'd1);
    assign blue_en   = (~effect_sel) && (color_state == 3'd2);
    assign orange_en = (~effect_sel) && (color_state == 3'd3);
    assign gray_en   = (~effect_sel) && (color_state == 3'd4);

    assign gamma_en    = effect_sel && (tone_state == 2'd1 || tone_state == 2'd2);
    assign gamma_level = (tone_state == 2'd2);
    assign night_en    = effect_sel && (tone_state == 2'd3);

endmodule
