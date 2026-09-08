class Driver extends uvm_driver #(transaction);
    `uvm_component_utils(Driver)

    virtual sccb_if sccb_vif;
    virtual uart_if uart_vif;
    virtual camera_if camera_vif;
    virtual control_if control_vif;

    transaction tr;

    function new(string name = "Driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sccb_if)::get( this, "", "sccb_vif", sccb_vif)) begin
            `uvm_fatal("DRV", "Unable to get sccb_vif")
        end
        if (!uvm_config_db#(virtual uart_if)::get(
                this, "", "uart_vif", uart_vif)) begin
            `uvm_fatal("DRV", "Unable to get uart_vif")
        end
        if (!uvm_config_db#(virtual camera_if)::get( this, "", "camera_vif", camera_vif)) begin
            `uvm_fatal("DRV", "Unable to get camera_vif")
        end
        // Drive Board 1 controls directly; Board 2 receives them over UART.
        void'(uvm_config_db#(virtual control_if)::get(
            this, "", "control_vif", control_vif));
    endfunction

    virtual task run_phase(uvm_phase phase);
        init_signals();
        forever begin
            seq_item_port.get_next_item(tr);
            camera_vif.drive(tr.cam_href, tr.cam_vsync, tr.cam_data);
            case (tr.mode)
                TEST_START: init_signals();
                TEST_END  : drive_idle();
                RESET     : drive_reset();
                BUTTON_PRESS: begin
                    if (control_vif != null)
                        control_vif.drive(
                            tr.btn_R, tr.btn_L, tr.btn_D, tr.btn_U,
                            tr.auth_sw, tr.zoom_en, tr.effect_en);
                    drive_button(tr);
                end
                SWITCH_SET: begin
                    if (control_vif != null)
                        control_vif.drive(
                            1'b0, 1'b0, 1'b0, 1'b0,
                            tr.auth_sw, tr.zoom_en, tr.effect_en);
                    drive_switches(tr);
                end
                UART_RX   : uart_vif.send_byte(tr.uart_rx_data);
                CAMERA_FRAME: begin
                    if (tr.camera_use_auth_grid)
                        camera_vif.send_auth_grid_frame(tr.camera_grid_id);
                    else
                        camera_vif.send_frame(
                            tr.camera_width, tr.camera_height,
                            tr.camera_rgb565, tr.camera_use_image,
                            tr.camera_line_blank_cycles);
                end
                SCCB_WRITE: drive_sccb_write();
                SCCB_READ : drive_sccb_read(tr.sccb_read_data);
                default   : `uvm_warning( "DRV", $sformatf("Unsupported mode: %s", tr.mode.name()))
            endcase
            seq_item_port.item_done();
        end
    endtask

    task automatic drive_switches(input transaction item);
        if (control_vif == null) begin
            `uvm_warning("DRV", "SWITCH_SET ignored: control_vif is not connected")
            return;
        end

        // Hold settings long enough for the DUT and monitor to observe them.
        repeat (item.switch_hold_cycles) @(posedge control_vif.clk);
    endtask

    task automatic drive_button(input transaction item);
        if (control_vif == null) begin
            `uvm_warning("DRV", "BUTTON_PRESS ignored: control_vif is not connected")
            return;
        end

        if (!$onehot({item.btn_U, item.btn_D, item.btn_L, item.btn_R})) begin
            `uvm_error("DRV", "BUTTON_PRESS requires exactly one asserted button")
            return;
        end

        repeat (item.button_hold_cycles) @(posedge control_vif.clk);
        control_vif.drive(
            1'b0, 1'b0, 1'b0, 1'b0,
            item.auth_sw, item.zoom_en, item.effect_en);
        // Wait for debounce to recognize release before the next press.
        repeat (item.button_hold_cycles) @(posedge control_vif.clk);
    endtask

    task automatic init_signals();
        sccb_vif.init();
        uart_vif.init();
        camera_vif.init();
        if (control_vif != null)
            control_vif.init();
    endtask

    task automatic drive_idle();
        sccb_vif.release_bus();
    endtask

    task automatic drive_reset();
        // tb_top drives DUT reset; the SCCB slave only releases SDA.
        sccb_vif.release_bus();
    endtask

    // Model the camera slave: ACK each byte and wait for STOP before counting.
    // Let the DUT generate SCCB addresses and timing so the monitor can verify them.
    task automatic receive_sccb_write(
        output logic [7:0] address_byte,
        output logic [7:0] register_byte,
        output logic [7:0] data_byte
    );
        sccb_vif.wait_start();
        sccb_vif.receive_byte(address_byte);
        sccb_vif.send_ack();
        sccb_vif.receive_byte(register_byte);
        sccb_vif.send_ack();
        sccb_vif.receive_byte(data_byte);
        sccb_vif.send_ack();
        sccb_vif.wait_stop();
        sccb_vif.count_write();
    endtask

    task automatic drive_sccb_write();
        logic [7:0] address_byte;
        logic [7:0] register_byte;
        logic [7:0] data_byte;

        receive_sccb_write(address_byte, register_byte, data_byte);

    endtask

    task automatic drive_sccb_read(input logic [7:0] read_data);
        logic [7:0] address_write;
        logic [7:0] address_read;
        logic [7:0] register_byte;
        logic       master_ack;

        // Receive the SCCB write address and register index.
        sccb_vif.wait_start();
        sccb_vif.receive_byte(address_write);
        sccb_vif.send_ack();
        sccb_vif.receive_byte(register_byte);
        sccb_vif.send_ack();
        sccb_vif.wait_stop();

        // Receive the SCCB read address, then return response data.
        sccb_vif.wait_start();
        sccb_vif.receive_byte(address_read);
        sccb_vif.send_ack();
        sccb_vif.send_byte(read_data, master_ack);
        sccb_vif.wait_stop();

        `uvm_info("DRV", $sformatf( "SCCB READ addr_w=0x%02h reg=0x%02h addr_r=0x%02h data=0x%02h ack=%0b",
            address_write, register_byte, address_read, read_data, master_ack), UVM_LOW)
    endtask

endclass
