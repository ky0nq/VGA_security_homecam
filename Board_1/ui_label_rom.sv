`timescale 1ns / 1ps

// Label bitmap ROM.
//   label 0 = "Terminal" (Board 1 / Board A)
//   label 1 = "HomeCam"  (Board 2 / Board B)
//
// Fixed 128x32 slot size allows direct address mapping via {label, y, x} concat (no multipliers).
// Read latency is 1 clock cycle.

module ui_label_rom #(
    parameter string MEM_FILE = "ui_labels.mem"
) (
    input  logic       clk,
    input  logic       i_label,
    input  logic [6:0] i_x,      // 0~127
    input  logic [4:0] i_y,      // 0~31
    output logic       o_pixel   // 1 = Text pixel
);

    localparam int SLOT_W    = 128;
    localparam int SLOT_H    = 32;
    localparam int NUM_LABEL = 2;
    localparam int MEM_BYTES = NUM_LABEL * SLOT_W * SLOT_H / 8;   // 1024

    (* rom_style = "block" *)
    logic [7:0] mem [0:MEM_BYTES-1];

    initial $readmemh(MEM_FILE, mem);

    logic [12:0] bit_index;
    assign bit_index = {i_label, i_y, i_x};

    logic [7:0] rd_byte;
    logic [2:0] bit_off_q;

    always_ff @(posedge clk) begin
        rd_byte   <= mem[bit_index[12:3]];
        bit_off_q <= bit_index[2:0];
    end

    assign o_pixel = rd_byte[3'd7 - bit_off_q];

endmodule
