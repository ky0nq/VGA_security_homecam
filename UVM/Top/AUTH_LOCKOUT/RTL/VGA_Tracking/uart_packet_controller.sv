`timescale 1ns / 1ps

module uart_packet_controller (
    input logic clk,
    input logic rst_n,

    // Authentication status from the control unit
    input logic i_unlock_state,

    // One-cycle pulses from btn_debounce
    input logic i_btn_U_pulse,
    input logic i_btn_D_pulse,
    input logic i_btn_R_pulse,
    input logic i_btn_L_pulse,

    // Basys 3 physical switches
    input logic i_effect_en,  // SW2
    input logic i_zoom_en,    // SW1

    // uart_tx status
    input logic i_tx_busy,
    input logic i_tx_done,

    // uart_tx inputs
    output logic       o_tx_start,
    output logic [7:0] o_tx_data
);

    // =========================================================
    // Button pulse vector
    // [3] : UP
    // [2] : DOWN
    // [1] : RIGHT
    // [0] : LEFT
    // =========================================================
    logic [3:0] button_pulse;

    assign button_pulse = {
        i_btn_U_pulse, i_btn_D_pulse, i_btn_R_pulse, i_btn_L_pulse
    };

    // =========================================================
    // Switch synchronizer
    // =========================================================
    logic effect_meta_q;
    logic effect_sync_q;

    logic zoom_meta_q;
    logic zoom_sync_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            effect_meta_q <= 1'b0;
            effect_sync_q <= 1'b0;

            zoom_meta_q   <= 1'b0;
            zoom_sync_q   <= 1'b0;
        end else begin
            effect_meta_q <= i_effect_en;
            effect_sync_q <= effect_meta_q;

            zoom_meta_q   <= i_zoom_en;
            zoom_sync_q   <= zoom_meta_q;
        end
    end

    // =========================================================
    // State change detection
    // =========================================================
    logic unlock_prev_q;
    logic effect_prev_q;
    logic zoom_prev_q;

    logic unlock_changed;
    logic effect_changed;
    logic zoom_changed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            unlock_prev_q <= 1'b0;
            effect_prev_q <= 1'b0;
            zoom_prev_q   <= 1'b0;
        end else begin
            unlock_prev_q <= i_unlock_state;
            effect_prev_q <= effect_sync_q;
            zoom_prev_q   <= zoom_sync_q;
        end
    end

    assign unlock_changed = i_unlock_state ^ unlock_prev_q;

    assign effect_changed = effect_sync_q ^ effect_prev_q;

    assign zoom_changed   = zoom_sync_q ^ zoom_prev_q;

    logic tx_event_valid;

    assign tx_event_valid =
        unlock_changed |
        (
            i_unlock_state &&
            (
                (|button_pulse) |
                effect_changed  |
                zoom_changed
            )
        );

    logic       pending_valid_q;
    logic       pending_unlock_q;
    logic [3:0] pending_button_q;
    logic       pending_effect_q;
    logic       pending_zoom_q;

    logic       tx_active_q;

    // =========================================================
    // UART packet transmission
    // [7] : Reserved, always 0
    // [6] : Unlock state
    // [5] : Button UP pulse
    // [4] : Button DOWN pulse
    // [3] : Button RIGHT pulse
    // [2] : Button LEFT pulse
    // [1] : Effect enable
    // [0] : Zoom enable
    // =========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid_q <= 1'b0;
            pending_unlock_q <= 1'b0;
            pending_button_q <= 4'b0000;
            pending_effect_q <= 1'b0;
            pending_zoom_q <= 1'b0;

            tx_active_q <= 1'b0;

            o_tx_start <= 1'b0;
            o_tx_data <= 8'b0000_0000;
        end else begin
            o_tx_start <= 1'b0;

            if (tx_active_q && i_tx_done) begin
                tx_active_q <= 1'b0;
            end

            if (tx_event_valid) begin
                pending_valid_q  <= 1'b1;
                pending_unlock_q <= i_unlock_state;

                if (i_unlock_state) begin
                    pending_button_q <= pending_button_q | button_pulse;

                    pending_effect_q <= effect_sync_q;
                    pending_zoom_q   <= zoom_sync_q;
                end else begin
                    pending_button_q <= 4'b0000;
                    pending_effect_q <= 1'b0;
                    pending_zoom_q   <= 1'b0;
                end
            end

            if (!tx_active_q && !i_tx_busy && pending_valid_q && !tx_event_valid) begin

                o_tx_data <= {1'b0,pending_unlock_q,pending_button_q,pending_effect_q,pending_zoom_q};
                o_tx_start <= 1'b1;
                tx_active_q <= 1'b1;
                pending_valid_q <= 1'b0;
                pending_button_q <= 4'b0000;
            end
        end
    end

endmodule
