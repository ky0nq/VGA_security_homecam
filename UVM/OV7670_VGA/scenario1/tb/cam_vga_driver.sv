class cam_vga_driver extends uvm_driver #(cam_vga_seq_item);
    `uvm_component_utils(cam_vga_driver)
    virtual cam_vga_if vif;
    function new(string name, uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cam_vga_if)::get(this,"","vif",vif))
            `uvm_fatal("VIF", "cam_vga_driver needs vif")
    endfunction
    // Camera pin changes precede the DUT's next rising-edge sample.
    task camera_cycle(bit href, bit vsync, bit [7:0] data);
        @(negedge vif.pclk);
        vif.cam_href=href; vif.cam_vsync=vsync; vif.cam_data=data;
    endtask
    task apply_reset(bit align_pclk=1);
        if(align_pclk) @(negedge vif.pclk);
        vif.rst_n=0; vif.capture_complete=0;
        vif.sccb_epoch++;
        vif.cam_href=0; vif.cam_vsync=0; vif.cam_data=0;
        vif.mem_we=0; vif.mem_addr=0; vif.mem_data=0; vif.sccb_start=0;
        repeat(20) @(negedge vif.pclk);
        #1ps; vif.rst_n=1;
        repeat(4) @(negedge vif.pclk);
    endtask
    task sccb_reset_at(cam_vga_seq_item req);
        time deadline;
        int start_cycles;
        bit state_match, step_match;
        if(!vif.check_sccb)
            `uvm_fatal("SCCB_RESET_SCOPE","Directed SCCB reset requires the SCCB checker")
        if((req.sccb_target_setup && !(req.sccb_target_state inside {[1:7]})) ||
           (!req.sccb_target_setup && !(req.sccb_target_state inside {[1:9]})) ||
           !(req.sccb_target_step inside {[-1:3]}) ||
           (req.sccb_target_setup && req.sccb_target_step!=-1))
            `uvm_fatal("SCCB_RESET_CONFIG","Invalid SCCB reset state/step target")
        req.sccb_target_observed=0;
        // Start and observe in one command: LOAD/SEND/NEXT last only 10 ns.
        @(negedge vif.clk); #1ps;
        vif.sccb_start=1;
        start_cycles=0;
        deadline=$time+150ms;
        while(!req.sccb_target_observed && $time<deadline) begin
            @(negedge vif.clk); #1ps;
            start_cycles++;
            if(start_cycles==6) vif.sccb_start=0;
            state_match=req.sccb_target_setup ?
                (vif.sccb_setup_state === 3'(req.sccb_target_state)) :
                (vif.sccb_master_state === 4'(req.sccb_target_state));
            step_match=(req.sccb_target_step==-1) ||
                (vif.sccb_master_step === 2'(req.sccb_target_step));
            if(vif.rst_n===1'b1 && state_match && step_match) begin
                req.sccb_target_observed=1;
                `uvm_info("SCCB_RESET_TARGET",$sformatf(
                    "observed target=%s state=%0d requested_step=%0d; actual master=%0d step=%0d setup=%0d at %0t; assert external rst_n",
                    req.sccb_target_setup ? "SETUP" : "MASTER",
                    req.sccb_target_state,req.sccb_target_step,
                    vif.sccb_master_state,vif.sccb_master_step,vif.sccb_setup_state,$time),UVM_LOW)
                apply_reset(0);
                if(vif.sccb_master_state!==4'd0 || vif.sccb_setup_state!==3'd0 ||
                   vif.setup_busy!==1'b0 || vif.setup_done!==1'b0 || vif.setup_error!==1'b0 ||
                   vif.cam_scl!==1'b1 || vif.cam_sda!==1'b1)
                    `uvm_error("SCCB_RESET_IDLE","Reset must restore idle FSMs, idle bus and cleared terminal status")
            end
        end
        if(!req.sccb_target_observed) begin
            vif.sccb_start=0;
            `uvm_fatal("SCCB_RESET_TARGET_TIMEOUT",$sformatf(
                "No observed %s state=%0d step=%0d within 150 ms",
                req.sccb_target_setup ? "SETUP" : "MASTER",
                req.sccb_target_state,req.sccb_target_step))
        end
    endtask
    task run_phase(uvm_phase phase);
        cam_vga_seq_item req;
        forever begin
            seq_item_port.get_next_item(req);
            if(req.command inside {CMD_LINE,CMD_MEM_LINE,CMD_VSYNC})
                vif.pattern_id=int'(req.pattern);
            case(req.command)
                CMD_RESET: begin
                    // Legacy partial-pixel reset
                    if(vif.check_camera && vif.rst_n) camera_cycle(1,0,8'ha5);
                    apply_reset();
                end
                CMD_RESET_RAW: apply_reset(); 
                CMD_RESET_ACTIVE: begin
                    // Called after VSYNC. HREF remains high, with an even byte count.
                    for(int x=0;x<8;x++) begin
                        camera_cycle(1,0,8'h20+x);
                        camera_cycle(1,0,8'h80+x);
                    end
                    apply_reset();
                end
                CMD_RESET_BETWEEN: begin
                    // A complete line, followed by sampled HREF-low blanking.
                    for(int x=0;x<320;x++) begin
                        camera_cycle(1,0,8'hf8);
                        camera_cycle(1,0,8'h00);
                    end
                    repeat(4) camera_cycle(0,0,0);
                    apply_reset();
                end
                CMD_VSYNC: begin
                    vif.capture_complete=0;
                    repeat(2) camera_cycle(0,1,0);
                    repeat(2) camera_cycle(0,0,0);
                end
                CMD_LINE: begin
                    vif.capture_complete=0;
                    for(int x=0;x<req.pixel_count;x++) begin
                        camera_cycle(1,0,req.pixels[x%320][15:8]);
                        camera_cycle(1,0,req.pixels[x%320][7:0]);
                    end
                    repeat(req.gap_cycles) camera_cycle(0,0,8'h5a);
                end
                CMD_MEM_LINE: begin
                    vif.capture_complete=0;
                    for(int x=0;x<320;x++) begin
                        @(negedge vif.pclk);
                        vif.mem_we=1;
                        vif.mem_addr=req.line_number*320+x;
                        vif.mem_data=req.pixels[x];
                    end
                    @(negedge vif.pclk); vif.mem_we=0;
                    repeat(req.gap_cycles) @(negedge vif.pclk);
                end
                CMD_PARTIAL_HREF: begin
                    camera_cycle(1,0,8'hab);
                    repeat(3) camera_cycle(0,0,8'hcd);
                end
                CMD_PARTIAL_VSYNC: begin
                    camera_cycle(1,0,8'h12);
                    repeat(2) camera_cycle(0,1,8'h34);
                    repeat(2) camera_cycle(0,0,0);
                end
                CMD_SCCB_START: begin
                    @(negedge vif.clk); vif.sccb_start=1;
                    repeat(6) @(negedge vif.clk);
                    vif.sccb_start=0;
                end
                CMD_SCCB_RESET_AT: sccb_reset_at(req);
                CMD_FRAME_DONE: begin
                    repeat(4) camera_cycle(0,0,0);
                    vif.capture_complete=1;
                end
                CMD_IDLE: repeat(req.gap_cycles) camera_cycle(0,0,8'hc3);
                default: `uvm_fatal("CMD", "Unknown block stimulus command")
            endcase
            seq_item_port.item_done();
        end
    endtask
endclass
