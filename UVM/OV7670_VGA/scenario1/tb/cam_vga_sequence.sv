// One transaction carries one image line, sent as camera bytes or RAM input.
class cam_vga_sequence extends uvm_sequence #(cam_vga_seq_item);
    `uvm_object_utils(cam_vga_sequence)
    pattern_e selected_pattern = COLOR_BARS;
    bit error_cases = 0;
    bit memory_mode = 0;
    function new(string name = "cam_vga_sequence"); super.new(name); endfunction

    function automatic bit [15:0] pattern_pixel(pattern_e p, int x, int y);
        bit [4:0] r, b;
        bit [5:0] g;
        case (p)
            COLOR_BARS: case (x/40)
                0: return 16'h0000; 1: return 16'hffff;
                2: return 16'hf800; 3: return 16'h07e0;
                4: return 16'h001f; 5: return 16'hffe0;
                6: return 16'hf81f; 7: return 16'h07ff;
            endcase
            H_GRADIENT: begin r=x*31/319; g=x*63/319; b=r; end
            V_GRADIENT: begin r=y*31/239; g=y*63/239; b=r; end
            CHECKERBOARD: return (((x/8)+(y/8))%2) ? 16'hffff : 16'h0000;
            QUADRANTS: begin
                if (y<120) return (x<160) ? 16'hf800 : 16'h07e0;
                else return (x<160) ? 16'h001f : 16'hffff;
            end
            CHANNEL_WALK: begin r=x%32; g=y%64; b=(x+y)%32; end
            default: begin r=0; g=0; b=0; end
        endcase
        return {r,g,b};
    endfunction

    task send_command(command_e cmd, int count = 1);
        cam_vga_seq_item req;
        req=cam_vga_seq_item::type_id::create("command");
        start_item(req);
        req.command=cmd; req.pattern=selected_pattern;
        req.gap_cycles=count;
        finish_item(req);
    endtask

    task send_line(int y, int count = 320);
        cam_vga_seq_item req;
        req=cam_vga_seq_item::type_id::create("line");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RANDOMIZE", "Camera line randomization failed")
        req.command=memory_mode ? CMD_MEM_LINE : CMD_LINE;
        req.pattern=selected_pattern;
        req.line_number=y; req.pixel_count=count;
        if (selected_pattern != RANDOM_PIXELS)
            foreach (req.pixels[x]) req.pixels[x]=pattern_pixel(selected_pattern,x,y);
        finish_item(req);
    endtask

    task body();
        if (error_cases && !memory_mode) begin
            send_command(CMD_VSYNC);
            send_command(CMD_PARTIAL_HREF);
            send_line(0,319);
            send_command(CMD_PARTIAL_VSYNC);
            send_line(0,321);
            // Reset after one high byte, then recovery to a complete frame.
            send_command(CMD_RESET);
        end
        if (!memory_mode) send_command(CMD_VSYNC);
        for (int y=0;y<240;y++) send_line(y);
        send_command(CMD_FRAME_DONE);
    endtask
endclass

class cam_vga_command_sequence extends uvm_sequence #(cam_vga_seq_item);
    `uvm_object_utils(cam_vga_command_sequence)
    command_e command=CMD_RESET;
    function new(string name="cam_vga_command_sequence"); super.new(name); endfunction
    task body();
        cam_vga_seq_item req;
        req=cam_vga_seq_item::type_id::create("req");
        start_item(req);
        req.command=command; req.gap_cycles=4;
        finish_item(req);
    endtask
endclass
