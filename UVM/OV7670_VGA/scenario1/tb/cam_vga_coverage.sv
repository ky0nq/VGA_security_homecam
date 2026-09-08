class cam_vga_coverage extends uvm_subscriber #(cam_vga_seq_item);
    `uvm_component_utils(cam_vga_coverage)
    virtual cam_vga_if vif;

    bit previous_href, previous_vsync, byte_phase;
    bit frame_started, line_started, reset_seen;
    bit waiting_for_reset_recovery;
    bit waiting_for_vga_reset_recovery;
    int reset_location;
    int unsigned reset_asserted_hits[4], reset_recovered_hits[4];
    int unsigned line_bytes, frame_lines;
    bit previous_hsync = 1, previous_vga_vsync = 1;
    int unsigned hsync_low_pixels, vsync_low_pixels;
    int unsigned line_period_pixels, frame_period_pixels;
    bit seen_line_start, seen_frame_start;
    longint unsigned observed_writes, observed_memory_loads, observed_vga_pixels;

    // CAM-02/03/05: sample actual writes, including the delayed last write
    // after HREF falls.  A randomized sequence that never reaches the DUT
    covergroup camera_write_cg with function sample(
        int pattern_id, bit [16:0] addr, bit [15:0] pixel);
        option.per_instance = 1;
        cp_pattern: coverpoint pattern_id {
            bins bars = {COLOR_BARS};
            bins horizontal_gradient = {H_GRADIENT};
            bins vertical_gradient = {V_GRADIENT};
            bins checkerboard = {CHECKERBOARD};
            bins random_pixels = {RANDOM_PIXELS};
            bins quadrants = {QUADRANTS};
            bins channel_walk = {CHANNEL_WALK};
        }
        cp_color: coverpoint pixel {
            bins black = {16'h0000}; bins white = {16'hffff};
            bins red = {16'hf800}; bins green = {16'h07e0};
            bins blue = {16'h001f}; bins yellow = {16'hffe0};
            bins magenta = {16'hf81f}; bins cyan = {16'h07ff};
            bins other = default;
        }
        cp_red: coverpoint pixel[15:11] {
            bins low = {[0:10]}; bins middle = {[11:20]};
            bins high = {[21:31]};
        }
        cp_green: coverpoint pixel[10:5] {
            bins low = {[0:21]}; bins middle = {[22:42]};
            bins high = {[43:63]};
        }
        cp_blue: coverpoint pixel[4:0] {
            bins low = {[0:10]}; bins middle = {[11:20]};
            bins high = {[21:31]};
        }
        cp_address: coverpoint addr {
            bins first = {0}; bins second = {1};
            bins end_first_row = {319}; bins start_second_row = {320};
            bins penultimate = {76798}; bins last = {76799};
            bins interior = {[2:318], [321:76797]};
        }
        // 27 useful brightness combinations, all reachable with random RGB565.
        rgb_levels: cross cp_red, cp_green, cp_blue;
    endgroup

    // VGA-only tests preload RAM directly.  
    covergroup memory_load_cg with function sample(
        int pattern_id, bit [16:0] addr, bit [15:0] pixel);
        option.per_instance = 1;
        cp_pattern: coverpoint pattern_id {
            bins bars = {COLOR_BARS};
            bins horizontal_gradient = {H_GRADIENT};
            bins vertical_gradient = {V_GRADIENT};
            bins checkerboard = {CHECKERBOARD};
            bins random_pixels = {RANDOM_PIXELS};
            bins quadrants = {QUADRANTS};
            bins channel_walk = {CHANNEL_WALK};
        }
        cp_red: coverpoint pixel[15:11] {
            bins low = {[0:10]}; bins middle = {[11:20]};
            bins high = {[21:31]};
        }
        cp_green: coverpoint pixel[10:5] {
            bins low = {[0:21]}; bins middle = {[22:42]};
            bins high = {[43:63]};
        }
        cp_blue: coverpoint pixel[4:0] {
            bins low = {[0:10]}; bins middle = {[11:20]};
            bins high = {[21:31]};
        }
        cp_address: coverpoint addr {
            bins first = {0}; bins second = {1};
            bins end_first_row = {319}; bins start_second_row = {320};
            bins penultimate = {76798}; bins last = {76799};
            bins interior = {[2:318], [321:76797]};
        }
        rgb_levels: cross cp_red, cp_green, cp_blue;
    endgroup

    // CAM-04/06: derive protocol events from camera pins, not command tags.
    // event_id: 0 new frame, 1 line start, 2 complete line end,
    //           3 partial byte discarded by HREF, 4 discarded by VSYNC.
    covergroup camera_event_cg with function sample(int event_id);
        option.per_instance = 1;
        cp_event: coverpoint event_id {
            bins frame_start = {0}; bins line_start = {1};
            bins complete_line_end = {2};
            bins partial_href = {3}; bins partial_vsync = {4};
        }
    endgroup

    covergroup camera_line_cg with function sample(int pixels, bit partial);
        option.per_instance = 1;
        cp_length: coverpoint pixels {
            bins short_line = {[0:318]}; bins just_short = {319};
            bins nominal = {320}; bins just_long = {321};
            ignore_bins outside_plan = {[322:32'h7fffffff]};
        }
        cp_partial: coverpoint partial { bins no = {0}; bins yes = {1}; }
        length_x_partial: cross cp_length, cp_partial {
            ignore_bins unplanned_long_partial =
                (binsof(cp_length.just_short) || binsof(cp_length.nominal) ||
                 binsof(cp_length.just_long)) && binsof(cp_partial.yes);
            ignore_bins unplanned_short_complete =
                binsof(cp_length.short_line) && binsof(cp_partial.no);
        }
    endgroup

    // A frame is counted only when its NEXT VSYNC is observed.
    covergroup camera_frame_cg with function sample(int lines);
        option.per_instance = 1;
        cp_lines: coverpoint lines {
            bins interrupted_frame = {[0:238]};
            bins nominal = {240};
        }
    endgroup

    covergroup vga_reset_cg with function sample(bit recovered);
        option.per_instance = 1;
        cp_recovery: coverpoint recovered {
            bins asserted = {0}; bins pixel_observation_resumed = {1};
        }
    endgroup
    
    // Camera phase is sampled at actual writes; VGA phase at frame boundaries.
    covergroup camera_phase_cg with function sample(int phase_bucket);
        option.per_instance = 1;
        cp_phase: coverpoint phase_bucket {
            bins phase_0ns = {0}; bins phase_5ns = {1};
            bins phase_7ns = {2}; bins other_phase = {3};
        }
    endgroup

    covergroup vga_phase_cg with function sample(int phase_bucket);
        option.per_instance = 1;
        cp_phase: coverpoint phase_bucket {
            bins phase_0ns = {0}; bins phase_5ns = {1};
            bins phase_7ns = {2}; bins other_phase = {3};
        }
    endgroup

    // The recovery event means a subsequent actual camera write was observed.
    covergroup reset_cg with function sample(int location, bit recovered);
        option.per_instance = 1;
        cp_location: coverpoint location {
            bins idle = {0}; bins active_line = {1};
            bins between_lines = {2}; bins partial_pixel = {3};
        }
        cp_recovery: coverpoint recovered {
            bins asserted = {0}; bins camera_write_resumed = {1};
        }
        location_x_recovery: cross cp_location, cp_recovery;
    endgroup

    // VGA-01/02/05: coordinates and zones are observed once per pixel
    // period by the monitor's independent cadence.
    covergroup vga_geometry_cg with function sample(
        int xpos, int ypos, bit visible, int hregion, int vregion);
        option.per_instance = 1;
        cp_horizontal: coverpoint hregion {
            bins visible = {0}; bins front_porch = {1};
            bins sync = {2}; bins back_porch = {3};
        }
        cp_vertical: coverpoint vregion {
            bins visible = {0}; bins front_porch = {1};
            bins sync = {2}; bins back_porch = {3};
        }
        horizontal_x_vertical: cross cp_horizontal, cp_vertical;
        cp_x_boundary: coverpoint xpos {
            bins edges[] = {0, 1, 638, 639, 640, 655, 656, 751, 752, 799};
        }
        cp_y_boundary: coverpoint ypos {
            bins edges[] = {0, 1, 478, 479, 480, 489, 490, 491, 492, 524};
        }
        cp_x_parity: coverpoint (xpos % 2) iff (visible) {
            bins even = {0}; bins odd = {1};
        }
        cp_y_parity: coverpoint (ypos % 2) iff (visible) {
            bins even = {0}; bins odd = {1};
        }
        upscale_2x2: cross cp_x_parity, cp_y_parity;
    endgroup

    // Widths are measured by counting complete observed pixel samples.
    // kind: 0 HSYNC low, 1 VSYNC low, 2 line period, 3 frame period.
    covergroup vga_timing_cg with function sample(int kind, int pixels);
        option.per_instance = 1;
        cp_hsync_width: coverpoint pixels iff (kind == 0) {
            bins correct = {96};
        }
        cp_vsync_width: coverpoint pixels iff (kind == 1) {
            bins two_lines = {1600};
        }
        cp_line_period: coverpoint pixels iff (kind == 2) {
            bins correct = {800};
        }
        cp_frame_period: coverpoint pixels iff (kind == 3) {
            bins correct = {420000};
        }
    endgroup

    // VGA-03: bins show which retained source/output nibble pairs were
    // observed on the real read-data/RGB path.  Golden pixels are owned by
    // the independent scoreboard.  Incorrect pairs do not fill match bins.
    covergroup rgb_mapping_cg with function sample(
        int channel, bit [3:0] source_nibble, bit [3:0] output_nibble);
        option.per_instance = 1;
        cp_channel: coverpoint channel {
            bins red = {0}; bins green = {1}; bins blue = {2};
        }
        cp_pair: coverpoint {source_nibble, output_nibble} {
            bins retained[] = {8'h00, 8'h11, 8'h22, 8'h33,
                               8'h44, 8'h55, 8'h66, 8'h77,
                               8'h88, 8'h99, 8'haa, 8'hbb,
                               8'hcc, 8'hdd, 8'hee, 8'hff};
        }
        channel_x_retained_value: cross cp_channel, cp_pair;
    endgroup

    // VGA-04: sample the native fixed 2x output path only.
    covergroup vga_address_cg with function sample(bit [16:0] addr);
        option.per_instance = 1;
        cp_read_address: coverpoint addr {
            bins first = {0}; bins second = {1};
            bins row_end = {319}; bins next_row = {320};
            bins penultimate = {76798}; bins last = {76799};
            bins interior = {[2:318], [321:76797]};
        }
    endgroup

    covergroup vga_corner_cg with function sample(int corner);
        option.per_instance = 1;
        cp_corner: coverpoint corner {
            bins top_left = {0}; bins top_right = {1};
            bins bottom_left = {2}; bins bottom_right = {3};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        camera_write_cg = new(); camera_event_cg = new();
        camera_line_cg = new(); camera_frame_cg = new(); reset_cg = new();
        memory_load_cg = new(); vga_reset_cg = new();
        camera_phase_cg = new(); vga_phase_cg = new();
        vga_geometry_cg = new(); vga_timing_cg = new();
        rgb_mapping_cg = new(); vga_address_cg = new();
        vga_corner_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_vga_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "Coverage requires cam_vga_if")
    endfunction

    function int current_phase_bucket();
        case (vif.camera_phase_ns)
            0: return 0;
            5: return 1;
            7: return 2;
            default: return 3;
        endcase
    endfunction

    function void observe_reset();
        if (!reset_seen) begin
            if (byte_phase) reset_location = 3;
            else if (previous_href) reset_location = 1;
            else if (frame_started) reset_location = 2;
            else reset_location = 0;
            if (vif.check_camera) begin
                reset_asserted_hits[reset_location]++;
                `uvm_info("RESET_OBS", $sformatf(
                    "t=%0t location=%0d previous_href=%0b byte_phase=%0b frame_started=%0b line_bytes=%0d asserted",
                    $time, reset_location, previous_href, byte_phase, frame_started, line_bytes), UVM_LOW)
                reset_cg.sample(reset_location, 0);
                waiting_for_reset_recovery = 1;
            end
            if (vif.check_vga) begin
                vga_reset_cg.sample(0);
                waiting_for_vga_reset_recovery = 1;
            end
        end
        reset_seen = 1;
        previous_href = 0; previous_vsync = 0; byte_phase = 0;
        frame_started = 0; line_started = 0;
        line_bytes = 0; frame_lines = 0;
        previous_hsync = 1; previous_vga_vsync = 1;
        hsync_low_pixels = 0; vsync_low_pixels = 0;
        line_period_pixels = 0; frame_period_pixels = 0;
        seen_line_start = 0; seen_frame_start = 0;
    endfunction

    function void observe_camera(cam_vga_seq_item t);
        if (t.write_en === 1'b1 &&
            !$isunknown({t.write_addr, t.write_data})) begin
            observed_writes++;
            camera_write_cg.sample(int'(t.pattern), t.write_addr, t.write_data);
            camera_phase_cg.sample(current_phase_bucket());
            if (waiting_for_reset_recovery) begin
                reset_recovered_hits[reset_location]++;
                `uvm_info("RESET_RECOVERY", $sformatf(
                    "t=%0t location=%0d actual_write addr=%0d data=%04h",
                    t.sample_time, reset_location, t.write_addr, t.write_data), UVM_LOW)
                reset_cg.sample(reset_location, 1);
                waiting_for_reset_recovery = 0;
            end
        end
        if ($isunknown({t.href, t.vsync})) return;
        if (t.vsync) begin
            if (!previous_vsync) begin
                if (byte_phase) camera_event_cg.sample(4);
                if (frame_started) camera_frame_cg.sample(frame_lines);
                camera_event_cg.sample(0);
                frame_started = 1; frame_lines = 0;
            end
            byte_phase = 0; line_started = 0; line_bytes = 0;
        end else if (t.href) begin
            if (!line_started) begin
                camera_event_cg.sample(1);
                frame_lines++; line_started = 1; line_bytes = 0;
            end
            line_bytes++;
            byte_phase = !byte_phase;
        end else begin
            if (line_started) begin
                camera_line_cg.sample(line_bytes / 2, byte_phase);
                camera_event_cg.sample(byte_phase ? 3 : 2);
            end
            line_started = 0; line_bytes = 0; byte_phase = 0;
        end
        previous_href = t.href; previous_vsync = t.vsync;
    endfunction

    function void observe_memory(cam_vga_seq_item t);
        if (t.write_en === 1'b1 &&
            !$isunknown({t.write_addr, t.write_data})) begin
            observed_memory_loads++;
            memory_load_cg.sample(int'(t.pattern), t.write_addr, t.write_data);
        end
    endfunction

    function void observe_vga(cam_vga_seq_item t);
        int hregion, vregion, corner;
        observed_vga_pixels++;
        if (waiting_for_vga_reset_recovery &&
            !$isunknown({t.x, t.y, t.de, t.hsync, t.vsync_out})) begin
            vga_reset_cg.sample(1);
            waiting_for_vga_reset_recovery = 0;
        end
        if (!$isunknown({t.x, t.y, t.de})) begin
            hregion = t.x < 640 ? 0 : t.x < 656 ? 1 : t.x < 752 ? 2 : 3;
            vregion = t.y < 480 ? 0 : t.y < 490 ? 1 : t.y < 492 ? 2 : 3;
            if (t.x < 800 && t.y < 525)
                vga_geometry_cg.sample(t.x, t.y, t.de, hregion, vregion);
            if (t.x == 0) begin
                if (seen_line_start) vga_timing_cg.sample(2, line_period_pixels);
                line_period_pixels = 0; seen_line_start = 1;
                if (t.y == 0) begin
                    if (seen_frame_start) begin
                        vga_timing_cg.sample(3, frame_period_pixels);
                        vga_phase_cg.sample(current_phase_bucket());
                    end
                    frame_period_pixels = 0; seen_frame_start = 1;
                end
            end
        end
        line_period_pixels++; frame_period_pixels++;
        if (t.hsync === 1'b0) hsync_low_pixels++;
        else if (t.hsync === 1'b1 && !previous_hsync) begin
            vga_timing_cg.sample(0, hsync_low_pixels); hsync_low_pixels = 0;
        end
        if (t.vsync_out === 1'b0) vsync_low_pixels++;
        else if (t.vsync_out === 1'b1 && !previous_vga_vsync) begin
            vga_timing_cg.sample(1, vsync_low_pixels); vsync_low_pixels = 0;
        end
        if (!$isunknown(t.hsync)) previous_hsync = t.hsync;
        if (!$isunknown(t.vsync_out)) previous_vga_vsync = t.vsync_out;

        if (t.full_frame_ready && t.de === 1'b1 &&
            !$isunknown({t.read_data, t.rgb, t.read_addr, t.x, t.y})) begin
            rgb_mapping_cg.sample(0, t.read_data[15:12], t.rgb[11:8]);
            rgb_mapping_cg.sample(1, t.read_data[10:7], t.rgb[7:4]);
            rgb_mapping_cg.sample(2, t.read_data[4:1], t.rgb[3:0]);
            vga_address_cg.sample(t.read_addr);
            corner = -1;
            if (t.x == 0 && t.y == 0) corner = 0;
            if (t.x == 639 && t.y == 0) corner = 1;
            if (t.x == 0 && t.y == 479) corner = 2;
            if (t.x == 639 && t.y == 479) corner = 3;
            if (corner >= 0) vga_corner_cg.sample(corner);
        end
    endfunction

    virtual function void write(cam_vga_seq_item t);
        if (t.reset_active) begin observe_reset(); return; end
        reset_seen = 0;
        case (t.observation)
            OBS_CAMERA: if (vif.check_camera) observe_camera(t);
            OBS_VGA: if (vif.check_vga) observe_vga(t);
            OBS_MEMORY: if (vif.check_vga) observe_memory(t);
            default: ;
        endcase
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COVERAGE", $sformatf(
            "Camera actual writes=%0d memory preload stimulus=%0d VGA pixel periods=%0d. Coverage is scenario exposure, not a PASS verdict.",
            observed_writes, observed_memory_loads, observed_vga_pixels), UVM_LOW)
        if (vif.check_camera) begin
            `uvm_info("COVERAGE", $sformatf(
            "Actual instance coverage: camera_write=%.2f%% events=%.2f%% lines=%.2f%% frames=%.2f%% reset=%.2f%% phase=%.2f%%",
            camera_write_cg.get_inst_coverage(), camera_event_cg.get_inst_coverage(),
            camera_line_cg.get_inst_coverage(), camera_frame_cg.get_inst_coverage(),
            reset_cg.get_inst_coverage(), camera_phase_cg.get_inst_coverage()), UVM_LOW)
        end
        if (vif.check_vga) begin
            `uvm_info("COVERAGE", $sformatf(
            "Actual instance coverage: VGA_geometry=%.2f%% timing=%.2f%% RGB_mapping=%.2f%% read_address=%.2f%% corners=%.2f%% reset=%.2f%% phase=%.2f%%",
            vga_geometry_cg.get_inst_coverage(), vga_timing_cg.get_inst_coverage(),
            rgb_mapping_cg.get_inst_coverage(), vga_address_cg.get_inst_coverage(),
            vga_corner_cg.get_inst_coverage(), vga_reset_cg.get_inst_coverage(),
            vga_phase_cg.get_inst_coverage()), UVM_LOW)
            if (!vif.check_camera)
                `uvm_info("COVERAGE", $sformatf(
                "Memory preload stimulus coverage=%.2f%% (not camera capture coverage)",
                memory_load_cg.get_inst_coverage()), UVM_LOW)
        end
        if (vif.check_camera || vif.check_vga)
            `uvm_info("COVERAGE",
                "Unhit bins require additional targeted tests/seeds; inspect only enabled scopes. No automatic 100% coverage claim.", UVM_LOW)
    endfunction
endclass
