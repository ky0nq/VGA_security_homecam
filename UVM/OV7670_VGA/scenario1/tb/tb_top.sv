`timescale 1ns/1ps
`ifndef FAST_SETUP
  `define FAST_SETUP 1
`endif
module tb_top;
    import uvm_pkg::*;
    import cam_vga_pkg::*;
    `include "uvm_macros.svh"
    logic clk=0, pclk=0;
    always #5ns clk=~clk;
    // TB-COV-03: Host-selected phase metadata
    int phase_ns=0;
    int have_phase_arg;
    initial begin
        $timeformat(-9,3," ns",12);
        have_phase_arg=$value$plusargs("PCLK_PHASE_NS=%d",phase_ns);
        // TB-COV-04: Reject invalid simulator configuration
        if(phase_ns<0 || phase_ns>39) $fatal(1,"PCLK_PHASE_NS must be 0..39");
        vif.camera_phase_ns=phase_ns;
        #(phase_ns*1ns);
        forever #20ns pclk=~pclk;
    end
    // Scales SCCB counters only, not Camera/VGA clocks. 
    localparam int CFG_HZ=(`FAST_SETUP!=0) ? 1000000 : 100000000;
    cam_vga_if vif(clk,pclk);

    // Camera capture pins -> RGB565 write stream.
    OV7670_MemCNTL u_camera_capture(
        .pclk(pclk),.rst_n(vif.rst_n),
        .cam_href(vif.cam_href),.cam_vsync(vif.cam_vsync),.cam_data(vif.cam_data),
        .we(vif.cap_we),.wAddr(vif.cap_addr),.wData(vif.cap_data));
    camera_clk_gen u_camera_clock(.clk(clk),.rst_n(vif.rst_n),.xclk(vif.xclk));

    // Explicit SCCB configuration request -> serial register writes.
    SCCB_setup_CNTL #(.CLK_FREQ_HZ(CFG_HZ),.I2C_FREQ_HZ(100000)) u_sccb(
        .clk(clk),.rst_n(vif.rst_n),.setup_start(vif.sccb_start),
        .setup_busy(vif.setup_busy),.setup_done(vif.setup_done),.setup_error(vif.setup_error),
        .scl(vif.cam_scl),.sda(vif.cam_sda));
    assign vif.sccb_master_state=u_sccb.U_I2C_MASTER.state;
    assign vif.sccb_master_step=u_sccb.U_I2C_MASTER.step;
    assign vif.sccb_setup_state=u_sccb.U_OV7670_SETUP_CNTL.state;

    // Known source image -> VGA timing / address / RGB conversion / output.
    wire fb_we=vif.link_camera_to_vga ? vif.cap_we : vif.mem_we;
    wire [16:0] fb_addr=vif.link_camera_to_vga ? vif.cap_addr : vif.mem_addr;
    wire [15:0] fb_data=vif.link_camera_to_vga ? vif.cap_data : vif.mem_data;
    framebuffer u_framebuffer(
        .wclk(pclk),.we(fb_we),.wAddr(fb_addr),.wData(fb_data),
        .rclk(clk),.rAddr(vif.rd_addr),.rData(vif.rd_data));
    logic raw_hsync, raw_vsync, delayed_hsync, delayed_vsync;
    logic [11:0] reader_rgb;
    VGA_Decoder u_vga_timing(
        .clk(clk),.rst_n(vif.rst_n),.h_sync(raw_hsync),.v_sync(raw_vsync),
        .x_pixel(vif.x),.y_pixel(vif.y),.de(vif.de));
    rom_reader_upscale u_vga_reader(
        .clk(clk),.rst_n(vif.rst_n),.de(vif.de),.x_pixel(vif.x),.y_pixel(vif.y),
        .addr(vif.rd_addr),.px_data(vif.rd_data),.o_rgb(reader_rgb));
    // Match sync to the real synchronous RAM/reader stage before output register.
    always_ff @(posedge clk or negedge vif.rst_n)
        if(!vif.rst_n) begin delayed_hsync<=1; delayed_vsync<=1; end
        else begin delayed_hsync<=raw_hsync; delayed_vsync<=raw_vsync; end
    vga_outreg u_vga_output(
        .clk(clk),.rst_n(vif.rst_n),
        .i_h_sync(delayed_hsync),.i_v_sync(delayed_vsync),.i_rgb(reader_rgb),
        .o_h_sync(vif.h_sync),.o_v_sync(vif.v_sync),.o_rgb(vif.rgb));

    initial begin
        vif.cfg_freq_hz=CFG_HZ; vif.sccb_freq_hz=100000;
        uvm_config_db#(virtual cam_vga_if)::set(null,"*","vif",vif);
        run_test();
    end
    initial begin
