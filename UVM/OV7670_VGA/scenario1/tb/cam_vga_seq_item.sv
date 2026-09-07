typedef enum int {COLOR_BARS, H_GRADIENT, V_GRADIENT, CHECKERBOARD,
                  RANDOM_PIXELS, QUADRANTS, CHANNEL_WALK} pattern_e;
typedef enum int {CMD_VSYNC, CMD_LINE, CMD_PARTIAL_HREF, CMD_PARTIAL_VSYNC,
                  CMD_RESET, CMD_IDLE, CMD_FRAME_DONE, CMD_MEM_LINE,
                  CMD_SCCB_START, CMD_RESET_RAW, CMD_RESET_ACTIVE,
                  CMD_RESET_BETWEEN, CMD_SCCB_RESET_AT} command_e;
typedef enum int {OBS_CAMERA, OBS_VGA, OBS_MEMORY, OBS_RESET} observation_e;

class cam_vga_seq_item extends uvm_sequence_item;
    `uvm_object_utils(cam_vga_seq_item)
    command_e command;
    // Directed reset scheduling only; never supplies expected SCCB data.
    bit sccb_target_setup = 0;
    int sccb_target_state = -1;
    int sccb_target_step = -1; // -1 accepts any quarter-bit phase.
    bit sccb_target_observed = 0;
    pattern_e pattern;
    // Observations leave this empty; only randomized line requests allocate it.
    rand bit [15:0] pixels[];
    constraint c_pixels { pixels.size() == 320; }
    rand int unsigned gap_cycles;
    constraint c_gap { gap_cycles inside {[1:8]}; }
    int line_number, pixel_count = 320;
    observation_e observation;
    bit reset_active;
    logic href, vsync;
    logic [7:0] camera_byte;
    logic write_en;
    logic [16:0] write_addr, read_addr;
    logic [15:0] write_data, read_data;
    logic [9:0] x, y;
    logic de, hsync, vsync_out;
    logic [11:0] rgb;
    bit full_frame_ready;
    time sample_time;
    function new(string name = "cam_vga_seq_item"); super.new(name); endfunction
endclass
