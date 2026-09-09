`timescale 1ns / 1ps

// 5x7 synthesizable ASCII font used by the VGA HUD.
// i_col: 0..4, i_row: 0..6. Unsupported characters are blank.
module ui_font5x7 (
    input  logic [7:0] i_char,
    input  logic [2:0] i_row,
    input  logic [2:0] i_col,
    output logic       o_pixel
);
    logic [4:0] row_bits;

    function automatic logic [4:0] glyph_row(
        input logic [7:0] ch,
        input logic [2:0] row
    );
        begin
            glyph_row = 5'b00000;
            case (ch)
                8'h41: case(row) // A
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b11111; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b10001;
                endcase
                8'h42: case(row) // B
                    0: glyph_row=5'b11110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b11110;
                endcase
                8'h43: case(row) // C
                    0: glyph_row=5'b01111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b10000; 4: glyph_row=5'b10000; 5: glyph_row=5'b10000; 6: glyph_row=5'b01111;
                endcase
                8'h44: case(row) // D
                    0: glyph_row=5'b11110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10001; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b11110;
                endcase
                8'h45: case(row) // E
                    0: glyph_row=5'b11111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10000; 5: glyph_row=5'b10000; 6: glyph_row=5'b11111;
                endcase
                8'h46: case(row) // F
                    0: glyph_row=5'b11111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10000; 5: glyph_row=5'b10000; 6: glyph_row=5'b10000;
                endcase
                8'h47: case(row) // G
                    0: glyph_row=5'b01111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b10111; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h48: case(row) // H
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b11111; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b10001;
                endcase
                8'h49: case(row) // I
                    0: glyph_row=5'b11111; 1: glyph_row=5'b00100; 2: glyph_row=5'b00100;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b00100; 5: glyph_row=5'b00100; 6: glyph_row=5'b11111;
                endcase
                8'h4A: case(row) // J
                    0: glyph_row=5'b00111; 1: glyph_row=5'b00010; 2: glyph_row=5'b00010;
                    3: glyph_row=5'b00010; 4: glyph_row=5'b10010; 5: glyph_row=5'b10010; 6: glyph_row=5'b01100;
                endcase
                8'h4B: case(row) // K
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10010; 2: glyph_row=5'b10100;
                    3: glyph_row=5'b11000; 4: glyph_row=5'b10100; 5: glyph_row=5'b10010; 6: glyph_row=5'b10001;
                endcase
                8'h4C: case(row) // L
                    0: glyph_row=5'b10000; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b10000; 4: glyph_row=5'b10000; 5: glyph_row=5'b10000; 6: glyph_row=5'b11111;
                endcase
                8'h4D: case(row) // M
                    0: glyph_row=5'b10001; 1: glyph_row=5'b11011; 2: glyph_row=5'b10101;
                    3: glyph_row=5'b10101; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b10001;
                endcase
                8'h4E: case(row) // N
                    0: glyph_row=5'b10001; 1: glyph_row=5'b11001; 2: glyph_row=5'b10101;
                    3: glyph_row=5'b10011; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b10001;
                endcase
                8'h4F: case(row) // O
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10001; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h50: case(row) // P
                    0: glyph_row=5'b11110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10000; 5: glyph_row=5'b10000; 6: glyph_row=5'b10000;
                endcase
                8'h51: case(row) // Q
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10001; 4: glyph_row=5'b10101; 5: glyph_row=5'b10010; 6: glyph_row=5'b01101;
                endcase
                8'h52: case(row) // R
                    0: glyph_row=5'b11110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10100; 5: glyph_row=5'b10010; 6: glyph_row=5'b10001;
                endcase
                8'h53: case(row) // S
                    0: glyph_row=5'b01111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b01110; 4: glyph_row=5'b00001; 5: glyph_row=5'b00001; 6: glyph_row=5'b11110;
                endcase
                8'h54: case(row) // T
                    0: glyph_row=5'b11111; 1: glyph_row=5'b00100; 2: glyph_row=5'b00100;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b00100; 5: glyph_row=5'b00100; 6: glyph_row=5'b00100;
                endcase
                8'h55: case(row) // U
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10001; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h56: case(row) // V
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10001; 4: glyph_row=5'b10001; 5: glyph_row=5'b01010; 6: glyph_row=5'b00100;
                endcase
                8'h57: case(row) // W
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b10101; 4: glyph_row=5'b10101; 5: glyph_row=5'b10101; 6: glyph_row=5'b01010;
                endcase
                8'h58: case(row) // X
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b01010;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b01010; 5: glyph_row=5'b10001; 6: glyph_row=5'b10001;
                endcase
                8'h59: case(row) // Y
                    0: glyph_row=5'b10001; 1: glyph_row=5'b10001; 2: glyph_row=5'b01010;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b00100; 5: glyph_row=5'b00100; 6: glyph_row=5'b00100;
                endcase
                8'h5A: case(row) // Z
                    0: glyph_row=5'b11111; 1: glyph_row=5'b00001; 2: glyph_row=5'b00010;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b01000; 5: glyph_row=5'b10000; 6: glyph_row=5'b11111;
                endcase

                8'h30: case(row) // 0
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10011;
                    3: glyph_row=5'b10101; 4: glyph_row=5'b11001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h31: case(row) // 1
                    0: glyph_row=5'b00100; 1: glyph_row=5'b01100; 2: glyph_row=5'b00100;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b00100; 5: glyph_row=5'b00100; 6: glyph_row=5'b01110;
                endcase
                8'h32: case(row) // 2
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b00001;
                    3: glyph_row=5'b00010; 4: glyph_row=5'b00100; 5: glyph_row=5'b01000; 6: glyph_row=5'b11111;
                endcase
                8'h33: case(row) // 3
                    0: glyph_row=5'b11110; 1: glyph_row=5'b00001; 2: glyph_row=5'b00001;
                    3: glyph_row=5'b01110; 4: glyph_row=5'b00001; 5: glyph_row=5'b00001; 6: glyph_row=5'b11110;
                endcase
                8'h34: case(row) // 4
                    0: glyph_row=5'b00010; 1: glyph_row=5'b00110; 2: glyph_row=5'b01010;
                    3: glyph_row=5'b10010; 4: glyph_row=5'b11111; 5: glyph_row=5'b00010; 6: glyph_row=5'b00010;
                endcase
                8'h35: case(row) // 5
                    0: glyph_row=5'b11111; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b00001; 5: glyph_row=5'b00001; 6: glyph_row=5'b11110;
                endcase
                8'h36: case(row) // 6
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10000; 2: glyph_row=5'b10000;
                    3: glyph_row=5'b11110; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h37: case(row) // 7
                    0: glyph_row=5'b11111; 1: glyph_row=5'b00001; 2: glyph_row=5'b00010;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b01000; 5: glyph_row=5'b01000; 6: glyph_row=5'b01000;
                endcase
                8'h38: case(row) // 8
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b01110; 4: glyph_row=5'b10001; 5: glyph_row=5'b10001; 6: glyph_row=5'b01110;
                endcase
                8'h39: case(row) // 9
                    0: glyph_row=5'b01110; 1: glyph_row=5'b10001; 2: glyph_row=5'b10001;
                    3: glyph_row=5'b01111; 4: glyph_row=5'b00001; 5: glyph_row=5'b00001; 6: glyph_row=5'b01110;
                endcase

                8'h2D: case(row) // -
                    3: glyph_row=5'b11111; default: glyph_row=5'b00000;
                endcase
                8'h2F: case(row) // /
                    0: glyph_row=5'b00001; 1: glyph_row=5'b00010; 2: glyph_row=5'b00010;
                    3: glyph_row=5'b00100; 4: glyph_row=5'b01000; 5: glyph_row=5'b01000; 6: glyph_row=5'b10000;
                endcase
                8'h3A: case(row) // :
                    1: glyph_row=5'b00100; 2: glyph_row=5'b00100; 4: glyph_row=5'b00100; 5: glyph_row=5'b00100;
                    default: glyph_row=5'b00000;
                endcase
                8'h2E: case(row) // .
                    6: glyph_row=5'b00100; default: glyph_row=5'b00000;
                endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    always_comb begin
        row_bits = glyph_row(i_char, i_row);
        if ((i_row < 3'd7) && (i_col < 3'd5))
            o_pixel = row_bits[4 - i_col];
        else
            o_pixel = 1'b0;
    end
endmodule
