`timescale 1ns / 1ps

module ui_frame_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [11:0] i_rgb,

    input  logic        i_unlock_en,
    input  logic        i_zoom_en,
    input  logic [3:0]  i_filter_id,

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
        .i_unlock_en(i_unlock_en),
        .i_zoom_en(i_zoom_en),
        .i_filter_id(i_filter_id),
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
