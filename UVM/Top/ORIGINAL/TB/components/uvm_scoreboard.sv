// Check SCCB setup and camera frame counts for each board.
// Board 2 also compares read addresses/data or internal blur pixels by test mode.
class Scoreboard extends uvm_scoreboard;
    `uvm_component_utils(Scoreboard)

    uvm_analysis_imp #(transaction, Scoreboard) recv;
    int unsigned total_count;
    int unsigned pass_count;
    int unsigned fail_count;
    int unsigned camera_frame_count;
    int expected_camera_frames = 3;
    virtual vga_if vga_vif;
    bit check_video;
    logic [11:0] photo_rgb444 [0:320*240-1];
    logic [11:0] gaussian_rgb444 [0:640*480-1];
    string test_mode;
    int zoom_id;
    logic [15:0] sccb_reference [0:66];
    logic [7:0] observed_register_map [0:255];
    logic [7:0] expected_register_map [0:255];
    string internal_sccb_path;
    string board_name;
    int unsigned internal_sccb_count;
    int unsigned internal_sccb_fail_count;
    bit internal_sccb_path_error;

    localparam int GAUSSIAN_LATENCY = 12_020;
    logic [9:0] gaussian_x_delay [0:GAUSSIAN_LATENCY-1];
    logic [9:0] gaussian_y_delay [0:GAUSSIAN_LATENCY-1];
    logic       gaussian_de_delay[0:GAUSSIAN_LATENCY-1];

    function new(string name = "Scoreboard", uvm_component parent = null);
        super.new(name, parent);
        recv = new("recv", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(bit)::get(this, "", "check_video", check_video));
        if (!uvm_config_db#(string)::get(this, "", "board_name", board_name))
            board_name = get_full_name();
        if (!uvm_config_db#(string)::get(this, "", "internal_sccb_path",
                                         internal_sccb_path))
            `uvm_fatal("SCB_HDL", $sformatf(
                "%s internal SCCB hierarchy path is not configured", board_name))
        $readmemh("../TB/ref/ov7670_67.hex", sccb_reference);
        foreach (observed_register_map[i]) begin
            observed_register_map[i] = 'x;
            expected_register_map[i] = 'x;
        end
        foreach (sccb_reference[i])
            expected_register_map[sccb_reference[i][15:8]] = sccb_reference[i][7:0];
        void'(uvm_config_db#(int)::get(this, "", "expected_camera_frames",
                                      expected_camera_frames));
        if (check_video) begin
            if (!uvm_config_db#(virtual vga_if)::get(this, "", "vga_vif", vga_vif))
                `uvm_fatal("SCB", "Unable to get VGA interface")
            $readmemh("../TB/image_hex/photo_input.hex", photo_rgb444);
            $readmemh("../TB/image_hex/gaussian_rtl_golden.hex", gaussian_rgb444);
            if (!uvm_config_db#(string)::get(this, "", "test_mode", test_mode))
                test_mode = "NORMAL";
            void'(uvm_config_db#(int)::get(this, "", "zoom_id", zoom_id));
        end
    endfunction

    // Cross-check the internal SCCB LUT against 67 reference entries and bus observations.
    function automatic void check_internal_sccb(transaction tr,
                                                 int unsigned expected_idx);
        uvm_hdl_data_t idx_value;
        uvm_hdl_data_t dev_value;
        uvm_hdl_data_t reg_value;
        uvm_hdl_data_t data_value;
        int unsigned idx;
        bit read_ok;
        bit pass;

        read_ok = uvm_hdl_read({internal_sccb_path, ".config_idx"}, idx_value);
        read_ok &= uvm_hdl_read({internal_sccb_path, ".dev_addr"}, dev_value);
        read_ok &= uvm_hdl_read({internal_sccb_path, ".reg_addr"}, reg_value);
        read_ok &= uvm_hdl_read({internal_sccb_path, ".reg_data"}, data_value);
        if (!read_ok) begin
            if (!internal_sccb_path_error)
                `uvm_error("SCB_HDL", $sformatf(
                    "%s uvm_hdl_read failed at path %s",
                    board_name, internal_sccb_path))
            internal_sccb_path_error = 1'b1;
            internal_sccb_fail_count++;
            return;
        end

        idx = int'(idx_value);
        internal_sccb_count++;
        pass = (idx == expected_idx) && (idx < 67) &&
               (dev_value[7:0] === 8'h42) &&
               ({reg_value[7:0], data_value[7:0]} === sccb_reference[idx]) &&
               (reg_value[7:0] === tr.sccb_register_addr) &&
               (data_value[7:0] === tr.sccb_write_data);

        if (pass) begin
            `uvm_info("SCB_HDL", $sformatf(
                "%s INTERNAL SCCB PASS idx=%0d dev=0x%02h reg=0x%02h data=0x%02h",
                board_name, idx, dev_value[7:0], reg_value[7:0],
                data_value[7:0]), UVM_LOW)
        end else begin
            internal_sccb_fail_count++;
            `uvm_error("SCB_HDL", $sformatf(
                "%s INTERNAL SCCB FAIL expected_idx=%0d actual_idx=%0d internal=%02h/%02h/%02h bus=%02h/%02h ref=%04h",
                board_name, expected_idx, idx, dev_value[7:0],
                reg_value[7:0], data_value[7:0], tr.sccb_register_addr,
                tr.sccb_write_data, (idx < 67) ? sccb_reference[idx] : 16'hxxxx))
        end
    endfunction

    function automatic logic [15:0] rgb444_to_rgb565(input logic [11:0] rgb444);
        return {rgb444[11:8], rgb444[11],
                rgb444[7:4],  rgb444[7:6],
                rgb444[3:0],  rgb444[3]};
    endfunction

    task automatic check_vga_frames();
        int unsigned frame_no = 0;
        int unsigned mismatch;
        int unsigned expected_addr;
        int unsigned x_src;
        int unsigned y_src;
        bit in_active = 0;
        bit frame_reported = 0;
        logic [9:0] compare_x;
        logic [9:0] compare_y;
        logic       compare_de;
        int unsigned gaussian_delay_ptr = 0;
        int unsigned gaussian_delay_fill = 0;

        forever begin
            @(posedge vga_vif.clk);

            // In ZOOM mode, wait for Board 2 unlock, zoom enable, and the expected region.
            if ((test_mode == "ZOOM") &&
                ((vga_vif.unlock_state !== 1'b1) ||
                 (vga_vif.zoom_en !== 1'b1) ||
                 (vga_vif.zoom_in !== zoom_id[1:0])))
                continue;

            if (!vga_vif.pixel_tick)
                continue;
            if (test_mode == "GAUSSIAN") begin
                compare_x  = gaussian_x_delay[gaussian_delay_ptr];
                compare_y  = gaussian_y_delay[gaussian_delay_ptr];
                compare_de = gaussian_de_delay[gaussian_delay_ptr];

                gaussian_x_delay[gaussian_delay_ptr]  = vga_vif.x_pixel;
                gaussian_y_delay[gaussian_delay_ptr]  = vga_vif.y_pixel;
                gaussian_de_delay[gaussian_delay_ptr] = vga_vif.de;
                gaussian_delay_ptr = (gaussian_delay_ptr == GAUSSIAN_LATENCY-1) ?
                                     0 : gaussian_delay_ptr + 1;

                if (gaussian_delay_fill < GAUSSIAN_LATENCY) begin
                    gaussian_delay_fill++;
                    compare_de = 1'b0;
                end
            end else begin
                compare_x  = vga_vif.x_pixel;
                compare_y  = vga_vif.y_pixel;
                compare_de = vga_vif.de;
            end

            if (compare_de && !in_active &&
                (compare_x == 0) && (compare_y == 0)) begin
                frame_no++;
                mismatch = 0;
                in_active = 1;
                frame_reported = 0;
            end
            if (!compare_de)
                in_active = 0;

            // NORMAL and ZOOM compare frame-buffer reads with the input photo.
            // This checks source addressing and data, not final VGA output pins.
            if (compare_de && (frame_no == 3) && (test_mode == "NORMAL")) begin
                x_src = compare_x >> 1;
                y_src = compare_y >> 1;
                expected_addr = y_src * 320 + x_src;
                if (vga_vif.source_addr !== expected_addr[16:0])
                    mismatch++;
                if (vga_vif.source_data !== rgb444_to_rgb565(photo_rgb444[expected_addr]))
                    mismatch++;
            end else if (compare_de && (frame_no == 3) &&
                         (test_mode == "ZOOM")) begin
                x_src = (compare_x >> 2) + (zoom_id[0] * 160);
                y_src = (compare_y >> 2) + (zoom_id[1] * 120);
                expected_addr = y_src * 320 + x_src;
                if (vga_vif.source_addr !== expected_addr[16:0])
                    mismatch++;
                if (vga_vif.source_data !== rgb444_to_rgb565(photo_rgb444[expected_addr]))
                    mismatch++;
            end else if (compare_de && (frame_no == 3) &&
                         (test_mode == "GAUSSIAN") &&
                         (compare_y >= 20)) begin
                // Compare internal blur output on frame 3, excluding the top 20 lines.
                expected_addr = compare_y * 640 + compare_x;
                if (vga_vif.gaussian_rgb !== gaussian_rgb444[expected_addr])
                    mismatch++;
            end

            if (!frame_reported && (frame_no == 3) &&
                (compare_x == 639) && (compare_y == 479)) begin
                frame_reported = 1;
                if (mismatch == 0)
                    `uvm_info("VGA_SCB", $sformatf(
                        "VGA frame %0d image comparison PASS", frame_no), UVM_LOW)
                else
                    `uvm_error("VGA_SCB", $sformatf(
                        "VGA frame %0d pixel mismatch=%0d", frame_no, mismatch))
            end
        end
    endtask

    virtual task run_phase(uvm_phase phase);
        if (check_video)
            check_vga_frames();
    endtask

    virtual function void write(transaction tr);
        bit pass;

        if (tr.mode == BUTTON_PRESS) begin
            if (tr.transaction_done &&
                $onehot({tr.btn_U, tr.btn_D, tr.btn_L, tr.btn_R})) begin
                `uvm_info("SCB", $sformatf(
                    "BUTTON PASS U=%0b D=%0b L=%0b R=%0b",
                    tr.btn_U, tr.btn_D, tr.btn_L, tr.btn_R), UVM_LOW)
            end else begin
                `uvm_error("SCB", "Invalid button transaction")
            end
            return;
        end

        if (tr.mode == SWITCH_SET) begin
            if (tr.transaction_done &&
                !$isunknown({tr.auth_sw, tr.zoom_en, tr.effect_en})) begin
                `uvm_info("SCB", $sformatf(
                    "SWITCH PASS auth=%0b zoom=%0b effect=%0b",
                    tr.auth_sw, tr.zoom_en, tr.effect_en), UVM_LOW)
            end else begin
                `uvm_error("SCB", "Invalid switch transaction")
            end
            return;
        end

        if (tr.mode == UART_TX) begin
            if (tr.transaction_done && tr.uart_tx_valid &&
                !$isunknown(tr.uart_tx_data)) begin
                `uvm_info("SCB", $sformatf(
                    "UART TX OBSERVED data=0x%02h", tr.uart_tx_data), UVM_LOW)
            end else begin
                `uvm_error("SCB", "Invalid UART TX transaction")
            end
            return;
        end

        if (tr.mode == CAMERA_FRAME) begin
            if (tr.transaction_done && tr.camera_frame_valid &&
                (tr.camera_pixel_count == 320 * 240)) begin
                camera_frame_count++;
                `uvm_info("SCB", $sformatf(
                    "CAMERA FRAME %0d/%0d PASS pixels=%0d",
                    camera_frame_count, expected_camera_frames,
                    tr.camera_pixel_count), UVM_LOW)
            end else begin
                `uvm_error("SCB", $sformatf(
                    "CAMERA FRAME FAIL pixels=%0d valid=%0b",
                    tr.camera_pixel_count, tr.camera_frame_valid))
            end
            return;
        end

        total_count++;
        check_internal_sccb(tr, total_count - 1);
        pass = tr.transaction_done && (total_count <= 67) &&
               (tr.mode == SCCB_WRITE) && (tr.sccb_device_addr == 8'h42) &&
               !tr.sccb_is_read && !tr.sccb_ack_error &&
               ({tr.sccb_register_addr,tr.sccb_write_data} === sccb_reference[total_count-1]);
        observed_register_map[tr.sccb_register_addr] = tr.sccb_write_data;

        if (pass) begin pass_count++;
            `uvm_info("SCB", $sformatf( "SCCB WRITE PASS addr=0x%02h reg=0x%02h data=0x%02h",
                tr.sccb_device_addr, tr.sccb_register_addr, tr.sccb_write_data), UVM_LOW) 
		end else begin fail_count++;
            `uvm_error("SCB", $sformatf( "SCCB WRITE FAIL addr=0x%02h reg=0x%02h data=0x%02h ack_error=%0b",
                tr.sccb_device_addr, tr.sccb_register_addr, tr.sccb_write_data, tr.sccb_ack_error)) 
		end
    endfunction

    // Require all 67 setup writes, the final register map, and expected input frames.
    // These totals catch incomplete stimulus even when individual transfers pass.
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT", $sformatf( "TOTAL=%0d PASS=%0d FAIL=%0d",
            total_count, pass_count, fail_count), UVM_LOW)
        `uvm_info("SCB_HDL_REPORT", $sformatf(
            "%s INTERNAL_TOTAL=%0d INTERNAL_FAIL=%0d PATH=%s",
            board_name, internal_sccb_count, internal_sccb_fail_count,
            internal_sccb_path), UVM_LOW)
        if ((internal_sccb_count != 67) || (internal_sccb_fail_count != 0))
            `uvm_error("SCB_HDL_REPORT", $sformatf(
                "%s expected 67 successful internal SCCB checks, got total=%0d fail=%0d",
                board_name, internal_sccb_count, internal_sccb_fail_count))
        if ((total_count != 67) || (fail_count != 0)) begin 
			`uvm_error("SCB_REPORT", $sformatf( "Expected 67 successful OV7670 configuration writes, got total=%0d fail=%0d",
                total_count, fail_count))
        end
        foreach (expected_register_map[i]) begin
            if (!$isunknown(expected_register_map[i]) &&
                (observed_register_map[i] !== expected_register_map[i]))
                `uvm_error("SCB_REGISTER_MAP", $sformatf(
                    "Final register 0x%02h expected=0x%02h actual=0x%02h",
                    i, expected_register_map[i], observed_register_map[i]))
        end
        if (camera_frame_count != expected_camera_frames) begin
            `uvm_error("SCB_REPORT", $sformatf(
                "Expected %0d valid camera input frames, got %0d",
                expected_camera_frames, camera_frame_count))
        end
    endfunction
endclass
