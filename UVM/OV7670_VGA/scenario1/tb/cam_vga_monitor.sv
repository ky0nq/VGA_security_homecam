class cam_vga_monitor extends uvm_monitor;
    `uvm_component_utils(cam_vga_monitor)
    virtual cam_vga_if vif;
    uvm_analysis_port #(cam_vga_seq_item) ap;
    function new(string name,uvm_component parent);
        super.new(name,parent); ap=new("ap",this);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual cam_vga_if)::get(this,"","vif",vif))
            `uvm_fatal("VIF","cam_vga_monitor needs vif")
    endfunction
    task camera_watch();
        cam_vga_seq_item tr;
        bit previous_active=0;
        bit previous_reset=1;
        forever begin
            @(posedge vif.pclk);
            // camera write port values consumed by RAM on this edge.
            if(vif.check_camera && (!vif.rst_n || vif.cam_href!==1'b0 ||
               vif.cam_vsync!==1'b0 || vif.cap_we!==1'b0 || previous_active || previous_reset)) begin
                tr=cam_vga_seq_item::type_id::create("camera_sample");
                tr.observation=OBS_CAMERA; tr.reset_active=!vif.rst_n;
                tr.href=vif.cam_href; tr.vsync=vif.cam_vsync;
                tr.camera_byte=vif.cam_data; tr.write_en=vif.cap_we;
                tr.write_addr=vif.cap_addr; tr.write_data=vif.cap_data;
                tr.pattern=pattern_e'(vif.pattern_id); tr.sample_time=$time;
                ap.write(tr);
            end
            previous_active=vif.cam_href || vif.cam_vsync;
            previous_reset=!vif.rst_n;
        end
    endtask
    task memory_watch();
        cam_vga_seq_item tr;
        forever begin
            @(posedge vif.pclk);
            if(vif.check_vga && !vif.link_camera_to_vga && vif.mem_we!==1'b0) begin
                tr=cam_vga_seq_item::type_id::create("memory_load");
                tr.observation=OBS_MEMORY; tr.reset_active=!vif.rst_n;
                tr.write_en=vif.mem_we; tr.write_addr=vif.mem_addr;
                tr.write_data=vif.mem_data; tr.pattern=pattern_e'(vif.pattern_id);
                tr.sample_time=$time; ap.write(tr);
            end
        end
    endtask
    task vga_watch();
        cam_vga_seq_item tr;
        longint unsigned cycles=0;
        bit reset_seen=0;
        forever begin
            @(posedge vif.clk);
            if(!vif.rst_n) begin
                cycles=0;
                if(!reset_seen) begin
                    tr=cam_vga_seq_item::type_id::create("reset");
                    tr.observation=OBS_RESET; tr.reset_active=1;
                    ap.write(tr);
                end
                reset_seen=1;
            end else begin
                reset_seen=0; cycles++;
                // enable rises on edge4; counter consumes on5.
                if(vif.check_vga && cycles>=5 && ((cycles-5)%4)==0) begin
                    tr=cam_vga_seq_item::type_id::create("vga_sample");
                    tr.observation=OBS_VGA;
                    tr.x=vif.x; tr.y=vif.y; tr.de=vif.de;
                    tr.read_addr=vif.rd_addr;
                    tr.full_frame_ready=vif.capture_complete;
                    tr.pattern=pattern_e'(vif.pattern_id); tr.sample_time=$time;
                    #1ps; tr.read_data=vif.rd_data; // RAM read for edge address
                    @(posedge vif.clk); cycles++;
                    #1ps; 
                    if(vif.rst_n) begin
                        tr.rgb=vif.rgb; tr.hsync=vif.h_sync; tr.vsync_out=vif.v_sync;
                        ap.write(tr);
                    end
                end
            end
        end
    endtask
    task run_phase(uvm_phase phase);
        fork camera_watch(); memory_watch(); vga_watch(); join
    endtask
endclass
