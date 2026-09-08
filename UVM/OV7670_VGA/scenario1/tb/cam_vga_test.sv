class cam_vga_sccb_reset_sequence extends uvm_sequence #(cam_vga_seq_item);
    `uvm_object_utils(cam_vga_sccb_reset_sequence)
    bit target_setup=0;
    int target_state=-1, target_step=-1;
    bit target_observed=0;
    function new(string name="sccb_reset_sequence"); super.new(name); endfunction
    task body();
        cam_vga_seq_item req;
        req=cam_vga_seq_item::type_id::create("reset_request");
        start_item(req);
        req.command=CMD_SCCB_RESET_AT;
        req.sccb_target_setup=target_setup;
        req.sccb_target_state=target_state;
        req.sccb_target_step=target_step;
        finish_item(req);
        target_observed=req.sccb_target_observed;
    endtask
endclass

class cam_vga_test extends uvm_test;
    `uvm_component_utils(cam_vga_test)
    cam_vga_env env;
    virtual cam_vga_if vif;
    string mode="camera_random";
    int num_frames=10;
    bit run_completed=0;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual cam_vga_if)::get(this,"","vif",vif))
            `uvm_fatal("VIF","cam_vga_test needs vif")
        void'($value$plusargs("NUM_FRAMES=%d",num_frames));
        if(num_frames<1) `uvm_fatal("NUM_FRAMES","NUM_FRAMES must be positive")
        env=cam_vga_env::type_id::create("env",this);
    endfunction
    task command(command_e cmd);
        cam_vga_command_sequence seq;
        seq=cam_vga_command_sequence::type_id::create("command_seq");
        seq.command=cmd; seq.start(env.agt.sqr);
    endtask
    task camera_reset_cases();
        longint unsigned before_writes;
        // After observing the initial raw reset at idle, verify recovery with a full frame.
        image_frame(RANDOM_PIXELS);

        command(CMD_VSYNC);
        before_writes=env.scb.camera_writes;
        command(CMD_RESET_ACTIVE);
        if(env.scb.camera_writes-before_writes!=7)
            `uvm_error("RESET_PREFIX","Active-line prefix must consume 7 writes; the 8th is cancelled by reset")
        image_frame(RANDOM_PIXELS);

        command(CMD_VSYNC);
        before_writes=env.scb.camera_writes;
        command(CMD_RESET_BETWEEN);
        if(env.scb.camera_writes-before_writes!=320)
            `uvm_error("RESET_PREFIX","Between-lines prefix must consume all 320 writes")
        image_frame(RANDOM_PIXELS);

        command(CMD_RESET); 
        image_frame(RANDOM_PIXELS);
        for(int location=0;location<4;location++) begin
            if(env.cov.reset_asserted_hits[location]==0 || env.cov.reset_recovered_hits[location]==0)
                `uvm_error("RESET_MISSING",$sformatf(
                    "location=%0d observed assert=%0d actual-write recovery=%0d",
                    location,env.cov.reset_asserted_hits[location],env.cov.reset_recovered_hits[location]))
        end
        if(env.cov.reset_cg.get_inst_coverage()<99.999)
            `uvm_error("RESET_COVERAGE","All four reset locations and their write recoveries must be observed")
        `uvm_info("RESET_RESULT",$sformatf("reset_cg=%.2f%%; four full recovery frames checked by the scoreboard",
            env.cov.reset_cg.get_inst_coverage()),UVM_LOW)
    endtask
    task wait_frames(int target);
        bit complete=0;
        fork : frame_watchdog
            begin wait(env.scb.full_vga_frames>=target); complete=1; end
            begin #40ms; end
        join_any
        disable frame_watchdog;
        if(!complete) `uvm_fatal("VGA_TIMEOUT","No complete scored VGA frame within 40 ms")
    endtask
    task image_frame(pattern_e p,bit errors=0);
        cam_vga_sequence seq;
        longint unsigned old_writes=env.scb.camera_writes;
        longint unsigned old_loads=env.scb.memory_loads;
        int target=env.scb.full_vga_frames+1;
        seq=cam_vga_sequence::type_id::create("image_sequence");
        seq.selected_pattern=p; seq.error_cases=errors;
        seq.memory_mode=vif.check_vga && !vif.link_camera_to_vga;
        `uvm_info("SCENARIO",$sformatf("scope=%s pattern=%s partial/reset cases=%0b",
            seq.memory_mode ? "VGA" : (vif.link_camera_to_vga ? "CAMERA_TO_VGA" : "CAMERA"),
            p.name(),errors),UVM_LOW)
        seq.start(env.agt.sqr);
        if(seq.memory_mode) begin
            env.scb.min_memory_loads+=76800;
            if(env.scb.memory_loads-old_loads!=76800)
                `uvm_error("LOAD_COUNT","VGA scenario must load exactly 76800 source pixels")
        end else begin
            env.scb.min_writes+=76800;
            if(!errors && env.scb.camera_writes-old_writes!=76800)
                `uvm_error("CAMERA_COUNT","Normal camera frame must produce exactly 76800 writes")
        end
        if(vif.check_vga) begin
            env.scb.min_frames++;
            wait_frames(target);
        end
        vif.capture_complete=0;
    endtask
    task wait_sccb(bit expected_error);
        bit complete=0;
        fork : sccb_watchdog
            begin wait(vif.setup_done===1 || vif.setup_error===1); complete=1; end
            begin #150ms; end
        join_any
        disable sccb_watchdog;
        if(!complete) `uvm_fatal("SCCB_TIMEOUT","Explicit SCCB request did not finish within 150 ms")
        repeat(20) @(negedge vif.clk);
        if(expected_error) begin
            if(vif.setup_error!==1 || vif.setup_done!==0 || vif.setup_busy!==0)
                `uvm_error("SCCB_STATUS","Injected NACK must give error=1 done=0 busy=0")
        end else if(vif.setup_error!==0 || vif.setup_done!==1 || vif.setup_busy!==0)
            `uvm_error("SCCB_STATUS","ACK setup must give done=1 error=0 busy=0")
    endtask
    task sccb_cases();
        env.sccb.min_completed_setups=5;
        env.sccb.min_error_setups=3;
        env.sccb.min_reset_interruptions=1;
        command(CMD_SCCB_START); wait_sccb(0);
        for(int byte_index=0;byte_index<3;byte_index++) begin
            vif.nack_transaction=0; vif.nack_byte=byte_index;
            command(CMD_RESET);
            `uvm_info("SCENARIO",$sformatf("SCCB NACK at byte %0d",byte_index),UVM_LOW)
            command(CMD_SCCB_START); wait_sccb(1);
            repeat(100) @(negedge vif.clk);
            if(vif.setup_error!==1) `uvm_error("SCCB_STICKY","SCCB error was not retained")
            // Retry without reset to verify the ERROR → LOAD transition.
            vif.nack_transaction=-1; vif.nack_byte=-1;
            `uvm_info("SCENARIO",$sformatf("SCCB retry without reset after byte-%0d NACK",byte_index),UVM_LOW)
            command(CMD_SCCB_START); wait_sccb(0);
        end
        vif.nack_transaction=-1; vif.nack_byte=-1;
        command(CMD_RESET); command(CMD_SCCB_START);
        wait(vif.setup_busy===1);
        repeat(3) @(posedge vif.cam_scl);
        command(CMD_RESET);
        command(CMD_SCCB_START); wait_sccb(0);
    endtask
    task sccb_reset_one(bit setup_target,int state_target,int step_target=-1);
        cam_vga_sccb_reset_sequence seq;
        int unsigned before_completed;
        seq=cam_vga_sccb_reset_sequence::type_id::create("sccb_reset_seq");
        seq.target_setup=setup_target;
        seq.target_state=state_target;
        seq.target_step=step_target;
        // Enter ERROR through a real first-byte NACK without forcing state.
        vif.nack_transaction=(setup_target && state_target==7) ? 0 : -1;
        vif.nack_byte=(setup_target && state_target==7) ? 0 : -1;
        seq.start(env.agt.sqr);
        if(!seq.target_observed)
            `uvm_fatal("SCCB_RESET_NOT_OBSERVED","Reset command did not observe its requested target")
        vif.nack_transaction=-1; vif.nack_byte=-1;
        before_completed=env.sccb.completed_setups;
        command(CMD_SCCB_START); wait_sccb(0);
        if(env.sccb.completed_setups!=before_completed+1)
            `uvm_error("SCCB_RESET_RECOVERY","Each targeted reset must be followed by one wire-checked 67-write setup")
        `uvm_info("SCCB_RESET_RECOVERY",$sformatf(
            "target=%s state=%0d step=%0d; post-reset complete setups %0d -> %0d; checker errors=%0d",
            setup_target ? "SETUP" : "MASTER",state_target,step_target,
            before_completed,env.sccb.completed_setups,env.sccb.errors),UVM_LOW)
    endtask
    task sccb_reset_cases();
        env.sccb.min_completed_setups=18;
        env.sccb.min_error_setups=0;
        env.sccb.min_reset_interruptions=1;
        for(int state_target=1;state_target<=9;state_target++)
            sccb_reset_one(0,state_target);
        for(int state_target=1;state_target<=7;state_target++)
            sccb_reset_one(1,state_target);
        // Verify reset transitions 1→0 and 2→0 in addition to normal bit cycling 3→0.
        sccb_reset_one(0,2,1);
        sccb_reset_one(0,2,2);
    endtask
    virtual task sccb_fault_cases();
        `uvm_fatal("SCCB_FAULT_MODE","Select sccb_fault_test for fault injection")
    endtask
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        vif.check_camera=(mode=="camera" || mode=="camera_random" ||
                          mode=="camera_error" || mode=="camera_reset" || mode=="path");
        vif.check_vga=(mode=="vga" || mode=="vga_random" ||
                       mode=="vga_gradient" || mode=="vga_reset" || mode=="path");
        vif.check_sccb=(mode=="sccb" || mode=="sccb_reset" || mode=="sccb_fault");
        vif.link_camera_to_vga=(mode=="path");
        env.scb.min_frames=0; env.scb.min_writes=0; env.scb.min_memory_loads=0;
        `uvm_info("TEST_CONFIG",$sformatf("mode=%s NUM_FRAMES=%0d phase=%0d ns cfg_freq=%0d Hz",
            mode,num_frames,vif.camera_phase_ns,vif.cfg_freq_hz),UVM_LOW)
        command(CMD_RESET_RAW);
        case(mode)
            "camera_random": repeat(num_frames) image_frame(RANDOM_PIXELS);
            "camera_error": repeat(10) image_frame(RANDOM_PIXELS,1);
            "camera_reset": camera_reset_cases();
            "vga_random": repeat(num_frames) image_frame(RANDOM_PIXELS);
            "vga_gradient": begin image_frame(H_GRADIENT); image_frame(V_GRADIENT); end
            "vga_reset": begin
                image_frame(RANDOM_PIXELS);
                repeat(10) @(negedge vif.clk);
                command(CMD_RESET);
                image_frame(H_GRADIENT);
            end
            "path": image_frame(RANDOM_PIXELS);
            "sccb": sccb_cases();
            "sccb_reset": sccb_reset_cases();
            "sccb_fault": sccb_fault_cases();
            "camera","vga": begin
                repeat(10) begin
                    image_frame(COLOR_BARS);
                    image_frame(H_GRADIENT);
                    image_frame(V_GRADIENT);
                    image_frame(CHECKERBOARD);
                    image_frame(RANDOM_PIXELS);
                    image_frame(QUADRANTS);
                    if(mode=="vga") begin
                        repeat(10) @(negedge vif.clk);
                        command(CMD_RESET);
                    end
                    image_frame(CHANNEL_WALK);
                    if(mode=="camera") image_frame(RANDOM_PIXELS,1);
                end
            end
            default: `uvm_fatal("TEST_MODE","Unknown functional-block test mode")
        endcase
        repeat(20) @(negedge vif.pclk);
        run_completed=1;
        phase.drop_objection(this);
    endtask
            
    function void report_phase(uvm_phase phase);
        uvm_report_server server;
        int error_count, fatal_count;
        bit passed;
        string result_msg;
        super.report_phase(phase);
        server=uvm_report_server::get_server();
        error_count=server.get_severity_count(UVM_ERROR);
        fatal_count=server.get_severity_count(UVM_FATAL);
        passed=run_completed &&
            (vif.check_camera || vif.check_vga || vif.check_sccb) &&
            error_count==0 && fatal_count==0 &&
            env.scb.errors==0 && env.sccb.errors==0;
        if(vif.check_camera)
            passed &= env.scb.camera_writes>0;
        if(vif.check_vga) begin
            passed &= env.scb.full_vga_frames>0;
            if(!vif.link_camera_to_vga)
                passed &= env.scb.memory_loads>0;
        end
        if(vif.check_sccb)
            passed &= env.sccb.completed_setups>0 && env.sccb.total_transactions>0;
        // error_setups counts expected NACK outcomes.
        result_msg=$sformatf({
            "%s test=%s completed=%0b errors=%0d fatals=%0d ",
            "camera_writes=%0d vga_frames=%0d sccb_completed=%0d ",
            "mismatches=%0d sccb_checker_errors=%0d"},
            passed ? "PASS" : "FAIL",get_type_name(),run_completed,
            error_count,fatal_count,env.scb.camera_writes,
            env.scb.full_vga_frames,env.sccb.completed_setups,
            env.scb.errors,env.sccb.errors);
        if(passed)
            `uvm_info("TEST_RESULT",result_msg,UVM_NONE)
        else
            `uvm_error("TEST_RESULT",result_msg)
    endfunction
endclass

class camera_test extends cam_vga_test;
    `uvm_component_utils(camera_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="camera"; endfunction
endclass
class camera_random_test extends cam_vga_test;
    `uvm_component_utils(camera_random_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="camera_random"; endfunction
endclass
class camera_error_test extends cam_vga_test;
    `uvm_component_utils(camera_error_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="camera_error"; endfunction
endclass
class camera_reset_test extends cam_vga_test;
    `uvm_component_utils(camera_reset_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="camera_reset"; endfunction
endclass
class vga_test extends cam_vga_test;
    `uvm_component_utils(vga_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="vga"; endfunction
endclass
class vga_random_test extends cam_vga_test;
    `uvm_component_utils(vga_random_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="vga_random"; endfunction
endclass
class vga_gradient_test extends cam_vga_test;
    `uvm_component_utils(vga_gradient_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="vga_gradient"; endfunction
endclass
class vga_reset_test extends cam_vga_test;
    `uvm_component_utils(vga_reset_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="vga_reset"; endfunction
endclass
class sccb_test extends cam_vga_test;
    `uvm_component_utils(sccb_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="sccb"; endfunction
endclass
class sccb_reset_test extends cam_vga_test;
    `uvm_component_utils(sccb_reset_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="sccb_reset"; endfunction
endclass
class camera_to_vga_test extends cam_vga_test;
    `uvm_component_utils(camera_to_vga_test)
    function new(string name,uvm_component parent); super.new(name,parent); mode="path"; endfunction
endclass
