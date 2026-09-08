// Select and run sequences and checks for each test mode.
class Dut_test extends uvm_test;
    `uvm_component_utils(Dut_test)
    Sequence board1_seq;
    Sequence board2_seq;
    Environment env;
    virtual vga_if board1_vga_vif;
    virtual vga_if board2_vga_vif;
    virtual uart_if board2_uart_vif;
    string test_mode;
    int zoom_id;
    function new(string name = "Dut_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = Environment::type_id::create("env", this);

        if (!uvm_config_db#(virtual vga_if)::get(
                this, "", "board1_vga_vif", board1_vga_vif)) begin
            `uvm_fatal("TEST", "Unable to get board1_vga_vif")
        end
        if (!uvm_config_db#(virtual vga_if)::get(
                this, "", "board2_vga_vif", board2_vga_vif)) begin
            `uvm_fatal("TEST", "Unable to get board2_vga_vif")
        end
        if (!uvm_config_db#(virtual uart_if)::get(
                this, "", "board2_uart_vif", board2_uart_vif)) begin
            `uvm_fatal("TEST", "Unable to get board2_uart_vif")
        end
        if (!$value$plusargs("TEST_MODE=%s", test_mode))
            test_mode = "NORMAL";
        uvm_config_db#(string)::set(this,"env","test_mode",test_mode);
        uvm_config_db#(string)::set(this,"env.auth_scb","test_mode",test_mode);
        uvm_config_db#(string)::set(this,"env.auth_cov","test_mode",test_mode);
        uvm_config_db#(string)::set(this,"env.board1_cov","test_mode",test_mode);
        uvm_config_db#(string)::set(this,"env.board2_cov","test_mode",test_mode);
        uvm_config_db#(virtual vga_if)::set(this,"env.auth_scb","board1_vif",board1_vga_vif);
        uvm_config_db#(virtual vga_if)::set(this,"env.auth_scb","board2_vif",board2_vga_vif);
        uvm_config_db#(virtual vga_if)::set(this,"env.auth_cov","board1_vif",board1_vga_vif);
        uvm_config_db#(virtual vga_if)::set(this,"env.auth_cov","board2_vif",board2_vga_vif);
        // Choose one of four zoom regions per run and share it with the scoreboard.
        zoom_id = $urandom_range(3, 0);
        if (test_mode == "AUTH_SUCCESS") begin
            Sequence_auth_success s;
            s = Sequence_auth_success::type_id::create("auth_success_seq");
            s.board1_vga_vif=board1_vga_vif; s.board2_vga_vif=board2_vga_vif;
            board1_seq=s;
        end else if (test_mode == "AUTH_LOCKOUT") begin
            Sequence_auth_lockout s;
            s = Sequence_auth_lockout::type_id::create("auth_lockout_seq");
            s.board1_vga_vif=board1_vga_vif;
            s.board2_vga_vif=board2_vga_vif;
            board1_seq=s;
        end else if (test_mode == "ZOOM") begin
            Sequence_write_zoom zoom_seq;
            zoom_seq = Sequence_write_zoom::type_id::create("board1_zoom_seq");
            zoom_seq.zoom_id = zoom_id;
            zoom_seq.board1_vga_vif = board1_vga_vif;
            zoom_seq.board2_vga_vif = board2_vga_vif;
            board1_seq = zoom_seq;
        end else begin
            board1_seq = Sequence_write_buttons::type_id::create("board1_seq");
        end
        if ((test_mode == "AUTH_SUCCESS") || (test_mode == "AUTH_LOCKOUT"))
            board2_seq = Sequence_write::type_id::create("board2_seq");
        else
            board2_seq = Sequence_write_camera::type_id::create("board2_seq");
        uvm_config_db#(string)::set(this, "env.board2_scb", "test_mode", test_mode);
        uvm_config_db#(int)::set(this, "env.board2_scb", "zoom_id", zoom_id);
        uvm_config_db#(string)::set(this, "env.board1_scb", "board_name", "BOARD1");
        uvm_config_db#(string)::set(this, "env.board2_scb", "board_name", "BOARD2");
        uvm_config_db#(string)::set(this, "env.board1_scb", "internal_sccb_path",
            "tb_top.u_board1.U_CAMERA_FRONTEND.U_SCCB_SETUP_CNTL.U_OV7670_SETUP_CNTL");
        uvm_config_db#(string)::set(this, "env.board2_scb", "internal_sccb_path",
            "tb_top.u_board2.U_VIDEO_PATH.U_VGA_CAM.U_SCCB_SETUP_CNTL.U_OV7670_SETUP_CNTL");
        uvm_config_db#(string)::set(this, "env.board1_cov", "internal_sccb_path",
            "tb_top.u_board1.U_CAMERA_FRONTEND.U_SCCB_SETUP_CNTL.U_OV7670_SETUP_CNTL");
        uvm_config_db#(string)::set(this, "env.board2_cov", "internal_sccb_path",
            "tb_top.u_board2.U_VIDEO_PATH.U_VGA_CAM.U_SCCB_SETUP_CNTL.U_OV7670_SETUP_CNTL");
        uvm_config_db#(int)::set(this, "env.board1_scb", "expected_camera_frames",
                                 (test_mode == "ZOOM") ? 10 :
                                 ((test_mode == "AUTH_SUCCESS") ||
                                  (test_mode == "AUTH_LOCKOUT")) ? 0 : 3);
        uvm_config_db#(int)::set(this, "env.board2_scb", "expected_camera_frames",
                                 ((test_mode == "AUTH_SUCCESS") ||
                                  (test_mode == "AUTH_LOCKOUT")) ? 0 : 3);
    endfunction
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info("TEST", "Dut_test raise_objection", UVM_HIGH)
        wait (board2_vga_vif.rst_n === 1'b1);
        @(posedge board2_vga_vif.clk);
        // Run both board sequences alongside the mode-specific completion wait.
        // Keep the objection until all branches finish, including post-unlock checks.
        fork
            board1_seq.start(env.board1_agent.sqr);
            board2_seq.start(env.board2_agent.sqr);
            begin
                case (test_mode)
                    "AUTH_SUCCESS": begin
                        wait(board2_vga_vif.unlock_state === 1'b1);
                        `uvm_info("TEST", "Authentication and UART unlock PASS", UVM_LOW)
                    end
                    "AUTH_LOCKOUT": begin
                        wait(board1_vga_vif.alarm === 1'b1);
                        if (board2_vga_vif.unlock_state !== 1'b0)
                            `uvm_error("TEST", "Unlock propagated during failed authentication")
                    end
                    "NORMAL", "GAUSSIAN": ;
                    "ZOOM": begin
                        `uvm_info("TEST", $sformatf(
                            "Random zoom selection id=%0d (%0b,%0b)",
                            zoom_id, zoom_id[1], zoom_id[0]), UVM_LOW)
                        wait ((board2_vga_vif.unlock_state === 1'b1) &&
                              (board2_vga_vif.zoom_en === 1'b1) &&
                              (board2_vga_vif.zoom_in === zoom_id[1:0]));
                    end
                    default: `uvm_fatal("TEST", $sformatf(
                        "Unknown TEST_MODE=%s", test_mode))
                endcase
                if ((test_mode != "AUTH_SUCCESS") &&
                    (test_mode != "AUTH_LOCKOUT"))
                    repeat (3) @(negedge board2_vga_vif.v_sync);
                if (test_mode == "GAUSSIAN")
                    #1ms;
            end
        join
        `uvm_info("TEST", $sformatf(
            "%s functional completion condition reached", test_mode), UVM_LOW)

        phase.drop_objection(this);
        `uvm_info("TEST", "Dut_test drop_objection", UVM_HIGH)
    endtask

	function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

	function void report_phase(uvm_phase phase);
		super.report_phase(phase);
	endfunction
endclass
