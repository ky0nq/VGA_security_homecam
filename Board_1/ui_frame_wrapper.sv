`timescale 1ns / 1ps

module ui_frame_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    input  logic        i_auth_active,
    input  logic        i_unlock_state,
    input  logic        i_lockout,
    input  logic        i_marker_valid,
    input  logic        i_grid_valid,
    input  logic [3:0]  i_grid_id,
    input  logic [1:0]  i_auth_state,
    input  logic [2:0]  i_pattern_index,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb
);
    logic de;
    logic [9:0] x, y;

    vga_sync_tracker U_TRACKER (
        .clk(clk), .rst_n(rst_n),
        .i_h_sync(i_h_sync), .i_v_sync(i_v_sync),
        .o_de(de), .o_x(x), .o_y(y)
    );

    ui_frame_overlay U_OVERLAY (
        .clk(clk), .rst_n(rst_n),
        .i_de(de), .i_x(x), .i_y(y), .i_rgb(i_rgb),
        .i_auth_active(i_auth_active),
        .i_unlock_state(i_unlock_state),
        .i_lockout(i_lockout),
        .i_marker_valid(i_marker_valid),
        .i_grid_valid(i_grid_valid),
        .i_grid_id(i_grid_id),
        .i_auth_state(i_auth_state),
        .i_pattern_index(i_pattern_index),
        .o_rgb(o_rgb)
    );

    // Overlay adds one clk latency.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;
            o_v_sync <= 1'b1;
        end else begin
            o_h_sync <= i_h_sync;
            o_v_sync <= i_v_sync;
        end
    end
endmodule
