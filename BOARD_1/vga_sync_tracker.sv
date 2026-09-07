`timescale 1ns / 1ps 
 
// Recover the screen position (x, y) and de from the incoming h_sync/v_sync.
// Timing follows the same 640x480@60 format used in vga_decoder.sv.
 
module vga_sync_tracker ( 
    input  logic       clk, 
    input  logic       rst_n, 
 
    input  logic       i_h_sync, 
    input  logic       i_v_sync, 
 
    output logic       o_de, 
    output logic [9:0] o_x, 
    output logic [9:0] o_y 
); 
 
    localparam int H_TOTAL   = 800; 
    localparam int V_TOTAL   = 525; 
    localparam int H_VISIBLE = 640; 
    localparam int V_VISIBLE = 480; 
 
    // h_sync is low from h_count 656 to 751, then rises at 752.
    localparam int H_SYNC_END = 752; 
    // v_sync is low from v_count 490 to 491, then rises at 492.
    localparam int V_SYNC_END = 492; 
 
    logic h_sync_q, v_sync_q; 
    logic h_rise, v_rise; 
 
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin 
            h_sync_q <= 1'b1; 
            v_sync_q <= 1'b1; 
        end else begin 
            h_sync_q <= i_h_sync; 
            v_sync_q <= i_v_sync; 
        end 
    end 
 
    assign h_rise = i_h_sync & ~h_sync_q; 
    assign v_rise = i_v_sync & ~v_sync_q; 
 
    // Pixel tick (25 MHz). The phase is reset at each h_sync rising edge
    // so it stays aligned with the start of each line.
    logic [1:0] phase; 
    logic       tick; 
 
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n)      phase <= 2'd0; 
        else if (h_rise) phase <= 2'd0; 
        else             phase <= phase + 2'd1; 
    end 
 
    assign tick = (phase == 2'd3); 
 
    logic [9:0] x_cnt, y_cnt; 
    logic       line_end; 
 
    assign line_end = tick && (x_cnt == H_TOTAL - 1); 
 
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n)      x_cnt <= 10'd0; 
        else if (h_rise) x_cnt <= 10'(H_SYNC_END); 
        else if (tick)   x_cnt <= (x_cnt == H_TOTAL - 1) ? 10'd0 : x_cnt + 10'd1; 
    end 
 
    always_ff @(posedge clk or negedge rst_n) begin 
        if (!rst_n)        y_cnt <= 10'd0; 
        else if (v_rise)   y_cnt <= 10'(V_SYNC_END); 
        else if (line_end) y_cnt <= (y_cnt == V_TOTAL - 1) ? 10'd0 : y_cnt + 10'd1; 
    end 
 
    assign o_x  = x_cnt; 
    assign o_y  = y_cnt; 
    assign o_de = (x_cnt < H_VISIBLE) && (y_cnt < V_VISIBLE); 
 
endmodule