`ifdef FSDB
        string fsdb_file;
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="cam_tb.fsdb";
        if($test$plusargs("DUMP_WAVES")) begin
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0,tb_top);
            if($test$plusargs("DUMP_MEMORY")) $fsdbDumpMDA();
        end
`endif
    end
    ap_write_range: assert property(@(posedge pclk)
        disable iff(!vif.rst_n || !vif.check_camera)
        vif.cap_we |-> (!$isunknown({vif.cap_addr,vif.cap_data}) && vif.cap_addr<76800))
        else `uvm_error("SVA_WRITE","Unknown or out-of-range camera write")
    cp_write: cover property(@(posedge pclk)
        disable iff(!vif.rst_n || !vif.check_camera) vif.cap_we);
    ap_read_range: assert property(@(posedge clk)
        disable iff(!vif.rst_n || !vif.check_vga)
        vif.de |-> (!$isunknown(vif.rd_addr) && vif.rd_addr<76800))
        else `uvm_error("SVA_READ","Unknown or out-of-range read address")
    ap_blank: assert property(@(posedge clk)
        disable iff(!vif.rst_n || !vif.check_vga)
        ($past(vif.rst_n,2) && !$past(vif.de,2)) |-> (vif.rgb===12'h000))
        else `uvm_error("SVA_BLANK","RGB is not black after two-stage blanking latency")
    ap_sync_known: assert property(@(posedge clk)
        disable iff(!vif.rst_n || !vif.check_vga)
        !$isunknown({vif.h_sync,vif.v_sync}))
        else `uvm_error("SVA_SYNC","Unknown sync signal")
    cp_blank_to_active: cover property(@(posedge clk)
        disable iff(!vif.rst_n || !vif.check_vga) !vif.de ##1 vif.de);
    cp_vsync: cover property(@(posedge clk)
        disable iff(!vif.rst_n || !vif.check_vga) $fell(vif.v_sync));
      
    time xclk_rise=0;
    bit xclk_seen=0;
    always @(negedge vif.rst_n) xclk_seen=0;
    always @(posedge vif.xclk) if(vif.rst_n && vif.check_camera) begin
        if(xclk_seen && ($time-xclk_rise)!=40ns)
            `uvm_error("XCLK_PERIOD","Camera XCLK period must be 40 ns")
        xclk_rise=$time; xclk_seen=1;
    end
    always @(negedge vif.xclk)
        if(vif.rst_n && vif.check_camera && xclk_seen && ($time-xclk_rise)!=20ns)
            `uvm_error("XCLK_DUTY","Camera XCLK high time must be 20 ns")
    // Simulator timeout guard. It remains active and fails stalled runs.
    initial begin
        int timeout_ms;
        timeout_ms=10000;
        void'($value$plusargs("TIMEOUT_MS=%d",timeout_ms));
        if(timeout_ms<1) $fatal(1,"TIMEOUT_MS must be positive");
        #(time'(timeout_ms)*1ms);
        `uvm_fatal("WATCHDOG","Global simulation timeout; check progress before increasing TIMEOUT_MS")
    end
endmodule
