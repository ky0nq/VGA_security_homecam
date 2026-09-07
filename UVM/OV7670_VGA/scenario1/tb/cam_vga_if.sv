`timescale 1ns/1ps
interface cam_vga_if(input logic clk, input logic pclk);
    logic rst_n = 0;
    logic cam_href = 0, cam_vsync = 0;
    logic [7:0] cam_data = 0;
    // Test selection, set once before reset is released.
    // TB-COV-01: Configuration metadata, not DUT activity. Functional bins remain enabled.
    //VCS coverage off
    bit check_camera = 0, check_vga = 0, check_sccb = 0;
    bit link_camera_to_vga = 0;
    int camera_phase_ns = 0;
    //VCS coverage on
    logic sccb_start = 0;
    // Independent VGA stimulus: write through the RAM's real input ports.
    logic mem_we = 0;
    logic [16:0] mem_addr = 0;
    logic [15:0] mem_data = 0;
    logic setup_busy, setup_done, setup_error, cam_scl, xclk;
    tri1 cam_sda;
    logic sccb_ack_low = 0;
    assign cam_sda = sccb_ack_low ? 1'b0 : 1'bz;
    logic h_sync, v_sync;
    logic [11:0] rgb;
    // Read-only observation taps; the RTL snapshot is unchanged.
    logic cap_we;
    logic [16:0] cap_addr, rd_addr;
    logic [15:0] cap_data, rd_data;
    logic de;
    logic [9:0] x, y;
    // Test intent tags, never pixel/address golden data.
    // TB-COV-02: Scenario tags/counters have no all-bits-toggle requirement.
    //VCS coverage off
    int pattern_id = 0;
    //VCS coverage on
    bit capture_complete = 0;
    // TB-COV-02 continued: stimulus selection and profile metadata only.
    //VCS coverage off
    int nack_transaction = -1, nack_byte = -1;
    int cfg_freq_hz = 1000000, sccb_freq_hz = 100000;
    int sccb_epoch = 0;
    //VCS coverage on
    // Read-only state taps for scheduling reset tests, NOT scoreboard goldens.
    logic [3:0] sccb_master_state;
    logic [1:0] sccb_master_step;
    logic [2:0] sccb_setup_state;
endinterface
