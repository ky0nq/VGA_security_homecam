// Coverage of authentication states, UART, decoding, and control inputs by lock state.
class AuthCoverage extends uvm_component;
    `uvm_component_utils(AuthCoverage)

    virtual vga_if b1;
    virtual vga_if b2;
    virtual uart_if uart2;
    virtual control_if control;
    string test_mode;
    bit relock_seen;
    int previous_fail_count;

    covergroup auth_result_cg with function sample(int result_event);
        option.per_instance = 1;
        cp_result: coverpoint result_event {
            bins unlock_success  = {0};
            bins failure_1       = {1};
            bins failure_2       = {2};
            bins failure_3_alarm = {3};
            illegal_bins undefined = default;
        }
    endgroup

    covergroup uart_cg with function sample(bit direction,
                                             logic [7:0] packet);
        option.per_instance = 1;
        cp_direction: coverpoint direction {
            bins b1_to_b2={0}; bins b2_to_b1={1};
        }
        cp_packet: coverpoint packet {
            bins lock_status={8'h00};
            bins unlock_status[]={8'h40,8'h41,8'h42,8'h43};
            bins buttons[]={8'h47,8'h4b,8'h53,8'h63};
            bins remote_relock={8'h80};
            illegal_bins undefined=default;
        }
        direction_by_packet: coverpoint {direction,packet} {
            bins b1_lock={9'h000};
            bins b1_unlock[]={9'h040,9'h041,9'h042,9'h043};
            bins b1_buttons[]={9'h047,9'h04b,9'h053,9'h063};
            bins b2_relock={9'h180};
            illegal_bins wrong_direction=default;
        }
    endgroup

    covergroup control_cg with function sample(bit unlocked, bit up, bit down,
                                                bit left, bit right,
                                                bit zoom, bit effect);
        option.per_instance = 1;
        cp_lock: coverpoint unlocked {
            bins locked={0}; bins unlocked={1};
        }
        cp_button: coverpoint {up,down,left,right} {
            bins none={4'b0000}; bins up={4'b1000}; bins down={4'b0100};
            bins left={4'b0010}; bins right={4'b0001};
            illegal_bins multi_button=default;
        }
        cp_zoom: coverpoint zoom { bins off={0}; bins on={1}; }
        cp_effect: coverpoint effect { bins off={0}; bins on={1}; }
        button_by_lock: cross cp_lock, cp_button;
        effect_by_lock: cross cp_lock, cp_zoom, cp_effect;
    endgroup

    covergroup state_cg with function sample(logic [1:0] state,
                                               bit auth_sw, bit alarm,
                                               bit remote_relock);
        option.per_instance = 1;
        cp_state: coverpoint state {
            bins idle={0}; bins auth_track={1};
            bins unlocked={2}; bins lockout={3};
        }
        cp_transition: coverpoint state {
            bins idle_to_auth=(0=>1); bins auth_to_unlocked=(1=>2);
            bins unlocked_to_idle=(2=>0); bins auth_to_lockout=(1=>3);
        }
        cp_lockout_auth_toggle: coverpoint auth_sw iff (state==3) {
            bins off_to_on=(0=>1);
        }
        cp_alarm: coverpoint alarm iff (state==3) { bins asserted={1}; }
        cp_remote_relock: coverpoint remote_relock { bins received={1}; }
    endgroup

    // Cover control stimuli in initial lock, unlock, relock, and lockout phases.
    // This samples expected forwarding; the scoreboard checks actual UART behavior.
    covergroup gate_cg with function sample(int phase, int input_class,
                                             bit should_forward);
        option.per_instance = 1;
        cp_phase_result: coverpoint {phase[1:0],should_forward} {
            bins initial_lock_block={3'b000};
            bins unlocked_forward={3'b011};
            bins relocked_block={3'b100};
            bins lockout_block={3'b110};
            illegal_bins invalid=default;
        }
        cp_input_class: coverpoint input_class {
            bins button={0}; bins level_control={1};
        }
        input_class_by_phase: cross cp_phase_result, cp_input_class;
    endgroup

    covergroup decode_cg with function sample(logic [7:0] packet,
                                               bit level_match,
                                               bit button_match);
        option.per_instance = 1;
        cp_packet: coverpoint packet {
            bins lock_status={8'h00};
            bins levels[]={8'h40,8'h41,8'h42,8'h43};
            bins buttons[]={8'h47,8'h4b,8'h53,8'h63};
        }
        cp_level_match: coverpoint level_match {
            bins pass={1}; illegal_bins fail={0};
        }
        cp_button_match: coverpoint button_match {
            bins pass={1}; illegal_bins fail={0};
        }
    endgroup

    function new(string name="AuthCoverage", uvm_component parent=null);
        super.new(name,parent);
        auth_result_cg=new(); uart_cg=new(); control_cg=new();
        state_cg=new(); gate_cg=new(); decode_cg=new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(string)::get(this,"","test_mode",test_mode));
        if (!uvm_config_db#(virtual vga_if)::get(this,"","board1_vif",b1))
            `uvm_fatal("AUTH_COV","Missing Board1 observation interface")
        if (!uvm_config_db#(virtual vga_if)::get(this,"","board2_vif",b2))
            `uvm_fatal("AUTH_COV","Missing Board2 observation interface")
        if (!uvm_config_db#(virtual uart_if)::get(this,"","uart2_vif",uart2))
            `uvm_fatal("AUTH_COV","Missing Board2 UART interface")
        if (!uvm_config_db#(virtual control_if)::get(this,"","control_vif",control))
            `uvm_fatal("AUTH_COV","Missing control interface")
    endfunction

    task run_phase(uvm_phase phase);
        if ((test_mode != "AUTH_SUCCESS") &&
            (test_mode != "AUTH_LOCKOUT")) return;
        fork
            forever begin
                bit unlock_covered;
                @(posedge b1.clk);
                state_cg.sample(b1.control_state,control.auth_sw,b1.alarm,
                    b1.uart_rx_done && (b1.uart_rx_data==8'h80));
                if (b1.unlock_state && !unlock_covered) begin
                    unlock_covered=1; auth_result_cg.sample(0);
                end
                if (b1.fail_count > previous_fail_count) begin
                    previous_fail_count=b1.fail_count;
                    auth_result_cg.sample(b1.fail_count);
                end
                if (b1.uart_rx_done && (b1.uart_rx_data==8'h80))
                    relock_seen=1;
            end
            forever begin
                logic [3:0] observed_button;
                logic [7:0] packet;
                @(posedge b2.clk);
                if (b2.uart_rx_done) begin
                    packet=b2.uart_rx_data;
                    observed_button=b2.button_pulse;
                    uart_cg.sample(0,packet);
                    #1ns;
                    decode_cg.sample(packet,
                        {b2.unlock_state,b2.effect_sel,b2.zoom_en} ===
                            {packet[6],packet[1:0]},
                        observed_button === packet[5:2]);
                end
            end
            forever begin
                logic [7:0] packet;
                uart2.receive_byte(packet);
                uart_cg.sample(1,packet);
            end
            forever begin
                @(posedge control.btn_U or posedge control.btn_D or
                  posedge control.btn_L or posedge control.btn_R or
                  control.zoom_en or control.effect_en);
                control_cg.sample(b1.unlock_state,control.btn_U,control.btn_D,
                    control.btn_L,control.btn_R,control.zoom_en,control.effect_en);
                gate_cg.sample(
                    (b1.control_state==3) ? 3 :
                    (relock_seen ? 2 : (b1.unlock_state ? 1 : 0)),
                    (control.btn_U || control.btn_D ||
                     control.btn_L || control.btn_R) ? 0 : 1,
                    b1.unlock_state && !relock_seen);
            end
        join
    endtask

    function void report_phase(uvm_phase phase);
        Coverage board1_cov;
        Coverage board2_cov;
        real sccb_pct;
        real internal_sccb_pct;
        super.report_phase(phase);
        if (!$cast(board1_cov,uvm_top.find("uvm_test_top.env.board1_cov")) ||
            !$cast(board2_cov,uvm_top.find("uvm_test_top.env.board2_cov"))) begin
            `uvm_error("AUTH_COV","Unable to find board coverage components")
            return;
        end
        sccb_pct = (board1_cov.sccb_cg.get_inst_coverage() +
                    board2_cov.sccb_cg.get_inst_coverage()) / 2.0;
        internal_sccb_pct =
            (board1_cov.internal_sccb_cg.get_inst_coverage() +
             board2_cov.internal_sccb_cg.get_inst_coverage()) / 2.0;
        $display("[COV] ================================================");
        $display("[COV]          Functional Coverage Result");
        $display("[COV] ================================================");
        $display("[COV] Authentication Result : %0.2f %%", auth_result_cg.get_inst_coverage());
        $display("[COV] Control               : %0.2f %%", control_cg.get_inst_coverage());
        $display("[COV] Decode                : %0.2f %%", decode_cg.get_inst_coverage());
        $display("[COV] Gate                  : %0.2f %%", gate_cg.get_inst_coverage());
        $display("[COV] State                 : %0.2f %%", state_cg.get_inst_coverage());
        $display("[COV] UART                  : %0.2f %%", uart_cg.get_inst_coverage());
        $display("[COV] Internal SCCB         : %0.2f %%", internal_sccb_pct);
        $display("[COV] SCCB                  : %0.2f %%", sccb_pct);
        $display("[COV] ================================================");
    endfunction
endclass
