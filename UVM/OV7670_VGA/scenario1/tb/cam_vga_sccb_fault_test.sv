// Deliberate white-box robustness scenarios, separate from pin-level tests.
// X injection exercises defensive RTL simulation paths; it is NOT a normal
// camera stimulus or a claim of silicon fault tolerance / formal reachability.
class sccb_fault_test extends cam_vga_test;
    `uvm_component_utils(sccb_fault_test)
    localparam string MASTER = "tb_top.u_sccb.U_I2C_MASTER";
    localparam string SETUP  = "tb_top.u_sccb.U_OV7670_SETUP_CNTL";
    int unsigned recovery_checks = 0;

    function new(string name, uvm_component parent);
        super.new(name,parent);
        mode="sccb_fault";
    endfunction

    function void poke(string path, uvm_hdl_data_t value);
        if (!uvm_hdl_deposit(path,value))
            `uvm_fatal("SCCB_HDL_ACCESS",$sformatf("Cannot deposit %s; keep -debug_access+all and UVM DPI enabled",path))
    endfunction

    function void expect_value(string path, uvm_hdl_data_t expected, int width);
        uvm_hdl_data_t actual;
        if (!uvm_hdl_read(path,actual))
            `uvm_fatal("SCCB_HDL_ACCESS",$sformatf("Cannot read %s",path))
        for (int i=0;i<width;i++) begin
            if (actual[i] !== expected[i]) begin
                `uvm_error("SCCB_RECOVERY",$sformatf("%s bit %0d: expected=%b actual=%b",path,i,expected[i],actual[i]))
                return;
            end
        end
    endfunction

    function void check_master_idle();
        int tick_div, count_width;
        tick_div=vif.cfg_freq_hz/(4*vif.sccb_freq_hz);
        count_width=(tick_div<=1) ? 1 : $clog2(tick_div);
        expect_value({MASTER,".state"},0,4);
        expect_value({MASTER,".busy"},0,1);
        expect_value({MASTER,".done"},0,1);
        expect_value({MASTER,".scl"},1,1);
        expect_value({MASTER,".sda_drive_low"},0,1);
        expect_value({MASTER,".clk_cnt"},0,count_width);
        expect_value({MASTER,".step"},0,2);
        expect_value({MASTER,".bit_cnt"},0,3);
        if (vif.cam_scl !== 1'b1 || vif.cam_sda !== 1'b1)
            `uvm_error("SCCB_RECOVERY","Recovered master must release the pulled-up bus")
    endfunction

    task inject_master_fault(int state_value, bit unknown_step);
        int tick_div;
        tick_div=vif.cfg_freq_hz/(4*vif.sccb_freq_hz);
        if (tick_div<1) tick_div=1;
        // Deposit after the wire monitor's negedge sample; let one rising
        // edge execute the recovery branch. Never force the expected result.
        @(negedge vif.clk); #1ns;
        poke({MASTER,".state"},state_value);
        if (unknown_step) poke({MASTER,".step"},'x);
        else              poke({MASTER,".step"},3);
        poke({MASTER,".clk_cnt"},tick_div-1);
        poke({MASTER,".bit_cnt"},7);
        poke({MASTER,".busy"},1);
        poke({MASTER,".done"},1);
        @(posedge vif.clk); #1ns;
        check_master_idle();
        recovery_checks++;
        `uvm_info("SCCB_FAULT_RECOVERY",$sformatf("state=%0d unknown_step=%0b: recovery outputs checked",state_value,unknown_step),UVM_LOW)
    endtask

    task checked_setup();
        int unsigned before_completed;
        before_completed=env.sccb.completed_setups;
        command(CMD_SCCB_START); wait_sccb(0);
        if (env.sccb.completed_setups != before_completed+1)
            `uvm_error("SCCB_FAULT_RECOVERY","Recovery must permit a full independent wire-checked 67-write setup")
    endtask

    virtual task sccb_fault_cases();
        int unsigned before_transactions, before_completed;
        env.sccb.min_completed_setups=2;

        // 4-bit master state has unused encodings; each phase case has only
        // 0..3 as valid values. X is required to reach its defensive default.
        inject_master_fault(15,0);
        for (int state_value=1;state_value<=8;state_value++)
            inject_master_fault(state_value,1);

        // Setup has all eight binary states, so this is explicitly X recovery.
        @(negedge vif.clk); #1ns;
        poke({SETUP,".state"},'x);
        poke({SETUP,".config_idx"},127);
        poke({SETUP,".delay_cnt"},1);
        @(posedge vif.clk); #1ns;
        expect_value({SETUP,".state"},0,3);
        expect_value({SETUP,".config_idx"},0,7);
        expect_value({SETUP,".delay_cnt"},0,$clog2((vif.cfg_freq_hz/1000)*30+1));
        expect_value({SETUP,".i2c_start"},0,1);
        if ({vif.setup_busy,vif.setup_done,vif.setup_error} !== 3'b000)
            `uvm_error("SCCB_RECOVERY","Invalid setup state must clear status")
        recovery_checks++;
        checked_setup();

        // Interface backpressure: the sole-owner integration normally reaches
        // SEND with busy=0. Emulate an occupied master, verify no early request,
        // release it, and check every real byte on the wire as usual.
        command(CMD_RESET_RAW);
        before_transactions=env.sccb.total_transactions;
        before_completed=env.sccb.completed_setups;
        @(negedge vif.clk); #1ns;
        if (!uvm_hdl_force({MASTER,".busy"},1))
            `uvm_fatal("SCCB_HDL_ACCESS","Cannot inject master backpressure")
        command(CMD_SCCB_START);
        repeat (12) begin
            @(posedge vif.clk); #1ns;
            expect_value({SETUP,".state"},2,3); // SEND
            expect_value({SETUP,".i2c_start"},0,1);
            if (vif.setup_busy !== 1'b1 || vif.cam_scl !== 1'b1 || vif.cam_sda !== 1'b1)
                `uvm_error("SCCB_BACKPRESSURE","SEND must wait with idle bus and setup_busy=1")
        end
        if (env.sccb.total_transactions != before_transactions)
            `uvm_error("SCCB_BACKPRESSURE","A wire transaction started while the master was busy")
        @(negedge vif.clk); #1ns;
        if (!uvm_hdl_release({MASTER,".busy"}))
            `uvm_fatal("SCCB_HDL_ACCESS","Cannot release master backpressure")
        wait_sccb(0);
        if (env.sccb.completed_setups != before_completed+1)
            `uvm_error("SCCB_BACKPRESSURE","Releasing busy must complete a wire-checked 67-write setup")
        recovery_checks++;
        if (recovery_checks != 11)
            `uvm_error("SCCB_FAULT_COUNT","All 11 recovery/backpressure scenarios must run")
        `uvm_info("SCCB_FAULT_RESULT",$sformatf("scenarios=%0d completed_setups=%0d checker_errors=%0d; coverage must be measured separately",
            recovery_checks,env.sccb.completed_setups,env.sccb.errors),UVM_LOW)
    endtask
endclass
