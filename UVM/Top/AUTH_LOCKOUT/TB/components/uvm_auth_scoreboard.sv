// Check authentication control results and UART traffic against expected events.
// These checks cover injected-result tests, not camera pattern recognition.
class AuthScoreboard extends uvm_component;
    `uvm_component_utils(AuthScoreboard)
    virtual vga_if b1;
    virtual vga_if b2;
    virtual uart_if uart1;
    virtual uart_if uart2;
    virtual control_if control;
    string test_mode;
    byte unsigned expected_q[$];
    byte unsigned tx_to_serial_q[$];
    byte unsigned serial_to_rx_q[$];
    int checks, errors;
    int fail_seen;
    bit alarm_seen, unlock_seen, relock_seen;
    int initial_lock_tx_count;
    int unlock_event_tx_count;
    int button_packet_count;
    int relock_packet_count;
    int post_relock_extra_tx_count;
    bit chk_auth_to_unlocked;
    bit chk_b1_uart_tx;
    bit chk_b2_uart_rx;
    bit chk_unlock_decode;
    bit chk_b2_unlock;
    bit chk_fail_count_1;
    bit chk_fail_count_2;
    bit chk_fail_count_3;
    bit chk_auth_to_lockout;
    bit chk_alarm;
    bit summary_printed;

    function new(string name="AuthScoreboard", uvm_component parent=null);
        super.new(name,parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(string)::get(this,"","test_mode",test_mode));
        if (!uvm_config_db#(virtual vga_if)::get(this,"","board1_vif",b1))
            `uvm_fatal("AUTH_SCB","Missing Board1 observation interface")
        if (!uvm_config_db#(virtual vga_if)::get(this,"","board2_vif",b2))
            `uvm_fatal("AUTH_SCB","Missing Board2 observation interface")
        if (!uvm_config_db#(virtual uart_if)::get(this,"","uart1_vif",uart1))
            `uvm_fatal("AUTH_SCB","Missing Board1 UART interface")
        if (!uvm_config_db#(virtual uart_if)::get(this,"","uart2_vif",uart2))
            `uvm_fatal("AUTH_SCB","Missing Board2 UART interface")
        if (!uvm_config_db#(virtual control_if)::get(this,"","control_vif",control))
            `uvm_fatal("AUTH_SCB","Missing Board1 control interface")
    endfunction
    task automatic mismatch(string where, byte exp, byte act);
        errors++; `uvm_error("AUTH_SCB",$sformatf("%s expected=0x%02h actual=0x%02h",where,exp,act))
    endtask
    function automatic int expected_grid(input int index);
        case(index) 0:return 1; 1:return 2; 2:return 3;
                    3:return 6; 4:return 5; 5:return 8; default:return 0; endcase
    endfunction
    task run_phase(uvm_phase phase);
        if (test_mode != "AUTH_SUCCESS" && test_mode != "AUTH_LOCKOUT") return;
        if (test_mode == "AUTH_SUCCESS") begin
            // Expect unlock, switch updates, four button packets, and one relock packet.
            // Queue comparisons detect missing, extra, reordered, or incorrect packets.
            expected_q = '{8'h40,8'h41,8'h43,8'h42,8'h40,8'h43,
                           8'h63,8'h53,8'h4b,8'h47,8'h00};
            fork
                begin
                    byte unsigned exp;
                    bit unlock_prev;
                    bit waiting_unlock_packet;
                    unlock_prev = 1'b0;
                    waiting_unlock_packet = 1'b0;
                    forever begin
                    @(posedge b1.clk);
                    if (b1.unlock_state && !unlock_prev)
                        waiting_unlock_packet = 1'b1;
                    unlock_prev = b1.unlock_state;
                    if (b1.uart_tx_start) begin
                        // Flag any Board 1 UART transmit attempt while locked before the first unlock.
                        if (!unlock_seen && !b1.unlock_state) begin
                            initial_lock_tx_count++;
                            errors++;
                            `uvm_error("AUTH_LOCK_GATE",
                                "uart_tx_start asserted while Board1 was locked")
                        end
                        if (waiting_unlock_packet) begin
                            unlock_event_tx_count++;
                            waiting_unlock_packet = 1'b0;
                            if (b1.uart_tx_data !== 8'h40)
                                mismatch("unlock transition packet",8'h40,
                                         b1.uart_tx_data);
                            else
                                chk_b1_uart_tx = 1'b1;
                        end
                        if ($onehot(b1.uart_tx_data[5:2]))
                            button_packet_count++;
                        if (relock_seen) begin
                            if ((relock_packet_count == 0) &&
                                (b1.uart_tx_data === 8'h00))
                                relock_packet_count++;
                            else begin
                                post_relock_extra_tx_count++;
                                errors++;
                                `uvm_error("AUTH_RELOCK_GATE", $sformatf(
                                    "extra packet after relock data=0x%02h",
                                    b1.uart_tx_data))
                            end
                        end
                        if (!expected_q.size()) mismatch("unexpected Board1 TX",0,b1.uart_tx_data);
                        else begin exp=expected_q.pop_front(); checks++;
                            if (b1.uart_tx_data!==exp) mismatch("Board1 TX load",exp,b1.uart_tx_data);
                            tx_to_serial_q.push_back(exp);
                        end
                    end
                end
                end
                forever begin
                    byte unsigned value, exp;
                    uart1.receive_byte(value);
                    if (!tx_to_serial_q.size()) mismatch("unexpected serial TX",0,value);
                    else begin exp=tx_to_serial_q.pop_front(); checks++;
                        if (value!==exp) mismatch("Board1 serial TX",exp,value);
                        serial_to_rx_q.push_back(exp);
                    end
                end
                forever begin
                    byte unsigned exp;
                    @(posedge b2.clk); if (b2.uart_rx_done) begin
                        if (!serial_to_rx_q.size()) mismatch("unexpected Board2 RX",0,b2.uart_rx_data);
                        else begin exp=serial_to_rx_q.pop_front(); checks++;
                            if (b2.uart_rx_data!==exp) mismatch("Board2 RX",exp,b2.uart_rx_data);
                            if ((exp == 8'h40) &&
                                (b2.uart_rx_data === 8'h40))
                                chk_b2_uart_rx = 1'b1;
                            // Sample combinational button pulses before NBA clears rx_done.
                            if (b2.button_pulse !== exp[5:2]) begin
                                errors++;
                                `uvm_error("AUTH_DECODE",$sformatf(
                                    "packet=0x%02h button pulse expected=0x%01h actual=0x%01h",
                                    exp,exp[5:2],b2.button_pulse))
                            end
                            #1;
                            if ({b2.unlock_state,b2.effect_sel,b2.zoom_en}
                                !== {exp[6],exp[1:0]}) begin
                                errors++;
                                `uvm_error("AUTH_DECODE",$sformatf(
                                    "packet=0x%02h level decode expected=0x%01h actual=0x%01h",exp,
                                    {exp[6],exp[1:0]},
                                    {b2.unlock_state,b2.effect_sel,b2.zoom_en}))
                            end else if ((exp == 8'h40) &&
                                         (b2.uart_rx_data === 8'h40)) begin
                                chk_unlock_decode = 1'b1;
                                if (b2.unlock_state === 1'b1)
                                    chk_b2_unlock = 1'b1;
                            end
                        end
                    end
                end
                forever begin
                    byte unsigned value;
                    uart2.receive_byte(value);
                    checks++;
                    if (value !== 8'h80) mismatch("Board2 serial relock",8'h80,value);
                end
                begin
                    logic [1:0] previous_state;
                    previous_state = b1.control_state;
                    forever begin
                    @(posedge b1.clk);
                    if ((previous_state == 2'd1) &&
                        (b1.control_state == 2'd2))
                        chk_auth_to_unlocked = 1'b1;
                    previous_state = b1.control_state;
                    if (b1.unlock_state && b2.unlock_state && !unlock_seen) begin
                        unlock_seen=1;
                    end
                    if (b1.uart_rx_done && b1.uart_rx_data==8'h80) begin
                        checks++; relock_seen=1;
                    end
                    end
                end
            join
        end else begin
          logic [1:0] previous_state;
          previous_state = b1.control_state;
          forever begin
            @(posedge b1.clk);
            if ((previous_state == 2'd1) &&
                (b1.control_state == 2'd3))
                chk_auth_to_lockout = 1'b1;
            previous_state = b1.control_state;
            if (b1.fail_count > fail_seen) begin
                fail_seen = b1.fail_count;
            end
            if (b1.fail_count == 1) chk_fail_count_1 = 1'b1;
            if (b1.fail_count == 2) chk_fail_count_2 = 1'b1;
            if (b1.fail_count == 3) chk_fail_count_3 = 1'b1;
            if (b1.alarm) begin
                alarm_seen=1;
                chk_alarm=1'b1;
            end
            if (b1.unlock_state || b2.unlock_state) unlock_seen=1;
            // Treat any Board 1 UART transmit attempt as an error throughout AUTH_LOCKOUT.
            if (b1.uart_tx_start)
                mismatch("UART packet during lockout test",0,b1.uart_tx_data);
          end
        end
    endtask
    function automatic string pass_fail(bit passed);
        return passed ? "PASS" : "FAIL";
    endfunction

    function void report_phase(uvm_phase phase);
        int total_check;
        int summary_pass;
        int summary_fail;
        super.report_phase(phase);
        if (test_mode=="AUTH_SUCCESS" || test_mode=="AUTH_LOCKOUT") begin
            if (expected_q.size() || tx_to_serial_q.size() || serial_to_rx_q.size())
                `uvm_error("AUTH_SCB","UART expected queues were not empty")
            if (test_mode=="AUTH_SUCCESS" && (!unlock_seen || !relock_seen)) begin
                errors++; `uvm_error("AUTH_SCB","Missing unlock or reverse-UART relock completion")
            end
            if (test_mode=="AUTH_SUCCESS" &&
                ((initial_lock_tx_count != 0) ||
                 (unlock_event_tx_count != 1) ||
                 (button_packet_count != 4) ||
                 (relock_packet_count != 1) ||
                 (post_relock_extra_tx_count != 0))) begin
                errors++;
                `uvm_error("AUTH_SCB", $sformatf(
                    "packet-count failure lock_tx=%0d unlock_tx=%0d button_tx=%0d relock_tx=%0d post_relock_extra=%0d",
                    initial_lock_tx_count, unlock_event_tx_count,
                    button_packet_count, relock_packet_count,
                    post_relock_extra_tx_count))
            end
            if (test_mode=="AUTH_LOCKOUT" &&
                ((fail_seen != 3) || !alarm_seen || unlock_seen)) begin
                errors++; `uvm_error("AUTH_SCB",$sformatf(
                    "Lockout result fail_seen=%0d alarm=%0b unlock_seen=%0b",
                    fail_seen,alarm_seen,unlock_seen))
            end

            if (test_mode=="AUTH_SUCCESS") begin
                total_check = 5;
                summary_pass = chk_auth_to_unlocked + chk_b1_uart_tx +
                    chk_b2_uart_rx + chk_unlock_decode + chk_b2_unlock;
                if (!chk_auth_to_unlocked) begin errors++; `uvm_error("AUTH_SUMMARY", "Missing DUT transition AUTH_TRACK -> UNLOCKED") end
                if (!chk_b1_uart_tx)       begin errors++; `uvm_error("AUTH_SUMMARY", "Missing Board1 unlock UART TX packet") end
                if (!chk_b2_uart_rx)       begin errors++; `uvm_error("AUTH_SUMMARY", "Missing Board2 unlock UART RX packet") end
                if (!chk_unlock_decode)    begin errors++; `uvm_error("AUTH_SUMMARY", "Board2 did not decode the unlock packet") end
                if (!chk_b2_unlock)        begin errors++; `uvm_error("AUTH_SUMMARY", "Board2 unlock_state was not asserted") end
            end else begin
                total_check = 5;
                summary_pass = chk_fail_count_1 + chk_fail_count_2 +
                    chk_fail_count_3 + chk_auth_to_lockout + chk_alarm;
                if (!chk_fail_count_1)    begin errors++; `uvm_error("AUTH_SUMMARY", "DUT fail_count=1 was not observed") end
                if (!chk_fail_count_2)    begin errors++; `uvm_error("AUTH_SUMMARY", "DUT fail_count=2 was not observed") end
                if (!chk_fail_count_3)    begin errors++; `uvm_error("AUTH_SUMMARY", "DUT fail_count=3 was not observed") end
                if (!chk_auth_to_lockout) begin errors++; `uvm_error("AUTH_SUMMARY", "Missing DUT transition AUTH_TRACK -> LOCKOUT") end
                if (!chk_alarm)           begin errors++; `uvm_error("AUTH_SUMMARY", "DUT alarm was not asserted") end
            end
            summary_fail = total_check - summary_pass;

            if (!summary_printed) begin
                summary_printed = 1'b1;
                $display("[SCB] ================================================");
                $display("[SCB]          AUTH Verification Summary");
                $display("[SCB] ================================================");
                $display("");
                if (test_mode == "AUTH_SUCCESS") begin
                    $display("[SCB] AUTH_SUCCESS");
                    $display("[SCB] AUTH_TRACK -> UNLOCKED        : %s", pass_fail(chk_auth_to_unlocked));
                    $display("[SCB] Board1 UART TX                : %s", pass_fail(chk_b1_uart_tx));
                    $display("[SCB] Board2 UART RX                : %s", pass_fail(chk_b2_uart_rx));
                    $display("[SCB] Unlock Command Decode         : %s", pass_fail(chk_unlock_decode));
                    $display("[SCB] Board2 Unlock State           : %s", pass_fail(chk_b2_unlock));
                end else begin
                    $display("[SCB] AUTH_LOCKOUT");
                    $display("[SCB] Fail Count = 1                : %s", pass_fail(chk_fail_count_1));
                    $display("[SCB] Fail Count = 2                : %s", pass_fail(chk_fail_count_2));
                    $display("[SCB] Fail Count = 3                : %s", pass_fail(chk_fail_count_3));
                    $display("[SCB] AUTH_TRACK -> LOCKOUT         : %s", pass_fail(chk_auth_to_lockout));
                    $display("[SCB] Alarm Assert                  : %s", pass_fail(chk_alarm));
                end
                $display("");
                $display("[SCB] ------------------------------------------------");
                $display("[SCB] TOTAL CHECK : %0d", total_check);
                $display("[SCB] PASS        : %0d", summary_pass);
                $display("[SCB] FAIL        : %0d", summary_fail);
                $display("[SCB] ================================================");
            end
            if (errors==0) `uvm_info("AUTH_SCB",$sformatf("PASS checks=%0d",checks),UVM_LOW)
        end
    endfunction
endclass
