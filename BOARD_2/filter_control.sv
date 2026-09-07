`timescale 1ns / 1ps

// =================================================================================
// Module: filter_control
// Description: Decodes button pulses to cycle through visual filter states.
//              - Color Mode (effect_sel=0): Cycles Normal -> Pink -> Blue -> Orange -> Gray
//              - Tone Mode  (effect_sel=1): Cycles Normal -> Bright -> Brighter -> Night
// Constraint: Button inputs are ignored when system is locked (unlock_en=0).
// =================================================================================

module filter_control (
    input  logic clk,
    input  logic rst_n,
    input  logic unlock_en,    // Lock status signal (1 = unlocked, 0 = locked)
    input  logic effect_sel,   // Filter mode select (0 = Color, 1 = Gamma/Night)
    input  logic btn_u_pulse,  // Single-clock button pulse

    // Color Effect Enables (effect_sel = 0)
    output logic pink_en,
    output logic blue_en,
    output logic orange_en,
    output logic gray_en,

    // Gamma / Night Effect Enables (effect_sel = 1)
    output logic gamma_en,
    output logic gamma_level,  // 0 = Bright, 1 = Brighter
    output logic night_en
);

    // Gate button pulse with lock status
    logic btn_pulse;
    assign btn_pulse = btn_u_pulse & unlock_en;

    // State Counters
    logic [2:0] color_state;  // 0 to 4: Normal/Pink/Blue/Orange/Gray
    logic [1:0] tone_state;   // 0 to 3: Normal/Bright/Brighter/Night

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            color_state <= 3'd0;
            tone_state  <= 2'd0;
        end else if (btn_pulse) begin
            if (!effect_sel) begin
                color_state <= (color_state == 3'd4) ? 3'd0 : color_state + 3'd1;
            end else begin
                tone_state  <= (tone_state == 2'd3)  ? 2'd0 : tone_state  + 2'd1;
            end
        end
    end

    // Enable Signal Decoding (Color Mode)
    assign pink_en   = (~effect_sel) && (color_state == 3'd1);
    assign blue_en   = (~effect_sel) && (color_state == 3'd2);
    assign orange_en = (~effect_sel) && (color_state == 3'd3);
    assign gray_en   = (~effect_sel) && (color_state == 3'd4);

    // Enable Signal Decoding (Tone Mode)
    assign gamma_en    = effect_sel && (tone_state == 2'd1 || tone_state == 2'd2);
    assign gamma_level = (tone_state == 2'd2);
    assign night_en    = effect_sel && (tone_state == 2'd3);

endmodule
