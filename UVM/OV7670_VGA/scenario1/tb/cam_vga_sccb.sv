// SCCB camera responder + independent, wire-level configuration checker.
// Only sccb_ack_low is driven. SCL, SDA data, START/STOP and setup status
// are observed; no DUT state or configuration LUT is read hierarchically.
class cam_vga_sccb extends uvm_component;
    `uvm_component_utils(cam_vga_sccb)

    virtual cam_vga_if vif;
    localparam int NUM_CONFIG = 67;
    localparam time SYSTEM_PERIOD = 10ns;

    // transactions is per setup request; other result counts are cumulative.
    int unsigned transactions = 0;
    int unsigned total_transactions = 0;
    int unsigned completed_setups = 0;
    int unsigned error_setups = 0;
    int unsigned errors = 0;
    int unsigned reset_interruptions = 0;
    // Tests set only the outcomes required by their selected scenarios.
    // Zero is intentional for camera/VGA tests that leave this block idle.
    int unsigned min_completed_setups = 0;
    int unsigned min_error_setups = 0;
    int unsigned min_reset_interruptions = 0;
    bit in_progress = 0;

    bit was_reset_released = 0;
    bit checker_armed = 0, setup_accepted = 0;
    logic previous_setup_start = 0;
    logic previous_scl = 1, previous_sda = 1;
    int byte_index = 0, bit_count = 0, ack_count = 0;
    logic [7:0] shift_byte = 0;
    logic [7:0] observed_byte[3];
    bit ack_sampled = 0;
    int transaction_nack_byte = -1;
    bit epoch_nack_seen = 0;
    int epoch_nack_transaction = -1;
    bit done_seen = 0, error_seen = 0, timeout_reported = 0;
    bit sticky_violation_reported = 0, unknown_reported = 0;
    time request_time, first_stop_time, last_rise_time, last_fall_time;
    time expected_scl_period, expected_half_period;
    time minimum_reset_delay, setup_timeout;
    int tick_div;

    // evt: 0 completed wire transaction, 1 sampled ACK, 2 setup status,
    //      3 reset, 4 timing mode. Every bin represents a planned scenario.
    covergroup sccb_cg with function sample(
        int evt, int table_index, int ack_byte, bit nack,
        bit outcome_error, bit interrupted, bit accelerated);
        option.per_instance = 1;
        table_entry: coverpoint table_index iff (evt == 0) {
            bins entries[] = {[0:66]};
        }
        byte_position: coverpoint ack_byte iff (evt == 1) {
            bins device_address = {0};
            bins register_address = {1};
            bins register_data = {2};
        }
        ack_result: coverpoint nack iff (evt == 1) {
            bins ack = {0}; bins nack = {1};
        }
        byte_ack: cross byte_position, ack_result;
        setup_result: coverpoint outcome_error iff (evt == 2) {
            bins completed = {0}; bins rejected = {1};
        }
        reset_location: coverpoint interrupted iff (evt == 3) {
            bins outside_transaction = {0}; bins during_transaction = {1};
        }
        timing_mode: coverpoint accelerated iff (evt == 4) {
            bins physical_100khz_configuration = {0};
            bins scaled_configuration = {1};
        }
    endgroup

    function new(string name = "cam_vga_sccb", uvm_component parent = null);
        super.new(name, parent);
        sccb_cg = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_vga_if)::get(this, "", "vif", vif))
            `uvm_fatal("SCCB_VIF", "cam_vga_if configuration key 'vif' is missing")
    endfunction

    // Frozen delivery specification for this RTL snapshot, independent of
    // the runtime DUT LUT. Review this table when the approved setup changes.
    // Each entry is {register_address, register_data}; device write byte=42.
    // This checks delivery/order of the intended table, not sensor optics or
    // whether these values are optimal for every physical OV7670 module.
    function logic [15:0] expected_config(int index);
        case (index)
             0: return 16'h1280;  1: return 16'h3a04;
             2: return 16'h1200;  3: return 16'h13e7;
             4: return 16'h6f9f;  5: return 16'hb084;
             6: return 16'h703a;  7: return 16'h7135;
             8: return 16'h7211;  9: return 16'h73f0;
            10: return 16'h7a20; 11: return 16'h7b10;
            12: return 16'h7c1e; 13: return 16'h7d35;
            14: return 16'h7e5a; 15: return 16'h7f69;
            16: return 16'h8076; 17: return 16'h8180;
            18: return 16'h8288; 19: return 16'h838f;
            20: return 16'h8496; 21: return 16'h85a3;
            22: return 16'h86af; 23: return 16'h87c4;
            24: return 16'h88d7; 25: return 16'h89e8;
            26: return 16'h0000; 27: return 16'h1000;
            28: return 16'h0d40; 29: return 16'h1418;
            30: return 16'ha505; 31: return 16'hab07;
            32: return 16'h2495; 33: return 16'h2533;
            34: return 16'h26e3; 35: return 16'h9f78;
            36: return 16'ha068; 37: return 16'ha103;
            38: return 16'ha6d8; 39: return 16'ha7d8;
            40: return 16'ha8f0; 41: return 16'ha990;
            42: return 16'haa94; 43: return 16'h1214;
            44: return 16'h0c04; 45: return 16'h3e19;
            46: return 16'h703a; 47: return 16'h7135;
            48: return 16'h7211; 49: return 16'h73f1;
            50: return 16'ha202; 51: return 16'h1716;
            52: return 16'h1804; 53: return 16'h3224;
            54: return 16'h1902; 55: return 16'h1a7a;
            56: return 16'h030a; 57: return 16'h40d0;
            58: return 16'h8c00; 59: return 16'h3dc0;
            60: return 16'h4fb3; 61: return 16'h50b3;
            62: return 16'h5100; 63: return 16'h523d;
            64: return 16'h53a7; 65: return 16'h54e4;
            66: return 16'h589e;
            default: return 16'hxxxx;
        endcase
    endfunction

    function void fail(string detail);
        errors++;
        `uvm_error("SCCB_CHECK", $sformatf("epoch=%0d transaction=%0d byte=%0d time=%0t: %s",
            vif.sccb_epoch, transactions, byte_index, $time, detail))
    endfunction

    function void reset_checker();
        // There are no forked ACK tasks to survive reset. This function is
        // called immediately on reset assertion as well as on clock samples.
        vif.sccb_ack_low = 0;
        if (was_reset_released) begin
            if (in_progress) reset_interruptions++;
            sccb_cg.sample(3, 0, 0, 0, 0, in_progress, 0);
        end
        was_reset_released = 0;
        checker_armed = 0; setup_accepted = 0;
        previous_setup_start = 0;
        in_progress = 0;
        transactions = 0;
        byte_index = 0; bit_count = 0; ack_count = 0;
        ack_sampled = 0; shift_byte = 0;
        transaction_nack_byte = -1;
        epoch_nack_seen = 0; epoch_nack_transaction = -1;
        done_seen = 0; error_seen = 0; timeout_reported = 0;
        sticky_violation_reported = 0; unknown_reported = 0;
        previous_scl = 1; previous_sda = 1;
        first_stop_time = 0; last_rise_time = 0; last_fall_time = 0;
    endfunction

    function void begin_epoch();
        was_reset_released = 1;
        if (vif.cfg_freq_hz < 1000 || vif.sccb_freq_hz <= 0)
            `uvm_fatal("SCCB_CONFIG", "Use cfg_freq_hz>=1000 and sccb_freq_hz>0")
        tick_div = vif.cfg_freq_hz / (4 * vif.sccb_freq_hz);
        if (tick_div < 1) tick_div = 1;
        expected_scl_period = 4 * tick_div * SYSTEM_PERIOD;
        expected_half_period = 2 * tick_div * SYSTEM_PERIOD;
        minimum_reset_delay = (vif.cfg_freq_hz/1000) * 30 * SYSTEM_PERIOD;
        setup_timeout = minimum_reset_delay +
            NUM_CONFIG * (32*expected_scl_period + 32*SYSTEM_PERIOD) + 100*SYSTEM_PERIOD;
        sccb_cg.sample(4, 0, 0, 0, 0, 0, vif.cfg_freq_hz != 100000000);
        `uvm_info("SCCB_TIMING", $sformatf(
            "cfg_clk=%0d actual_clk=100000000 tick_div=%0d SCL_period=%0t reset_wait_min=%0t (scaled in FAST_SETUP)",
            vif.cfg_freq_hz, tick_div, expected_scl_period, minimum_reset_delay), UVM_LOW)
    endfunction

    function void begin_setup_request();
        // SCCB_setup_CNTL has an external start input. Reset release alone
        // does not request configuration, so idle time must never time out.
        checker_armed = 1;
        setup_accepted = 0;
        request_time = $time;
        transactions = 0;
        byte_index = 0; bit_count = 0; ack_count = 0;
        transaction_nack_byte = -1;
        epoch_nack_seen = 0; epoch_nack_transaction = -1;
        done_seen = 0; error_seen = 0; timeout_reported = 0;
        sticky_violation_reported = 0;
        first_stop_time = 0; last_rise_time = 0; last_fall_time = 0;
    endfunction

    function void receive_start();
        if (in_progress) fail("Repeated START before STOP: this three-byte write requires STOP");
        if (!checker_armed) fail("Wire START without an external setup_start request");
        if (done_seen || error_seen) fail("Unexpected START after terminal setup status without a new request");
        if (transactions >= NUM_CONFIG) fail("More than 67 configuration transactions");
        if (vif.setup_busy !== 1'b1) fail("START while setup_busy is not asserted");
        if (transactions == 1 && first_stop_time != 0 &&
            $time < first_stop_time + minimum_reset_delay)
            fail("Register 1 START occurred before the required post-reset-register wait");
        in_progress = 1;
        byte_index = 0; bit_count = 0; ack_count = 0;
        shift_byte = 0; ack_sampled = 0;
        last_rise_time = 0; last_fall_time = 0;
        vif.sccb_ack_low = 0;
        transaction_nack_byte = (vif.nack_transaction == int'(transactions)) ? vif.nack_byte : -1;
        if (transaction_nack_byte < -1 || transaction_nack_byte > 2)
            `uvm_fatal("SCCB_NACK_CONFIG", "nack_byte must be -1, 0, 1 or 2")
    endfunction

    function void check_received_byte();
        logic [15:0] expected_pair;
        logic [7:0] expected_byte;
        expected_pair = expected_config(transactions);
        case (byte_index)
            0: expected_byte = 8'h42;
            1: expected_byte = expected_pair[15:8];
            2: expected_byte = expected_pair[7:0];
            default: expected_byte = 8'hxx;
        endcase
        observed_byte[byte_index] = shift_byte;
        if (shift_byte !== expected_byte)
            fail($sformatf("MSB-first byte mismatch: expected=%02h actual=%02h (table=%04h)",
                expected_byte, shift_byte, expected_pair));
    endfunction

    function void receive_rising_clock();
        logic expected_ack_level;
        // The extra SCL rise used to form STOP is not a fourth data byte.
        if (byte_index >= 3) return;
        if (last_rise_time != 0 && $time - last_rise_time != expected_scl_period)
            fail($sformatf("SCL period expected=%0t actual=%0t", expected_scl_period, $time-last_rise_time));
        if (last_fall_time != 0 && $time - last_fall_time != expected_half_period)
            fail($sformatf("SCL low width expected=%0t actual=%0t", expected_half_period, $time-last_fall_time));
        last_rise_time = $time;
        if (bit_count < 8) begin
            shift_byte = {shift_byte[6:0], vif.cam_sda};
            bit_count++;
            if (bit_count == 8) check_received_byte();
        end else if (!ack_sampled) begin
            expected_ack_level = (transaction_nack_byte == byte_index);
            if (vif.cam_sda !== expected_ack_level)
                fail($sformatf("ACK slot expected SDA=%0b actual SDA=%b", expected_ack_level, vif.cam_sda));
            if (expected_ack_level) begin
                epoch_nack_seen = 1;
                epoch_nack_transaction = transactions;
            end
            sccb_cg.sample(1, transactions, byte_index, vif.cam_sda === 1'b1, 0, 0, 0);
            ack_sampled = 1;
            ack_count++;
        end else fail("Extra rising clock in the same ACK slot");
    endfunction

    function void receive_falling_clock();
        if (byte_index >= 3) return;
        if (last_rise_time != 0 && $time - last_rise_time != expected_half_period)
            fail($sformatf("SCL high width expected=%0t actual=%0t", expected_half_period, $time-last_rise_time));
        last_fall_time = $time;
        if (bit_count == 8) begin
            if (!ack_sampled) begin
                // Eighth bit has finished. Pull down only while SCL is low,
                // and keep ACK valid across the entire ninth high phase.
                vif.sccb_ack_low = (transaction_nack_byte != byte_index);
            end else begin
                // Ninth falling edge: release SDA before the next byte.
                vif.sccb_ack_low = 0;
                byte_index++;
                bit_count = 0; shift_byte = 0; ack_sampled = 0;
            end
        end
    endfunction

    function void receive_stop();
        if (!in_progress) begin
            fail("STOP without a matching START");
            return;
        end
        if (byte_index != 3 || bit_count != 0 || ack_count != 3)
            fail($sformatf("STOP before exactly 3 bytes and 3 ACK slots: bytes=%0d bits=%0d ACKs=%0d",
                byte_index, bit_count, ack_count));
        if (vif.sccb_ack_low) fail("Camera responder still holds SDA at STOP");
        if (transactions == 0) first_stop_time = $time;
        sccb_cg.sample(0, transactions, 0, 0, 0, 0, 0);
        transactions++;
        total_transactions++;
        in_progress = 0;
        last_rise_time = 0; last_fall_time = 0;
    endfunction

    function void check_status();
        if (!checker_armed) return;
        if (vif.setup_busy === 1'b1) setup_accepted = 1;
        // Previous terminal flags remain high while a new request crosses
        // the DUT input synchronizer. Compare the new outcome only after
        // this attempt has actually asserted busy.
        if (!setup_accepted) begin
            if (!timeout_reported && $time > request_time + setup_timeout) begin
                fail("Setup request was not accepted before timeout");
                timeout_reported = 1;
            end
            return;
        end
        if (vif.setup_done === 1'b1 && !done_seen) begin
            if (epoch_nack_seen) fail("setup_done asserted despite injected NACK");
            if (transactions != NUM_CONFIG || in_progress)
                fail($sformatf("setup_done before 67 complete START/three-byte/STOP writes: actual=%0d", transactions));
            if (vif.setup_busy !== 1'b0 || vif.setup_error !== 1'b0)
                fail("Completed setup must have setup_busy=0 and setup_error=0");
            done_seen = 1;
            completed_setups++;
            sccb_cg.sample(2, 0, 0, 0, 0, 0, 0);
        end
        if (vif.setup_error === 1'b1 && !error_seen) begin
            if (!epoch_nack_seen) fail("Unexpected setup_error while the camera ACKed every byte");
            if (in_progress || transactions != epoch_nack_transaction + 1)
                fail("NACK error must be reported after STOP of the injected transaction");
            if (vif.setup_done !== 1'b0 || vif.setup_busy !== 1'b0)
                fail("NACK terminal status must have setup_done=0 and setup_busy=0");
            error_seen = 1;
            error_setups++;
            sccb_cg.sample(2, 0, 0, 0, 1, 0, 0);
        end
        if (!sticky_violation_reported &&
            ((done_seen && vif.setup_done !== 1'b1) ||
             (error_seen && vif.setup_error !== 1'b1))) begin
            fail("Terminal setup status did not remain asserted until reset or a new request");
            sticky_violation_reported = 1;
        end
        if (!done_seen && !error_seen && !timeout_reported &&
            $time > request_time + setup_timeout) begin
            fail($sformatf("Setup timeout after %0t; no terminal done/error status", setup_timeout));
            timeout_reported = 1;
        end
    endfunction

    task run_phase(uvm_phase phase);
        bit start_seen_now, stop_seen_now;
        vif.sccb_ack_low = 0;
        forever begin
            // SCCB outputs change at positive system edges. Sampling at the
            // following negative edge avoids NBA races. Even TICK_DIV=1
            // leaves enough low time to drive/release the external ACK.
            @(negedge vif.clk or negedge vif.rst_n);
            if (!vif.check_sccb) begin
                // A disabled responder must release the open-drain bus and
                // must not create completion, timeout, or protocol results.
                vif.sccb_ack_low = 0;
                was_reset_released = 0;
                checker_armed = 0; setup_accepted = 0;
                in_progress = 0;
                previous_setup_start = vif.sccb_start;
                previous_scl = vif.cam_scl; previous_sda = vif.cam_sda;
                continue;
            end
            if (!vif.rst_n) begin
                reset_checker();
                continue;
            end
            if (!was_reset_released) begin_epoch();
            if (vif.sccb_start === 1'b1 && previous_setup_start === 1'b0 &&
                (!checker_armed || done_seen || error_seen))
                begin_setup_request();
            previous_setup_start = vif.sccb_start;
            if ($isunknown({vif.cam_scl, vif.cam_sda, vif.setup_busy,
                            vif.setup_done, vif.setup_error}) && !unknown_reported) begin
                fail("Unknown X/Z on pulled-up SCCB bus or setup status");
                unknown_reported = 1;
            end
            start_seen_now = previous_sda === 1'b1 && vif.cam_sda === 1'b0 &&
                             previous_scl === 1'b1 && vif.cam_scl === 1'b1;
            stop_seen_now = previous_sda === 1'b0 && vif.cam_sda === 1'b1 &&
                            previous_scl === 1'b1 && vif.cam_scl === 1'b1;
            if (start_seen_now) receive_start();
            else if (stop_seen_now) receive_stop();
            else if (in_progress) begin
                if (previous_scl === 1'b0 && vif.cam_scl === 1'b1) receive_rising_clock();
                if (previous_scl === 1'b1 && vif.cam_scl === 1'b0) receive_falling_clock();
            end
            check_status();
            previous_scl = vif.cam_scl;
            previous_sda = vif.cam_sda;
        end
    endtask

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (completed_setups < min_completed_setups)
            fail($sformatf("Required completed setups=%0d, observed=%0d",
                min_completed_setups, completed_setups));
        if (error_setups < min_error_setups)
            fail($sformatf("Required NACK terminal outcomes=%0d, observed=%0d",
                min_error_setups, error_setups));
        if (reset_interruptions < min_reset_interruptions)
            fail($sformatf("Required wire-transaction reset interruptions=%0d, observed=%0d",
                min_reset_interruptions, reset_interruptions));
        if (vif.check_sccb && checker_armed && !done_seen && !error_seen)
            fail("Test ended with a setup request still outstanding");
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCCB_SUMMARY", $sformatf(
            "complete_setups=%0d error_setups=%0d total_wire_transactions=%0d reset_interruptions=%0d checker_errors=%0d coverage=%0.2f%%",
            completed_setups, error_setups, total_transactions, reset_interruptions, errors,
            sccb_cg.get_inst_coverage()), UVM_LOW)
    endfunction
endclass
