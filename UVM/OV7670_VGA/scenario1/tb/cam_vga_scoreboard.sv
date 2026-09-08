class cam_vga_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cam_vga_scoreboard)

    uvm_analysis_imp #(cam_vga_seq_item, cam_vga_scoreboard) analysis_export;
    virtual cam_vga_if vif;
    uvm_event frame_done_event;

    longint unsigned camera_writes, expected_writes, camera_pixels, memory_loads;
    longint unsigned vga_pixels_checked, vga_lines, timing_frames;
    longint unsigned full_vga_frames, errors, comparisons;
    int unsigned min_frames = 1, min_writes = 76800, min_memory_loads = 0;
    bit write_images = 1;
    logic [15:0] ref_mem [0:76799];
    bit ref_written [0:76799];
    bit in_reset, byte_phase, previous_vsync;
    logic [7:0] first_byte;
    int unsigned expected_write_addr, writes_in_camera_frame;
    int unsigned camera_frame, camera_line;
    bit previous_href;
    bit pending_write;
    logic [15:0] pending_data;
    int unsigned pending_addr;
    int unsigned expected_load_addr, loads_in_memory_frame;

    // Detect DUT x/y counter errors using an independent raster model.
    int unsigned expected_x, expected_y;
    bit comparing_frame;
    int frame_pattern;
    int unsigned frame_pixels;
    longint unsigned frame_first_errors;
    int ppm_fd;
    longint unsigned expected_hist [3][16];
    longint unsigned actual_hist [3][16];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        frame_done_event = new("frame_done_event");
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_vga_if)::get(this, "", "vif", vif))
            `uvm_fatal("NO_VIF", "cam_vga_scoreboard requires virtual interface key vif")
        void'(uvm_config_db#(int unsigned)::get(this, "", "min_frames", min_frames));
        void'(uvm_config_db#(int unsigned)::get(this, "", "min_writes", min_writes));
        void'(uvm_config_db#(int unsigned)::get(this, "", "min_memory_loads", min_memory_loads));
        void'(uvm_config_db#(bit)::get(this, "", "write_images", write_images));
    endfunction

    function void mismatch(string reason);
        errors++;
        if (errors <= 20)
            `uvm_error("CAM_VGA_MISMATCH", reason)
        else if (errors == 21)
            `uvm_error("CAM_VGA_MISMATCH", "Further detail suppressed; all mismatches remain counted in report_phase")
    endfunction

    function void abort_image(string reason);
        if (comparing_frame) begin
            if (ppm_fd != 0) begin
                $fclose(ppm_fd);
                ppm_fd = 0;
            end
            `uvm_info("FRAME_RESTART", $sformatf("Incomplete output comparison discarded: %s. Wait for the next stable complete raster.", reason), UVM_MEDIUM)
        end
        comparing_frame = 0;
    endfunction

    function void reset_model();
        abort_image("reset");
        byte_phase = 0;
        first_byte = '0;
        previous_vsync = 0;
        previous_href = 0;
        expected_write_addr = 0;
        writes_in_camera_frame = 0;
        expected_load_addr = 0;
        loads_in_memory_frame = 0;
        camera_line = 0;
        pending_write = 0;
        expected_x = 0;
        expected_y = 0;
    endfunction

    function string image_scope();
        return vif.link_camera_to_vga ? "CAMERA_TO_VGA_PATH" : "VGA_BLOCK";
    endfunction

    function string pattern_name(int id);
        case (id)
            0: return "COLOR_BARS";
            1: return "H_GRADIENT";
            2: return "V_GRADIENT";
            3: return "CHECKERBOARD";
            4: return "RANDOM_PIXELS";
            5: return "QUADRANTS";
            6: return "CHANNEL_WALK";
            default: return "UNSPECIFIED";
        endcase
    endfunction

    function void observe_camera(cam_vga_seq_item tr);
        comparisons++;
        if (tr.write_en !== pending_write)
            mismatch($sformatf("t=%0t camera_frame=%0d line=%0d write pulse expected=%0b actual=%b addr=%0d",
                tr.sample_time, camera_frame, camera_line, pending_write,
                tr.write_en, tr.write_addr));
        if (tr.write_en === 1'b1) begin
            camera_writes++;
            if (vif.link_camera_to_vga) abort_image("camera framebuffer write");
            if ($isunknown(tr.write_addr) || tr.write_addr >= 76800)
                mismatch($sformatf("t=%0t framebuffer WRITE address outside 0..76799: %h", tr.sample_time, tr.write_addr));
        end
        if (pending_write) begin
            if (vif.link_camera_to_vga) abort_image("expected camera framebuffer write");
            expected_writes++;
            writes_in_camera_frame++;
            comparisons += 2;
            if (tr.write_addr !== pending_addr[16:0])
                mismatch($sformatf("t=%0t camera_frame=%0d pixel=%0d WRITE address expected=%0d actual=%0d",
                    tr.sample_time, camera_frame, writes_in_camera_frame-1,
                    pending_addr, tr.write_addr));
            if (tr.write_data !== pending_data)
                mismatch($sformatf("t=%0t camera_frame=%0d pixel=%0d addr=%0d RGB565 expected=%04h actual=%04h",
                    tr.sample_time, camera_frame, writes_in_camera_frame-1,
                    pending_addr, pending_data, tr.write_data));
            if (pending_addr < 76800) begin
                if (vif.link_camera_to_vga) begin
                    ref_mem[pending_addr] = pending_data;
                    ref_written[pending_addr] = !$isunknown(pending_data);
                end
            end else begin
                mismatch($sformatf("t=%0t input stream produced more than 76800 pixels before VSYNC; expected addr=%0d",
                    tr.sample_time, pending_addr));
            end
            expected_write_addr++;
        end
        pending_write = 0;

        if (tr.vsync === 1'b1) begin
            if (!previous_vsync) begin
                camera_frame++;
                writes_in_camera_frame = 0;
                camera_line = 0;
                if (vif.link_camera_to_vga) abort_image("new camera frame");
            end
            expected_write_addr = 0;
            byte_phase = 0;
        end else if (tr.href === 1'b0) begin
            // Discard an unmatched first byte at every line boundary.
            byte_phase = 0;
        end else if (tr.href === 1'b1) begin
            if (!previous_href) camera_line++;
            if (!byte_phase) begin
                first_byte = tr.camera_byte;
                byte_phase = 1;
            end else begin
                pending_data = {first_byte, tr.camera_byte};
                pending_addr = expected_write_addr;
                pending_write = 1;
                byte_phase = 0;
                camera_pixels++;
            end
        end else begin
            mismatch($sformatf("t=%0t camera HREF is unknown", tr.sample_time));
        end
        if ($isunknown({tr.vsync, tr.href}) ||
            (tr.href === 1'b1 && tr.vsync === 1'b0 && $isunknown(tr.camera_byte)))
            mismatch($sformatf("t=%0t valid camera input contains X/Z", tr.sample_time));
        previous_vsync = (tr.vsync === 1'b1);
        previous_href = (tr.href === 1'b1);
    endfunction

    function void observe_memory(cam_vga_seq_item tr);
        // Observe TB source pins before the RAM edge.
        if ($isunknown(tr.write_en)) begin
            mismatch($sformatf("t=%0t VGA source load enable contains X/Z", tr.sample_time));
            return;
        end
        if (!tr.write_en) return;
        abort_image("new independent VGA source-memory load");
        memory_loads++;
        if ($isunknown(tr.write_addr) || tr.write_addr >= 76800) begin
            mismatch($sformatf("t=%0t VGA source load address outside 0..76799: %h",
                tr.sample_time, tr.write_addr));
            return;
        end
        // Every pattern explicitly starts a new complete load at address zero.
        if (tr.write_addr == 0) begin
            expected_load_addr = 0;
            loads_in_memory_frame = 0;
        end
        comparisons++;
        if (tr.write_addr !== expected_load_addr[16:0])
            mismatch($sformatf("t=%0t independent VGA source load address expected=%0d actual=%0d",
                tr.sample_time, expected_load_addr, tr.write_addr));
        if ($isunknown(tr.write_data))
            mismatch($sformatf("t=%0t independent VGA source load RGB565 contains X/Z: addr=%0d data=%h",
                tr.sample_time, tr.write_addr, tr.write_data));
        ref_mem[tr.write_addr] = tr.write_data;
        ref_written[tr.write_addr] = !$isunknown(tr.write_data);
        expected_load_addr++;
        loads_in_memory_frame++;
        if (loads_in_memory_frame > 76800)
            mismatch($sformatf("t=%0t VGA source load exceeds 76800 pixels before the next address-zero frame",
                tr.sample_time));
    endfunction

    function void begin_frame(cam_vga_seq_item tr);
        comparing_frame = 1;
        frame_pixels = 0;
        frame_first_errors = errors;
        frame_pattern = vif.pattern_id;
        foreach (expected_hist[c,b]) begin
            expected_hist[c][b] = 0;
            actual_hist[c][b] = 0;
        end
        if (write_images) begin
            ppm_fd = $fopen($sformatf("vga_frame_%0d.ppm", full_vga_frames), "w");
            if (ppm_fd == 0)
                mismatch("Could not open measured VGA output PPM file");
            else begin
                $fwrite(ppm_fd, "P3\n# SIMULATION MEASURED: VGA RGB444 expanded to RGB888\n");
                $fwrite(ppm_fd, "# scope=%s pattern=%s\n640 480\n255\n",
                    image_scope(), pattern_name(frame_pattern));
            end
        end
        `uvm_info("FRAME_CHECK", $sformatf("scope=%s start initialized 640x480 comparison, output=%0d pattern=%s",
            image_scope(), full_vga_frames, pattern_name(frame_pattern)), UVM_LOW)
    endfunction

    function void emit_histogram();
        int fd, base_y, x_bar, h_expected, h_actual;
        longint unsigned peak, sum_expected, sum_actual;
        string channel, color;
        fd = $fopen($sformatf("histogram_frame_%0d.svg", full_vga_frames), "w");
        if (fd == 0) begin
            mismatch("Could not open measured histogram SVG file");
            return;
        end
        $fwrite(fd, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1100\" height=\"830\" viewBox=\"0 0 1100 830\">\n");
        $fwrite(fd, "<rect width=\"1100\" height=\"830\" fill=\"#101827\"/>\n");
        $fwrite(fd, "<g font-family=\"Arial, sans-serif\" fill=\"#ecf2ff\">\n");
        $fwrite(fd, "<text x=\"45\" y=\"42\" font-size=\"24\">SIMULATION MEASURED: VGA RGB444 histogram</text>\n");
        $fwrite(fd, "<text x=\"45\" y=\"72\" font-size=\"16\">%s | Frame %0d | %s | checked pixels=%0d</text>\n",
            image_scope(), full_vga_frames, pattern_name(frame_pattern), frame_pixels);
        $fwrite(fd, "<text x=\"45\" y=\"98\" font-size=\"14\">Each level: left bar = expected; right bar = measured. Pixel-by-pixel comparison is also required.</text>\n");
        $fwrite(fd, "<text x=\"45\" y=\"121\" font-size=\"14\">Mismatches during this frame: %0d. Counts are measured, not predicted coverage percentages.</text>\n", errors-frame_first_errors);
        for (int c=0; c<3; c++) begin
            case(c)
                0: begin channel="R"; color="#ef6a78"; end
                1: begin channel="G"; color="#5de0ae"; end
                2: begin channel="B"; color="#6fabff"; end
            endcase
            peak = 1;
            sum_expected = 0;
            sum_actual = 0;
            for (int b=0; b<16; b++) begin
                if (expected_hist[c][b] > peak) peak = expected_hist[c][b];
                if (actual_hist[c][b] > peak) peak = actual_hist[c][b];
                sum_expected += expected_hist[c][b];
                sum_actual += actual_hist[c][b];
            end
            base_y = 310+c*220;
            $fwrite(fd, "<text x=\"45\" y=\"%0d\" font-size=\"16\">%s | peak=%0d | expected total=%0d | measured total=%0d</text>\n",
                base_y-155, channel, peak, sum_expected, sum_actual);
            $fwrite(fd, "<line x1=\"45\" y1=\"%0d\" x2=\"1040\" y2=\"%0d\" stroke=\"#728099\"/>\n", base_y, base_y);
            for (int b=0; b<16; b++) begin
                x_bar = 60+b*61;
                h_expected = int'((expected_hist[c][b]*130)/peak);
                h_actual = int'((actual_hist[c][b]*130)/peak);
                $fwrite(fd, "<rect x=\"%0d\" y=\"%0d\" width=\"19\" height=\"%0d\" fill=\"%s\" opacity=\"0.45\"><title>Expected %s[%0d]=%0d</title></rect>\n",
                    x_bar, base_y-h_expected, h_expected, color, channel, b, expected_hist[c][b]);
                $fwrite(fd, "<rect x=\"%0d\" y=\"%0d\" width=\"19\" height=\"%0d\" fill=\"%s\"><title>Measured %s[%0d]=%0d</title></rect>\n",
                    x_bar+22, base_y-h_actual, h_actual, color, channel, b, actual_hist[c][b]);
                $fwrite(fd, "<text x=\"%0d\" y=\"%0d\" font-size=\"13\">%0d</text>\n", x_bar+13, base_y+21, b);
            end
        end
        $fwrite(fd, "<text x=\"45\" y=\"802\" font-size=\"13\">X: channel value 0..15. Bar height: occurrence count. Hover bars to read exact counts.</text>\n</g></svg>\n");
        $fclose(fd);
    endfunction

    function void end_frame();
        longint unsigned sum_expected, sum_actual;
        if (frame_pixels != 307200)
            mismatch($sformatf("Complete visible frame requires 307200 pixels; got %0d", frame_pixels));
        for (int c=0; c<3; c++) begin
            sum_expected=0;
            sum_actual=0;
            for (int b=0; b<16; b++) begin
                sum_expected += expected_hist[c][b];
                sum_actual += actual_hist[c][b];
                if (expected_hist[c][b] != actual_hist[c][b])
                    mismatch($sformatf("frame=%0d histogram channel=%0d bin=%0d expected=%0d actual=%0d",
                        full_vga_frames, c, b, expected_hist[c][b], actual_hist[c][b]));
            end
            if (sum_expected != frame_pixels || sum_actual != frame_pixels)
                mismatch($sformatf("Histogram count conservation failed: channel=%0d expected_sum=%0d actual_sum=%0d pixels=%0d",
                    c, sum_expected, sum_actual, frame_pixels));
        end
        if (ppm_fd != 0) begin
            $fclose(ppm_fd);
            ppm_fd=0;
        end
        if (write_images) emit_histogram();
        `uvm_info("FRAME_RESULT", $sformatf("scope=%s frame=%0d pattern=%s compared=%0d mismatches=%0d (pixel comparison plus histogram)",
            image_scope(), full_vga_frames, pattern_name(frame_pattern), frame_pixels,
            errors-frame_first_errors), UVM_LOW)
        full_vga_frames++;
        comparing_frame=0;
        frame_done_event.trigger();
    endfunction

    function void observe_vga(cam_vga_seq_item tr);
        bit expected_de, expected_hsync, expected_vsync, source_frame_ready;
        int unsigned source_x, source_y, golden_addr;
        logic [15:0] golden565;
        logic [11:0] golden444;
        expected_de = (expected_x < 640 && expected_y < 480);
        expected_hsync = !(expected_x >= 656 && expected_x < 752);
        expected_vsync = !(expected_y >= 490 && expected_y < 492);
        comparisons += 5;
        if (tr.x !== expected_x[9:0] || tr.y !== expected_y[9:0])
            mismatch($sformatf("t=%0t raster expected=(%0d,%0d) actual=(%0d,%0d)",
                tr.sample_time, expected_x, expected_y, tr.x, tr.y));
        if (tr.de !== expected_de)
            mismatch($sformatf("t=%0t x=%0d y=%0d DE expected=%b actual=%b", tr.sample_time, expected_x, expected_y, expected_de, tr.de));
        if (tr.hsync !== expected_hsync || tr.vsync_out !== expected_vsync)
            mismatch($sformatf("t=%0t x=%0d y=%0d sync H/V expected=%b/%b actual=%b/%b",
                tr.sample_time, expected_x, expected_y, expected_hsync,
                expected_vsync, tr.hsync, tr.vsync_out));
        source_x = expected_x >> 1;
        source_y = expected_y >> 1;
        golden_addr = expected_de ? source_y*320+source_x : 0;
        if ($isunknown(tr.read_addr) || tr.read_addr !== golden_addr[16:0])
            mismatch($sformatf("t=%0t x=%0d y=%0d READ address expected=%0d actual=%0d",
                tr.sample_time, expected_x, expected_y, golden_addr, tr.read_addr));
        if (expected_de && (golden_addr >= 76800 || tr.read_addr >= 76800))
            mismatch($sformatf("t=%0t x=%0d y=%0d visible READ out of range expected=%0d actual=%0d",
                tr.sample_time, expected_x, expected_y, golden_addr, tr.read_addr));

        source_frame_ready = vif.link_camera_to_vga ?
            (!pending_write && writes_in_camera_frame == 76800) :
            (loads_in_memory_frame == 76800);
        if (comparing_frame && (!tr.full_frame_ready || !source_frame_ready))
            abort_image("source frame changed while scanning");

        if (!comparing_frame && expected_x == 0 && expected_y == 0 &&
            tr.full_frame_ready && source_frame_ready)
            begin_frame(tr);

        if (!expected_de) begin
            if (tr.rgb !== 12'h000)
                mismatch($sformatf("t=%0t x=%0d y=%0d blanking RGB expected=000 actual=%03h",
                    tr.sample_time, expected_x, expected_y, tr.rgb));
        end else if (comparing_frame) begin
            // Capture has finished.
            frame_pixels++;
            vga_pixels_checked++;
            if (golden_addr < 76800 && ref_written[golden_addr]) begin
                golden565 = ref_mem[golden_addr];
                golden444 = {golden565[15:12], golden565[10:7], golden565[4:1]};
                comparisons += 2;
                if (tr.read_data !== golden565 || tr.rgb !== golden444)
                    mismatch($sformatf("t=%0t frame=%0d pattern=%s VGA=(%0d,%0d) addr exp/act=%0d/%0d RGB565 exp/act=%04h/%04h RGB444 exp/act=%03h/%03h",
                        tr.sample_time, full_vga_frames, pattern_name(frame_pattern),
                        expected_x, expected_y, golden_addr, tr.read_addr,
                        golden565, tr.read_data, golden444, tr.rgb));
                expected_hist[0][golden444[11:8]]++;
                expected_hist[1][golden444[7:4]]++;
                expected_hist[2][golden444[3:0]]++;
            end else begin
                mismatch($sformatf("t=%0t complete-frame comparison reached unwritten/invalid reference address=%0d",
                    tr.sample_time, golden_addr));
            end
            if ($isunknown(tr.rgb)) begin
                mismatch($sformatf("t=%0t initialized output has X/Z at VGA=(%0d,%0d)",
                    tr.sample_time, expected_x, expected_y));
                if (ppm_fd != 0) $fwrite(ppm_fd, "255 0 255\n");
            end else begin
                actual_hist[0][tr.rgb[11:8]]++;
                actual_hist[1][tr.rgb[7:4]]++;
                actual_hist[2][tr.rgb[3:0]]++;
                if (ppm_fd != 0) $fwrite(ppm_fd, "%0d %0d %0d\n",
                    int'(tr.rgb[11:8])*17, int'(tr.rgb[7:4])*17, int'(tr.rgb[3:0])*17);
            end
        end

        if (expected_x == 799) begin
            vga_lines++;
            expected_x = 0;
            if (expected_y == 524) begin
                expected_y = 0;
                timing_frames++;
                if (comparing_frame) end_frame();
            end else expected_y++;
        end else expected_x++;
    endfunction

    function void write(cam_vga_seq_item tr);
        if (tr.reset_active) begin
            if (!in_reset) reset_model();
            in_reset = 1;
            if (vif.check_camera && tr.observation == OBS_CAMERA && tr.write_en !== 1'b0)
                mismatch($sformatf("t=%0t camera write asserted or unknown during reset", tr.sample_time));
            if (vif.check_vga && !vif.link_camera_to_vga &&
                tr.observation == OBS_MEMORY && tr.write_en !== 1'b0)
                mismatch($sformatf("t=%0t independent VGA source load asserted or unknown during reset", tr.sample_time));
            return;
        end
        in_reset = 0;
        case (tr.observation)
            OBS_CAMERA: if (vif.check_camera) observe_camera(tr);
            OBS_VGA: if (vif.check_vga) observe_vga(tr);
            OBS_MEMORY: if (vif.check_vga && !vif.link_camera_to_vga) observe_memory(tr);
            default: begin end
        endcase
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (vif.check_camera) begin
            if (pending_write)
                mismatch("Camera block test ended with an expected framebuffer write still pending; drain at least one pclk edge");
            if (camera_writes != expected_writes)
                mismatch($sformatf("Camera block write count expected=%0d actual=%0d", expected_writes, camera_writes));
            if (camera_writes < min_writes)
                mismatch($sformatf("Vacuous camera block result: writes=%0d required>=%0d", camera_writes, min_writes));
        end
        if (vif.check_vga) begin
            if (full_vga_frames < min_frames)
                mismatch($sformatf("Vacuous VGA block result: checked full frames=%0d required>=%0d", full_vga_frames, min_frames));
            if (!vif.link_camera_to_vga && memory_loads < min_memory_loads)
                mismatch($sformatf("Vacuous independent VGA source load: pixels=%0d required>=%0d", memory_loads, min_memory_loads));
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (ppm_fd != 0) begin
            $fclose(ppm_fd);
            ppm_fd = 0;
        end
        if (vif.check_camera)
            `uvm_info("CAMERA_BLOCK_SUMMARY", $sformatf("camera_pixels=%0d expected_writes=%0d actual_writes=%0d pending_writes=%0d",
                camera_pixels, expected_writes, camera_writes, pending_write), UVM_NONE)
        if (vif.check_vga)
            `uvm_info("VGA_BLOCK_SUMMARY", $sformatf("scope=%s independent_memory_loads=%0d VGA_pixels=%0d raster_lines=%0d raster_frames=%0d fully_compared_frames=%0d",
                image_scope(), memory_loads, vga_pixels_checked, vga_lines,
                timing_frames, full_vga_frames), UVM_NONE)
        `uvm_info("BLOCK_SCOREBOARD_SUMMARY", $sformatf("camera_enabled=%0b VGA_enabled=%0b comparisons=%0d mismatches=%0d; SCCB results are reported by the SCCB checker",
            vif.check_camera, vif.check_vga, comparisons, errors), UVM_NONE)
    endfunction
endclass
