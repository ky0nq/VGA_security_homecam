`timescale 1ns / 1ps

// Board 2 HUD overlay: Home Cam monitor
// 640x480 RGB444, one-clock RGB latency.
module ui_frame_overlay (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        i_de,
    input  logic [9:0]  i_x,
    input  logic [9:0]  i_y,
    input  logic [11:0] i_rgb,

    input  logic        i_unlock_en,
    input  logic        i_zoom_en,
    input  logic [3:0]  i_filter_id,

    output logic [11:0] o_rgb
);
    localparam logic [11:0] C_BLACK     = 12'h000;
    localparam logic [11:0] C_BAR       = 12'h112;
    localparam logic [11:0] C_PANEL     = 12'h223;
    localparam logic [11:0] C_PANEL_HI  = 12'h334;
    localparam logic [11:0] C_CYAN      = 12'h0CF;
    localparam logic [11:0] C_CYAN_DIM  = 12'h056;
    localparam logic [11:0] C_WHITE     = 12'hFFF;
    localparam logic [11:0] C_GRAY      = 12'h778;
    localparam logic [11:0] C_GREEN     = 12'h2F7;
    localparam logic [11:0] C_GREEN_DIM = 12'h153;
    localparam logic [11:0] C_BLUE      = 12'h28F;
    localparam logic [11:0] C_BLUE_DIM  = 12'h124;

    logic [11:0] pixel_c;
    logic [11:0] status_color;
    logic [11:0] status_fill;

    logic [7:0]  font_char;
    logic [2:0]  font_row, font_col;
    logic        font_pixel;
    logic        text_req;
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
                0:title2_char="H"; 1:title2_char="O"; 2:title2_char="M"; 3:title2_char="E";
                4:title2_char=" "; 5:title2_char="C"; 6:title2_char="A"; 7:title2_char="M";
                default:title2_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] unlocked_char(input integer n);
        begin
            case(n)
                0:unlocked_char="U"; 1:unlocked_char="N"; 2:unlocked_char="L"; 3:unlocked_char="O";
                4:unlocked_char="C"; 5:unlocked_char="K"; 6:unlocked_char="E"; 7:unlocked_char="D";
                default:unlocked_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] locked_char(input integer n);
        begin
            case(n)
                0:locked_char="L"; 1:locked_char="O"; 2:locked_char="C"; 3:locked_char="K";
                4:locked_char="E"; 5:locked_char="D"; default:locked_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] privacy_char(input integer n);
        begin
            case(n)
                0:privacy_char="P"; 1:privacy_char="R"; 2:privacy_char="I"; 3:privacy_char="V";
                4:privacy_char="A"; 5:privacy_char="C"; 6:privacy_char="Y"; 7:privacy_char=" ";
                8:privacy_char="M"; 9:privacy_char="O"; 10:privacy_char="D"; 11:privacy_char="E";
                default:privacy_char=" ";
            endcase
        end
    endfunction

    function automatic logic [7:0] zoom_char(input integer n);
        begin
            case(n)
                0:zoom_char="Z"; 1:zoom_char="O"; 2:zoom_char="O"; 3:zoom_char="M";
                default:zoom_char=" ";
            endcase
        end
    endfunction

    // Active effect names: 0 NORMAL, 4 GRAY, 5 BRIGHT, 6 BRIGHTER, 7 NIGHT
    function automatic logic [7:0] filter_name_char(input logic [3:0] id, input integer n);
        begin
            filter_name_char = " ";
            case(id)
                4'd0: case(n) 0:filter_name_char="N";1:filter_name_char="O";2:filter_name_char="R";3:filter_name_char="M";4:filter_name_char="A";5:filter_name_char="L"; endcase
                4'd4: case(n) 0:filter_name_char="G";1:filter_name_char="R";2:filter_name_char="A";3:filter_name_char="Y"; endcase
                4'd5: case(n) 0:filter_name_char="B";1:filter_name_char="R";2:filter_name_char="I";3:filter_name_char="G";4:filter_name_char="H";5:filter_name_char="T"; endcase
                4'd6: case(n) 0:filter_name_char="B";1:filter_name_char="R";2:filter_name_char="I";3:filter_name_char="G";4:filter_name_char="H";5:filter_name_char="T";6:filter_name_char="E";7:filter_name_char="R"; endcase
                4'd7: case(n) 0:filter_name_char="N";1:filter_name_char="I";2:filter_name_char="G";3:filter_name_char="H";4:filter_name_char="T"; endcase
                default: filter_name_char = " ";
            endcase
        end
    endfunction

    always_comb begin
        if (i_unlock_en) begin
            status_color = C_GREEN;
            status_fill  = C_GREEN_DIM;
        end else begin
            status_color = C_BLUE;
            status_fill  = C_BLUE_DIM;
        end

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

            // Locked privacy panel over the blurred video
            if (!i_unlock_en) begin
                if ((i_x >= 10'd210) && (i_x < 10'd430) &&
                    (i_y >= 10'd190) && (i_y < 10'd280))
                    pixel_c = C_PANEL;
                if ((i_x >= 10'd210) && (i_x < 10'd430) &&
                    ((i_y == 10'd190) || (i_y == 10'd279)))
                    pixel_c = status_color;
                if ((i_y >= 10'd190) && (i_y < 10'd280) &&
                    ((i_x == 10'd210) || (i_x == 10'd429)))
                    pixel_c = status_color;
                if ((i_x >= 10'd216) && (i_x < 10'd424) &&
                    ((i_y == 10'd196) || (i_y == 10'd273)))
                    pixel_c = C_PANEL_HI;
                if ((i_x >= 10'd226) && (i_x < 10'd414) && (i_y == 10'd190))
                    pixel_c = C_BLUE;
                if ((i_x >= 10'd228) && (i_x < 10'd412) && (i_y == 10'd261))
                    pixel_c = C_CYAN_DIM;
                if ((i_x >= 10'd224) && (i_x < 10'd234) &&
                    (i_y >= 10'd207) && (i_y < 10'd216))
                    pixel_c = C_BLACK;
                if ((i_x >= 10'd226) && (i_x < 10'd232) &&
                    (i_y >= 10'd209) && (i_y < 10'd214))
                    pixel_c = C_BLUE;
            end

            // Two footer cards: current effect status and ZOOM
            if ((((i_x >= 10'd8)   && (i_x < 10'd405)) ||
                 ((i_x >= 10'd411) && (i_x < 10'd632))) &&
                (i_y >= 10'd439) && (i_y < 10'd473))
                pixel_c = C_PANEL;

            // Footer card outlines
            if ((((i_x >= 10'd8)   && (i_x < 10'd405)) ||
                 ((i_x >= 10'd411) && (i_x < 10'd632))) &&
                ((i_y == 10'd439) || (i_y == 10'd472)))
                pixel_c = C_CYAN_DIM;
            if (((i_x == 10'd8) || (i_x == 10'd404) ||
                 (i_x == 10'd411) || (i_x == 10'd631)) &&
                (i_y >= 10'd439) && (i_y <= 10'd472))
                pixel_c = C_CYAN_DIM;

            // Card accent rails
            if ((i_y == 10'd439) && (i_x >= 10'd419) && (i_x < 10'd451))
                pixel_c = (i_unlock_en && i_zoom_en) ? C_GREEN : C_GRAY;

            // Zoom LED and level bars
            if ((i_x >= 10'd419) && (i_x < 10'd429) &&
                (i_y >= 10'd446) && (i_y < 10'd456))
                pixel_c = C_BLACK;
            if ((i_x >= 10'd421) && (i_x < 10'd427) &&
                (i_y >= 10'd448) && (i_y < 10'd454))
                pixel_c = (i_unlock_en && i_zoom_en) ? C_GREEN : C_GRAY;
            if ((i_y >= 10'd461) && (i_y < 10'd469)) begin
                if ((i_x >= 10'd494) && (i_x < 10'd518))
                    pixel_c = i_unlock_en ? C_CYAN_DIM : C_PANEL_HI;
                if ((i_x >= 10'd524) && (i_x < 10'd548))
                    pixel_c = (i_unlock_en && i_zoom_en) ? C_GREEN : C_PANEL_HI;
            end
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
        if ((i_x >= 10'd16) && (i_x < 10'd120) &&
            (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 16; dy = i_y - 15; idx = dx >> 3;
            font_char = title1_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        // HOME CAM
        else if ((i_x >= 10'd144) && (i_x < 10'd208) &&
                 (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 144; dy = i_y - 15; idx = dx >> 3;
            font_char = title2_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_CYAN;
        end
        // Dynamic LOCKED / UNLOCKED badge
        else if ((i_x >= 10'd487) && (i_x < 10'd623) &&
                 (i_y >= 10'd15) && (i_y < 10'd23)) begin
            dx = i_x - 487; dy = i_y - 15; idx = dx >> 3;
            font_char = i_unlock_en ? unlocked_char(idx) : locked_char(idx);
            font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = status_color;
        end
        // Large LOCKED message, only while privacy mode is active
        else if (!i_unlock_en &&
                 (i_x >= 10'd272) && (i_x < 10'd368) &&
                 (i_y >= 10'd216) && (i_y < 10'd232)) begin
            dx = i_x - 272; dy = i_y - 216; idx = dx >> 4;
            font_char = locked_char(idx); font_col = dx[3:1]; font_row = dy[3:1];
            text_req = 1'b1; text_color = C_BLUE;
        end
        // PRIVACY MODE
        else if (!i_unlock_en &&
                 (i_x >= 10'd272) && (i_x < 10'd368) &&
                 (i_y >= 10'd246) && (i_y < 10'd254)) begin
            dx = i_x - 272; dy = i_y - 246; idx = dx >> 3;
            font_char = privacy_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        // Current effect name only; no mode label or selector blocks
        else if ((i_x >= 10'd18) && (i_x < 10'd90) &&
                 (i_y >= 10'd447) && (i_y < 10'd455)) begin
            dx = i_x - 18; dy = i_y - 447; idx = dx >> 3;
            font_char = filter_name_char(i_filter_id, idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = i_unlock_en ? C_CYAN : C_GRAY;
        end
        // ZOOM and X2/OFF value
        else if ((i_x >= 10'd438) && (i_x < 10'd470) &&
                 (i_y >= 10'd447) && (i_y < 10'd455)) begin
            dx = i_x - 438; dy = i_y - 447; idx = dx >> 3;
            font_char = zoom_char(idx); font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1; text_color = C_WHITE;
        end
        else if ((i_x >= 10'd494) && (i_x < 10'd526) &&
                 (i_y >= 10'd447) && (i_y < 10'd455)) begin
            dx = i_x - 494; dy = i_y - 447; idx = dx >> 3;
            if (i_zoom_en) begin
                case(idx)
                    0:font_char="X"; 1:font_char="2"; default:font_char=" ";
                endcase
            end else begin
                case(idx)
                    0:font_char="O"; 1:font_char="F"; 2:font_char="F"; default:font_char=" ";
                endcase
            end
            font_col = dx[2:0]; font_row = dy[2:0];
            text_req = 1'b1;
            text_color = (i_unlock_en && i_zoom_en) ? C_GREEN : C_GRAY;
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
