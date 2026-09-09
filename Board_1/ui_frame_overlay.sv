`timescale 1ns / 1ps

// Board 1 HUD overlay: Security/Auth terminal
// 640x480 RGB444, one-clock RGB latency.
module ui_frame_overlay (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_de,
    input  logic [9:0]  i_x,
    input  logic [9:0]  i_y,
    input  logic [11:0] i_rgb,

    input  logic        i_auth_active,
    input  logic        i_unlock_state,
    input  logic        i_lockout,
    input  logic        i_marker_valid,
    input  logic        i_grid_valid,
    input  logic [3:0]  i_grid_id,
    input  logic [1:0]  i_auth_state,
    input  logic [2:0]  i_pattern_index,

    output logic [11:0] o_rgb
);
    localparam logic [11:0] C_BLACK      = 12'h000;
    localparam logic [11:0] C_BAR        = 12'h112;
    localparam logic [11:0] C_PANEL      = 12'h223;
    localparam logic [11:0] C_PANEL_HI   = 12'h334;
    localparam logic [11:0] C_CYAN       = 12'h0CF;
    localparam logic [11:0] C_CYAN_DIM   = 12'h056;
    localparam logic [11:0] C_WHITE      = 12'hFFF;
    localparam logic [11:0] C_GRAY       = 12'h778;
    localparam logic [11:0] C_GREEN      = 12'h2F7;
    localparam logic [11:0] C_GREEN_DIM  = 12'h153;
    localparam logic [11:0] C_YELLOW     = 12'hFD2;
    localparam logic [11:0] C_YELLOW_DIM = 12'h542;
    localparam logic [11:0] C_RED        = 12'hF33;
    localparam logic [11:0] C_RED_DIM    = 12'h511;

    logic [11:0] pixel_c;
    logic [11:0] status_color;
    logic [11:0] status_fill;
    logic [1:0]  status_sel; // 0=LOCKED 1=AUTH 2=UNLOCKED 3=LOCKOUT
    logic [2:0]  progress;

    logic [7:0] font_char;
    logic [2:0] font_row, font_col;
    logic       font_pixel;
    logic       text_req;
    logic [11:0] text_color;
    integer idx;
    integer dx, dy;

    ui_font5x7 U_FONT (
        .i_char (font_char),
        .i_row  (font_row),
        .i_col  (font_col),
        .o_pixel(font_pixel)
    );

    function automatic logic [7:0] title1_char(input integer n);
        begin
            case(n)
                0:title1_char="S"; 1:title1_char="E"; 2:title1_char="C"; 3:title1_char="U";
                4:title1_char="R"; 5:title1_char="E"; 6:title1_char=" "; 7:title1_char="V";
                8:title1_char="I"; 9:title1_char="S"; 10:title1_char="I"; 11:title1_char="O";
                12:title1_char="N"; default:title1_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] title2_char(input integer n);
        begin
            case(n)
                0:title2_char="A"; 1:title2_char="U"; 2:title2_char="T"; 3:title2_char="H";
                4:title2_char=" "; 5:title2_char="T"; 6:title2_char="E"; 7:title2_char="R";
                8:title2_char="M"; 9:title2_char="I"; 10:title2_char="N"; 11:title2_char="A";
                12:title2_char="L"; default:title2_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] pattern_char(input integer n);
        begin
            case(n)
                0:pattern_char="P"; 1:pattern_char="A"; 2:pattern_char="T"; 3:pattern_char="T";
                4:pattern_char="E"; 5:pattern_char="R"; 6:pattern_char="N"; default:pattern_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] grid_char(input integer n);
        begin
            case(n)
                0:grid_char="G"; 1:grid_char="R"; 2:grid_char="I"; 3:grid_char="D";
                default:grid_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] status_char(input logic [1:0] sel, input integer n);
        begin
            status_char = " ";
            case(sel)
                2'd0: case(n) // LOCKED
                    0:status_char="L";1:status_char="O";2:status_char="C";3:status_char="K";4:status_char="E";5:status_char="D";
                endcase
                2'd1: case(n) // AUTHENTICATING
                    0:status_char="A";1:status_char="U";2:status_char="T";3:status_char="H";
                    4:status_char="E";5:status_char="N";6:status_char="T";7:status_char="I";
                    8:status_char="C";9:status_char="A";10:status_char="T";11:status_char="I";
                    12:status_char="N";13:status_char="G";
                endcase
                2'd2: case(n) // UNLOCKED
                    0:status_char="U";1:status_char="N";2:status_char="L";3:status_char="O";
                    4:status_char="C";5:status_char="K";6:status_char="E";7:status_char="D";
                endcase
                2'd3: case(n) // LOCKOUT
                    0:status_char="L";1:status_char="O";2:status_char="C";3:status_char="K";
                    4:status_char="O";5:status_char="U";6:status_char="T";
                endcase
            endcase
        end
    endfunction

    function automatic logic [7:0] marker_char(input logic valid, input integer n);
        begin
            marker_char = " ";
            if (valid) begin // MARKER DETECTED
                case(n)
                    0:marker_char="M";1:marker_char="A";2:marker_char="R";3:marker_char="K";
                    4:marker_char="E";5:marker_char="R";6:marker_char=" ";7:marker_char="D";
                    8:marker_char="E";9:marker_char="T";10:marker_char="E";11:marker_char="C";
                    12:marker_char="T";13:marker_char="E";14:marker_char="D";
                endcase
            end else begin // MARKER LOST
                case(n)
                    0:marker_char="M";1:marker_char="A";2:marker_char="R";3:marker_char="K";
                    4:marker_char="E";5:marker_char="R";6:marker_char=" ";7:marker_char="L";
                    8:marker_char="O";9:marker_char="S";10:marker_char="T";
                endcase
            end
        end
    endfunction

    always_comb begin
        if (i_lockout) begin
            status_sel   = 2'd3;
            status_color = C_RED;
            status_fill  = C_RED_DIM;
        end else if (i_unlock_state) begin
            status_sel   = 2'd2;
            status_color = C_GREEN;
            status_fill  = C_GREEN_DIM;
        end else if (i_auth_active) begin
            status_sel   = 2'd1;
            status_color = C_YELLOW;
            status_fill  = C_YELLOW_DIM;
        end else begin
            status_sel   = 2'd0;
            status_color = C_CYAN;
            status_fill  = C_PANEL;
        end

        if (i_unlock_state)
            progress = 3'd6;
        else if (i_auth_active && (i_auth_state == 2'd2))
            progress = 3'd6;
        else if (i_auth_active)
            progress = i_pattern_index;
        else
            progress = 3'd0;
    end

    // Base HUD shapes. The live camera image remains untouched between the bars.
    always_comb begin
        pixel_c = i_de ? i_rgb : C_BLACK;

        if (i_de) begin
            // Header and footer surfaces
            if (i_y < 10'd40)
                pixel_c = C_BAR;
            if (i_y >= 10'd432)
                pixel_c = C_BAR;

            // Subtle two-level depth bands
            if ((i_y >= 10'd3) && (i_y < 10'd6))
                pixel_c = C_PANEL;
            if ((i_y >= 10'd474) && (i_y < 10'd477))
                pixel_c = C_PANEL;

            // Outer frame and double separators
            if ((i_x == 10'd0) || (i_x == 10'd639) ||
                (i_y == 10'd0) || (i_y == 10'd479))
                pixel_c = C_CYAN_DIM;
            if ((i_y == 10'd39) || (i_y == 10'd431))
                pixel_c = C_CYAN;
            if ((i_y == 10'd41) || (i_y == 10'd429))
                pixel_c = C_CYAN_DIM;

            // Brand rail and title divider
            if ((i_x >= 10'd10) && (i_x < 10'd13) &&
                (i_y >= 10'd11) && (i_y < 10'd29))
                pixel_c = C_CYAN;
            if ((i_x == 10'd132) && (i_y >= 10'd11) && (i_y < 10'd29))
                pixel_c = C_CYAN_DIM;

            // Camera viewport corner brackets
            if (((i_y == 10'd47) || (i_y == 10'd423)) &&
                (((i_x >= 10'd8) && (i_x < 10'd28)) ||
                 ((i_x >= 10'd612) && (i_x < 10'd632))))
                pixel_c = C_CYAN_DIM;
            if (((i_x == 10'd8) || (i_x == 10'd631)) &&
                (((i_y >= 10'd47) && (i_y < 10'd63)) ||
                 ((i_y >= 10'd408) && (i_y <= 10'd423))))
                pixel_c = C_CYAN_DIM;

            // Header status badge with state-coloured fill and double border
            if ((i_x >= 10'd452) && (i_x < 10'd630) &&
                (i_y >= 10'd7) && (i_y < 10'd32))
                pixel_c = status_fill;
            if ((i_x >= 10'd452) && (i_x < 10'd630) &&
                ((i_y == 10'd7) || (i_y == 10'd31)))
                pixel_c = status_color;
            if ((i_y >= 10'd7) && (i_y < 10'd32) &&
                ((i_x == 10'd452) || (i_x == 10'd629)))
                pixel_c = status_color;
            if ((i_x >= 10'd456) && (i_x < 10'd626) &&
                ((i_y == 10'd10) || (i_y == 10'd28)))
                pixel_c = C_PANEL_HI;

            // Badge indicator LED and its dark socket
            if ((i_x >= 10'd460) && (i_x < 10'd470) &&
                (i_y >= 10'd15) && (i_y < 10'd24))
                pixel_c = C_BLACK;
            if ((i_x >= 10'd462) && (i_x < 10'd468) &&
                (i_y >= 10'd17) && (i_y < 10'd22))
                pixel_c = status_color;

            // Three footer cards
            if ((((i_x >= 10'd8)   && (i_x < 10'd204)) ||
                 ((i_x >= 10'd210) && (i_x < 10'd315)) ||
                 ((i_x >= 10'd321) && (i_x < 10'd632))) &&
                (i_y >= 10'd439) && (i_y < 10'd473))
                pixel_c = C_PANEL;

            // Footer card outlines
            if ((((i_x >= 10'd8)   && (i_x < 10'd204)) ||
                 ((i_x >= 10'd210) && (i_x < 10'd315)) ||
                 ((i_x >= 10'd321) && (i_x < 10'd632))) &&
                ((i_y == 10'd439) || (i_y == 10'd472)))
                pixel_c = C_CYAN_DIM;
            if ((((i_x == 10'd8) || (i_x == 10'd203) ||
                  (i_x == 10'd210) || (i_x == 10'd314) ||
                  (i_x == 10'd321) || (i_x == 10'd631))) &&
                (i_y >= 10'd439) && (i_y <= 10'd472))
                pixel_c = C_CYAN_DIM;

            // Card accent rails
            if ((i_y == 10'd439) && (i_x >= 10'd16) && (i_x < 10'd72))
                pixel_c = C_YELLOW;
            if ((i_y == 10'd439) && (i_x >= 10'd218) && (i_x < 10'd250))
                pixel_c = C_CYAN;
            if ((i_y == 10'd439) && (i_x >= 10'd329) && (i_x < 10'd385))
                pixel_c = i_marker_valid ? C_GREEN : C_GRAY;

            // Six pattern progress blocks
            if ((i_y >= 10'd460) && (i_y < 10'd469)) begin
                if ((i_x >= 10'd88) && (i_x < 10'd98))   pixel_c = (progress >= 1) ? C_YELLOW : C_PANEL_HI;
                if ((i_x >= 10'd104) && (i_x < 10'd114)) pixel_c = (progress >= 2) ? C_YELLOW : C_PANEL_HI;
                if ((i_x >= 10'd120) && (i_x < 10'd130)) pixel_c = (progress >= 3) ? C_YELLOW : C_PANEL_HI;
                if ((i_x >= 10'd136) && (i_x < 10'd146)) pixel_c = (progress >= 4) ? C_YELLOW : C_PANEL_HI;
                if ((i_x >= 10'd152) && (i_x < 10'd162)) pixel_c = (progress >= 5) ? C_YELLOW : C_PANEL_HI;
                if ((i_x >= 10'd168) && (i_x < 10'd178)) pixel_c = (progress >= 6) ? C_YELLOW : C_PANEL_HI;
            end

            // Marker LED
            if ((i_x >= 10'd329) && (i_x < 10'd339) &&
                (i_y >= 10'd446) && (i_y < 10'd456))
                pixel_c = C_BLACK;
            if ((i_x >= 10'd331) && (i_x < 10'd337) &&
                (i_y >= 10'd448) && (i_y < 10'd454))
                pixel_c = i_marker_valid ? C_GREEN : C_GRAY;
        end
    end

    // Select one text glyph for current pixel. Cell = 8x8, glyph = 5x7.
    always_comb begin
        font_char  = " ";
        font_row   = 3'd0;
        font_col   = 3'd0;
        text_req   = 1'b0;
        text_color = C_WHITE;
        idx = 0; dx = 0; dy = 0;

        // SECURE VISION
        if ((i_x >= 10'd16) && (i_x < 10'd120) && (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 16; dy = i_y - 15; idx = dx >> 3;
            font_char = title1_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        // AUTH TERMINAL
        else if ((i_x >= 10'd144) && (i_x < 10'd248) && (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 144; dy = i_y - 15; idx = dx >> 3;
            font_char = title2_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_CYAN;
        end
        // Dynamic badge text
        else if ((i_x >= 10'd487) && (i_x < 10'd623) && (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 487; dy = i_y - 15; idx = dx >> 3;
            font_char = status_char(status_sel, idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = status_color;
        end
        // PATTERN
        else if ((i_x >= 10'd18) && (i_x < 10'd74) && (i_y >= 10'd445) && (i_y < 10'd453)) begin
            dx = i_x - 18; dy = i_y - 445; idx = dx >> 3;
            font_char = pattern_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        // Progress text 0N/06
        else if ((i_x >= 10'd86) && (i_x < 10'd126) && (i_y >= 10'd445) && (i_y < 10'd453)) begin
            dx = i_x - 86; dy = i_y - 445; idx = dx >> 3;
            case(idx)
                0: font_char = "0";
                1: font_char = 8'h30 + progress;
                2: font_char = "/";
                3: font_char = "0";
                4: font_char = "6";
                default: font_char = " ";
            endcase
            font_col = dx[2:0]; font_row = dy[2:0]; text_req = 1'b1; text_color = C_YELLOW;
        end
        // GRID
        else if ((i_x >= 10'd220) && (i_x < 10'd252) && (i_y >= 10'd450) && (i_y < 10'd458)) begin
            dx = i_x - 220; dy = i_y - 450; idx = dx >> 3;
            font_char = grid_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        // Dynamic grid ID
        else if ((i_x >= 10'd266) && (i_x < 10'd274) && (i_y >= 10'd450) && (i_y < 10'd458)) begin
            dx = i_x - 266; dy = i_y - 450;
            font_char = i_grid_valid ? (8'h30 + i_grid_id) : "-";
            font_col = dx[2:0]; font_row = dy[2:0]; text_req = 1'b1;
            text_color = i_grid_valid ? C_YELLOW : C_GRAY;
        end
        // Marker state text
        else if ((i_x >= 10'd342) && (i_x < 10'd462) && (i_y >= 10'd447) && (i_y < 10'd455)) begin
            dx = i_x - 342; dy = i_y - 447; idx = dx >> 3;
            font_char = marker_char(i_marker_valid, idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = i_marker_valid ? C_GREEN : C_GRAY;
        end
    end

    logic [11:0] final_c;
    always_comb begin
        final_c = pixel_c;
        if (text_req && font_pixel)
            final_c = text_color;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            o_rgb <= C_BLACK;
        else
            o_rgb <= final_c;
    end
endmodule
