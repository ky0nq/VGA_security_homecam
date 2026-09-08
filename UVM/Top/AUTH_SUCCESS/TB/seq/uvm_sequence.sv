class Sequence extends uvm_sequence #(transaction);
    `uvm_object_utils(Sequence)

    function new(string name = "Sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_mode(TEST_START);
        send_mode(TEST_END);
    endtask

    task automatic send_mode(input c_mode mode);
        transaction tr;
        tr = transaction::type_id::create("tr");
        start_item(tr);
        tr.mode = mode;
        finish_item(tr);
    endtask

    task automatic send_reset();
        send_mode(RESET);
    endtask

    task automatic send_write();
        send_mode(SCCB_WRITE);
    endtask

    task automatic send_read(input logic [7:0] read_data);
        transaction tr;
        tr = transaction::type_id::create("read_tr");
        start_item(tr);
        tr.mode = SCCB_READ;
        tr.sccb_read_data = read_data;
        finish_item(tr);
    endtask

    task automatic send_button(
        input logic press_up,
        input logic press_down,
        input logic press_left,
        input logic press_right,
        input int unsigned hold_cycles = 10_010
    );
        transaction tr;
        tr = transaction::type_id::create("button_tr");
        start_item(tr);
        tr.mode               = BUTTON_PRESS;
        tr.btn_U              = press_up;
        tr.btn_D              = press_down;
        tr.btn_L              = press_left;
        tr.btn_R              = press_right;
        tr.button_hold_cycles = hold_cycles;
        finish_item(tr);
    endtask

    task automatic send_switches(
        input logic drive_auth_sw,
        input logic drive_zoom_en,
        input logic drive_effect_en,
        input int unsigned hold_cycles = 100
    );
        transaction tr;
        tr = transaction::type_id::create("switch_tr");
        start_item(tr);
        tr.mode               = SWITCH_SET;
        tr.auth_sw            = drive_auth_sw;
        tr.zoom_en            = drive_zoom_en;
        tr.effect_en          = drive_effect_en;
        tr.switch_hold_cycles = hold_cycles;
        finish_item(tr);
    endtask

    task automatic send_camera_frame(
        input logic [15:0] rgb565 = 16'h001f,
        input logic        use_image = 1'b0
    );
        transaction tr;
        tr = transaction::type_id::create("camera_frame_tr");
        start_item(tr);
        tr.mode                     = CAMERA_FRAME;
        tr.camera_rgb565            = rgb565;
        tr.camera_use_image         = use_image;
        tr.camera_width             = 320;
        tr.camera_height            = 240;
        tr.camera_line_blank_cycles = 2;
        finish_item(tr);
    endtask

    task automatic send_auth_grid(input logic [3:0] grid_id);
        transaction tr;
        tr = transaction::type_id::create("auth_grid_tr");
        start_item(tr);
        tr.mode = CAMERA_FRAME;
        tr.camera_use_auth_grid = 1'b1;
        tr.camera_grid_id = grid_id;
        tr.camera_width = 320;
        tr.camera_height = 240;
        tr.camera_line_blank_cycles = 2;
        finish_item(tr);
    endtask

endclass

// NORMAL/GAUSSIAN: exercise physical controls and send three camera frames.
// The final photo frame provides reference data for video checks.
class Sequence_write_buttons extends Sequence;
    `uvm_object_utils(Sequence_write_buttons)

    function new(string name = "Sequence_write_buttons");
        super.new(name);
    endfunction

    virtual task body();
        send_mode(TEST_START);
        send_reset();
        repeat (67) send_write();

        // Hold each button longer than the debounce threshold.
        send_button(1'b1, 1'b0, 1'b0, 1'b0);
        send_button(1'b0, 1'b1, 1'b0, 1'b0);
        send_button(1'b0, 1'b0, 1'b1, 1'b0);
        send_button(1'b0, 1'b0, 1'b0, 1'b1);

        // Exercise each switch, then restore the default settings.
        send_switches(1'b1, 1'b0, 1'b0);
        send_switches(1'b0, 1'b1, 1'b0);
        send_switches(1'b0, 1'b0, 1'b1);
        send_switches(1'b0, 1'b0, 1'b0);
        // Use photo data for the third camera frame.
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b1);
        send_mode(TEST_END);
    endtask
endclass

// Board 2 camera stimulus: complete SCCB setup, then send two blue frames and a photo.
// This supplies a known image for normal, blur, and zoom comparisons.
class Sequence_write_camera extends Sequence;
    `uvm_object_utils(Sequence_write_camera)

    function new(string name = "Sequence_write_camera");
        super.new(name);
    endfunction

    virtual task body();
        send_mode(TEST_START);
        send_reset();
        repeat (67) send_write();
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b1);
        send_mode(TEST_END);
    endtask
endclass

// ZOOM: authenticate with camera grids 1,2,3,6,5,8 before selecting a zoom region.
// This exercises the camera-to-authentication-to-UART path without forcing success.
class Sequence_write_zoom extends Sequence;
    `uvm_object_utils(Sequence_write_zoom)
    int zoom_id;
    virtual vga_if board1_vga_vif;
    virtual vga_if board2_vga_vif;

    function new(string name = "Sequence_write_zoom");
        super.new(name);
    endfunction

    task automatic drive_zoom_button(
        input logic press_left,
        input logic press_right,
        input logic press_down
    );
        transaction tr;
        tr = transaction::type_id::create("zoom_button_tr");
        start_item(tr);
        tr.mode               = BUTTON_PRESS;
        tr.btn_U              = 1'b0;
        tr.btn_D              = press_down;
        tr.btn_L              = press_left;
        tr.btn_R              = press_right;
        tr.auth_sw            = 1'b1;
        tr.zoom_en            = 1'b1;
        tr.effect_en          = 1'b0;
        // Allow margin beyond 10,000 debounce cycles at the 1 MHz parameter setting.
        tr.button_hold_cycles = 10_010;
        finish_item(tr);
    endtask

    virtual task body();
        send_mode(TEST_START);
        send_reset();
        repeat (67) send_write();
        // Exercise the actual tracking, grid, and authentication path with zoom disabled.
        send_switches(1'b1, 1'b0, 1'b0, 4);
        send_auth_grid(4'd1);
        send_auth_grid(4'd2);
        send_auth_grid(4'd3);
        send_auth_grid(4'd6);
        send_auth_grid(4'd5);
        send_auth_grid(4'd8);
        // Refresh the grid-8 result and allow the final hold to complete.
        send_auth_grid(4'd8);
        wait (board1_vga_vif.unlock_state === 1'b1);
        wait (board2_vga_vif.unlock_state === 1'b1);

        // Enable zoom after Board 2 receives the UART unlock.
        send_switches(1'b1, 1'b1, 1'b0, 4);
        case (zoom_id)
            1: drive_zoom_button(1'b0, 1'b1, 1'b0); // 01
            2: drive_zoom_button(1'b1, 1'b0, 1'b0); // 10
            3: drive_zoom_button(1'b0, 1'b0, 1'b1); // 11
            default: ;                               // 00
        endcase
        wait ((board2_vga_vif.zoom_en === 1'b1) &&
              (board2_vga_vif.zoom_in === zoom_id[1:0]));
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b0);
        send_camera_frame(16'h001f, 1'b1);
        send_mode(TEST_END);
    endtask
endclass

// AUTH_SUCCESS: inject success, exercise unlocked controls, then inject a timeout.
// Verify UART delivery and relock behavior without waiting for camera authentication.
class Sequence_auth_success extends Sequence;
    `uvm_object_utils(Sequence_auth_success)
    virtual vga_if board1_vga_vif;
    virtual vga_if board2_vga_vif;
    function new(string name="Sequence_auth_success"); super.new(name); endfunction
    task automatic pulse_internal(input string path);
        if (!uvm_hdl_force(path, 1'b1))
            `uvm_fatal("AUTH_INJECT", $sformatf("Cannot force %s", path))
        @(posedge board1_vga_vif.clk);
        #1ns;
        if (!uvm_hdl_force(path, 1'b0))
            `uvm_fatal("AUTH_INJECT", $sformatf("Cannot clear %s", path))
        @(posedge board1_vga_vif.clk);
        #1ns;
        if (!uvm_hdl_release(path))
            `uvm_fatal("AUTH_INJECT", $sformatf("Cannot release %s", path))
        @(posedge board1_vga_vif.clk);
    endtask
    task automatic send_unlocked_button(input logic up, down, left, right);
        transaction tr;
        tr=transaction::type_id::create("post_auth_button_tr");
        start_item(tr);
        tr.mode=BUTTON_PRESS;
        tr.btn_U=up; tr.btn_D=down; tr.btn_L=left; tr.btn_R=right;
        tr.auth_sw=1'b1; tr.zoom_en=1'b1; tr.effect_en=1'b1;
        tr.button_hold_cycles=10_010;
        finish_item(tr);
    endtask
    virtual task body();
        send_mode(TEST_START); send_reset(); repeat (67) send_write();
        // Check for no control packets or Board 2 state changes while locked.
        send_button(1,0,0,0); send_button(0,1,0,0);
        send_button(0,0,1,0); send_button(0,0,0,1);
        send_switches(0,1,0,100); send_switches(0,0,1,100);
        send_switches(0,0,0,100);
        if (board2_vga_vif.unlock_state !== 1'b0 ||
            board2_vga_vif.zoom_en !== 1'b0 ||
            board2_vga_vif.effect_sel !== 1'b0 ||
            board2_vga_vif.zoom_in !== 2'b00)
            `uvm_error("AUTH_PRELOCK", "Board2 control changed while Board1 was locked")
        send_switches(1,0,0,4);
        wait(board1_vga_vif.control_state == 2'd1); // S_AUTH_TRACK
        // Inject authentication success for one rising-edge sample to speed up control/UART checks.
        pulse_internal("tb_top.u_board1.U_CONTROL_UNIT.i_unlock_pass");
        wait(board1_vga_vif.unlock_state === 1'b1);
        wait(board2_vga_vif.unlock_state === 1'b1);
        // Check switch and four-direction button packet fields after authentication.
        send_switches(1,1,0,100);
        wait(board2_vga_vif.zoom_en === 1'b1);
        send_switches(1,1,1,100);
        wait(board2_vga_vif.effect_sel === 1'b1);
        // Check status packet 0x42 for zoom OFF and effect ON.
        send_switches(1,0,1,100);
        wait((board2_vga_vif.zoom_en === 1'b0) &&
             (board2_vga_vif.effect_sel === 1'b1));
        // Check that simultaneous zoom/effect changes produce one combined status packet.
        send_switches(1,0,0,100);
        wait((board2_vga_vif.zoom_en === 1'b0) &&
             (board2_vga_vif.effect_sel === 1'b0));
        send_switches(1,1,1,100);
        wait((board2_vga_vif.zoom_en === 1'b1) &&
             (board2_vga_vif.effect_sel === 1'b1));
        send_unlocked_button(1,0,0,0);
        send_unlocked_button(0,1,0,0);
        send_unlocked_button(0,0,0,1);
        send_unlocked_button(0,0,1,0);
        // Inject timeout completion and 0x80 to test the actual reverse UART and relock path.
        if (!uvm_hdl_force("tb_top.u_board2.U_UART_LINK.data_10s", 8'h80) ||
            !uvm_hdl_force("tb_top.u_board2.U_UART_LINK.done_10s", 1'b1))
            `uvm_fatal("TIMEOUT_INJECT", "Cannot inject Board2 timeout")
        @(posedge board1_vga_vif.clk);
        #1ns;
        void'(uvm_hdl_release("tb_top.u_board2.U_UART_LINK.done_10s"));
        void'(uvm_hdl_release("tb_top.u_board2.U_UART_LINK.data_10s"));
        wait(board1_vga_vif.uart_rx_done &&
             (board1_vga_vif.uart_rx_data == 8'h80));
        wait(board1_vga_vif.unlock_state === 1'b0);
        @(posedge board2_vga_vif.clk iff
          (board2_vga_vif.uart_rx_done && board2_vga_vif.uart_rx_data==8'h00));

        // Repeat button and zoom/effect inputs after remote relock to check blocking.
        // The scoreboard permits one 0x00 status packet, then rejects further traffic.
        send_button(1,0,0,0); send_button(0,1,0,0);
        send_button(0,0,1,0); send_button(0,0,0,1);
        send_switches(1,0,0,100);
        send_switches(1,1,1,100);
        repeat (20) @(posedge board1_vga_vif.clk);
        if (board1_vga_vif.unlock_state !== 1'b0 ||
            board2_vga_vif.unlock_state !== 1'b0 ||
            board2_vga_vif.zoom_en !== 1'b0 ||
            board2_vga_vif.effect_sel !== 1'b0 ||
            board2_vga_vif.button_pulse !== 4'b0000)
            `uvm_error("AUTH_RELOCK_GATE", $sformatf(
                "control escaped relock gate b1_unlock=%0b b2_unlock=%0b zoom=%0b effect=%0b button=%04b",
                board1_vga_vif.unlock_state, board2_vga_vif.unlock_state,
                board2_vga_vif.zoom_en, board2_vga_vif.effect_sel,
                board2_vga_vif.button_pulse))
        send_mode(TEST_END);
    endtask
endclass

// AUTH_LOCKOUT: inject three failures and try controls while the alarm is active.
// Check failure counts and control blocking; this does not wait for lockout expiry.
class Sequence_auth_lockout extends Sequence;
    `uvm_object_utils(Sequence_auth_lockout)
    virtual vga_if board1_vga_vif;
    virtual vga_if board2_vga_vif;
    function new(string name="Sequence_auth_lockout"); super.new(name); endfunction
    task automatic pulse_fail();
        if (!uvm_hdl_force("tb_top.u_board1.U_CONTROL_UNIT.i_unlock_fail", 1'b1))
            `uvm_fatal("AUTH_INJECT", "Cannot force unlock_fail")
        @(posedge board1_vga_vif.clk);
        #1ns;
        if (!uvm_hdl_force("tb_top.u_board1.U_CONTROL_UNIT.i_unlock_fail", 1'b0))
            `uvm_fatal("AUTH_INJECT", "Cannot clear unlock_fail")
        @(posedge board1_vga_vif.clk);
        #1ns;
        void'(uvm_hdl_release("tb_top.u_board1.U_CONTROL_UNIT.i_unlock_fail"));
        `uvm_info("AUTH_INJECT", $sformatf(
            "failure pulse sampled: state=%0d fail_count=%0d alarm=%0b",
            board1_vga_vif.control_state, board1_vga_vif.fail_count,
            board1_vga_vif.alarm), UVM_LOW)
    endtask
    virtual task body();
        send_mode(TEST_START); send_reset(); repeat (67) send_write();
        send_switches(1,0,0,4);
        wait(board1_vga_vif.control_state == 2'd1); // S_AUTH_TRACK
        // Inject three authentication failures without camera frames.
        pulse_fail();
        if (board1_vga_vif.fail_count != 1)
            `uvm_fatal("AUTH_LOCKOUT", $sformatf(
                "After failure 1 expected count=1, got %0d",
                board1_vga_vif.fail_count))
        pulse_fail();
        if (board1_vga_vif.fail_count != 2)
            `uvm_fatal("AUTH_LOCKOUT", $sformatf(
                "After failure 2 expected count=2, got %0d",
                board1_vga_vif.fail_count))
        pulse_fail();
        if ((board1_vga_vif.fail_count != 3) || !board1_vga_vif.alarm)
            `uvm_fatal("AUTH_LOCKOUT", $sformatf(
                "After failure 3 expected count=3/alarm=1, got %0d/%0b",
                board1_vga_vif.fail_count, board1_vga_vif.alarm))
        // Check that a new authentication request cannot escape LOCKOUT.
        send_switches(0,0,0,20);
        send_switches(1,0,0,20);
        // Check that LOCKOUT blocks all button and switch controls.
        send_button(1,0,0,0); send_button(0,1,0,0);
        send_button(0,0,1,0); send_button(0,0,0,1);
        send_switches(1,1,0,100);
        send_switches(1,0,1,100);
        send_switches(1,1,1,100);
        repeat (10) @(posedge board1_vga_vif.clk);
        if (!board1_vga_vif.alarm || board1_vga_vif.unlock_state ||
            board2_vga_vif.unlock_state || board2_vga_vif.zoom_en ||
            board2_vga_vif.effect_sel ||
            (board2_vga_vif.button_pulse !== 4'b0000))
            `uvm_error("AUTH_LOCKOUT", $sformatf(
                "control escaped lockout alarm=%0b b1_unlock=%0b b2_unlock=%0b zoom=%0b effect=%0b button=%04b",
                board1_vga_vif.alarm, board1_vga_vif.unlock_state,
                board2_vga_vif.unlock_state, board2_vga_vif.zoom_en,
                board2_vga_vif.effect_sel, board2_vga_vif.button_pulse))
        send_mode(TEST_END);
    endtask
endclass


class Sequence_reset extends Sequence;
    `uvm_object_utils(Sequence_reset)

    function new(string name = "Sequence_reset");
        super.new(name);
    endfunction

    virtual task body();
        send_mode(TEST_START);
        send_reset();
        send_mode(TEST_END);
    endtask
endclass


class Sequence_write extends Sequence;
    `uvm_object_utils(Sequence_write)

    function new(string name = "Sequence_write");
        super.new(name);
    endfunction

    virtual task body();
        send_mode(TEST_START);
        send_reset();
        repeat (67)
            send_write();
        send_mode(TEST_END);
    endtask
endclass


class Sequence_read extends Sequence;
    `uvm_object_utils(Sequence_read)

    function new(string name = "Sequence_read");
        super.new(name);
    endfunction

    virtual task body();
        logic [7:0] read_data;

        send_mode(TEST_START);
        send_reset();
        repeat (67) begin
            if (!std::randomize(read_data))
                `uvm_fatal("SEQ", "Failed to randomize SCCB read data")
            send_read(read_data);
        end
        send_mode(TEST_END);
    endtask
endclass
