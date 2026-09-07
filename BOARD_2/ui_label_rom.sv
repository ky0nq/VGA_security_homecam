`timescale 1ns / 1ps

// =================================================================================
// Module: ui_label_rom
// Description: Fixed 128x32 Bitmap ROM for Korean UI Text Labels.
// Features:
//   - Label 0: "단말기" (Terminal / Board A)
//   - Label 1: "홈캠"   (Home Cam / Board B)
//   - Direct address concatenation `{label, y, x}` avoiding multipliers.
//   - 1-Clock Cycle Read Latency (Block RAM synthesis inferred via `rom_style`).
// Memory Layout:
//   - 2 Slots x 128 x 32 bits = 8,192 bits = 1,024 Bytes.
// =================================================================================

module ui_label_rom #(
    parameter string MEM_FILE = "ui_labels.mem"
) (
    input  logic       clk,
    input  logic       i_label,      // Label selector (0 or 1)
    input  logic [6:0] i_x,          // X coordinate within slot (0~127)
    input  logic [4:0] i_y,          // Y coordinate within slot (0~31)
    output logic       o_pixel       // Active pixel output (1 = text pixel)
);

    localparam int SLOT_W    = 128;
    localparam int SLOT_H    = 32;
    localparam int NUM_LABEL = 2;
    localparam int MEM_BYTES = NUM_LABEL * SLOT_W * SLOT_H / 8; // 1,024 Bytes

    (* rom_style = "block" *)
    logic [7:0] mem [0:MEM_BYTES-1];

    // Load initial memory content from file
    initial begin
        $readmemh(MEM_FILE, mem);
    end

    // Bit-level address calculation (13-bit total bit index)
    // Bit 12: i_label, Bits [11:7]: i_y, Bits [6:0]: i_x
    logic [12:0] bit_index;
    assign bit_index = {i_label, i_y, i_x};

    // Pipeline Registers for 1-Cycle Block RAM Read
    logic [7:0] rd_byte;
    logic [2:0] bit_off_q;

    always_ff @(posedge clk) begin
        rd_byte   <= mem[bit_index[12:3]]; // Byte-aligned ROM lookup
        bit_off_q <= bit_index[2:0];       // Latch bit offset inside byte
    end

    // Extract targeted bit from latched byte (MSB-first indexing)
    assign o_pixel = rd_byte[3'd7 - bit_off_q];

endmodule
