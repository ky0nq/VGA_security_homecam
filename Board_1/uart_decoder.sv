`timescale 1ns / 1ps

// Splits the received byte into zoom_en, effect_sel, buttons, and unlock_en.

module uart_decoder (
    input logic clk,
    input logic rst_n,

    input logic [7:0] rx_data,
    input logic        rx_done,
    input logic        lock_force,  // pulse from counter_10s that forces a re-lock

    output logic zoom_en,      // bit0, a real switch so we just pass the level through
    output logic effect_sel,   // bit1, a real switch so we just pass the level through
    output logic btn_l,        // bit2, turned into a 1-clock pulse
    output logic btn_r,        // bit3, turned into a 1-clock pulse
    output logic btn_d,        // bit4, turned into a 1-clock pulse
    output logic btn_u_pulse,  // bit5, turned into a 1-clock pulse (filter button)
    output logic unlock_en     // bit6, pattern match result, can be overridden by forced_lock
);

    //============================================================
    // hold the last received byte. only updates when rx_done is high
    //============================================================
    logic [7:0] status_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_reg <= 8'b0;
        end else if (rx_done) begin
            status_reg <= rx_data;
        end
        // keep the old value on every other clock
    end

    //============================================================
    // these two bits are real switches, so just read them straight from status_reg
    //============================================================
    assign zoom_en    = status_reg[0];
    assign effect_sel = status_reg[1];

    //============================================================
    // forced_lock latch: lock_force sets it, only a new rx_done can clear it
    //============================================================
    logic forced_lock;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            forced_lock <= 1'b0;
        end else if (rx_done) begin
            forced_lock <= 1'b0;       // new data arrived, so release the forced lock
        end else if (lock_force) begin
            forced_lock <= 1'b1;       // 10 second timeout fired, hold the lock
        end
    end

    assign unlock_en = forced_lock ? 1'b0 : status_reg[6];

    //============================================================
    // bit2~5 (btn_l/r/d/u) : the sender only ever puts a 1 here in the exact
    // packet for a real button press, and clears it right after sending, so
    // we can just trust rx_done + that bit without comparing to the old value
    //============================================================
    assign btn_l = rx_done & rx_data[2];
    assign btn_r = rx_done & rx_data[3];
    assign btn_d = rx_done & rx_data[4];
    assign btn_u_pulse = rx_done & rx_data[5];

endmodule
