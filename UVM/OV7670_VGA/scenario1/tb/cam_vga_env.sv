class cam_vga_env extends uvm_env;
    `uvm_component_utils(cam_vga_env)
    cam_vga_agent agt;
    cam_vga_scoreboard scb;
    cam_vga_coverage cov;
    cam_vga_sccb sccb;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt=cam_vga_agent::type_id::create("agt",this);
        scb=cam_vga_scoreboard::type_id::create("scb",this);
        cov=cam_vga_coverage::type_id::create("cov",this);
        sccb=cam_vga_sccb::type_id::create("sccb",this);
    endfunction
    function void connect_phase(uvm_phase phase);
        agt.mon.ap.connect(scb.analysis_export);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
