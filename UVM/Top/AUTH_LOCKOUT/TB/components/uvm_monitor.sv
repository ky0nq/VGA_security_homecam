// Observe DUT traffic and applied controls independently of sequence intent.
// Publish transactions for scoreboard checks and coverage sampling.
class Monitor extends uvm_monitor;
    `uvm_component_utils(Monitor)
    uvm_analysis_port #(transaction) send;
    virtual sccb_if sccb_vif;
    virtual uart_if uart_vif;
    virtual camera_if camera_vif;
    virtual control_if control_vif;

    function new(string name = "Monitor", uvm_component parent = null);
        super.new(name, parent); send = new("send", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sccb_if)::get( this, "", "sccb_vif", sccb_vif)) 
		begin `uvm_fatal("MON", "Unable to get sccb_vif") end
        if (!uvm_config_db#(virtual uart_if)::get(
                this, "", "uart_vif", uart_vif)) begin
            `uvm_fatal("MON", "Unable to get uart_vif")
        end
        if (!uvm_config_db#(virtual camera_if)::get(
                this, "", "camera_vif", camera_vif)) begin
            `uvm_fatal("MON", "Unable to get camera_vif")
        end
        void'(uvm_config_db#(virtual control_if)::get(
            this, "", "control_vif", control_vif));
    endfunction

    // Observe one byte and its ACK without driving the bus.
    task automatic sample_byte_and_ack(
        output logic [7:0] data,
        output logic       ack_error
    );
        sccb_vif.receive_byte(data);
        @(posedge sccb_vif.cam_scl);
        #1; ack_error = (sccb_vif.cam_sda !== 1'b0);
    endtask

    task automatic monitor_sccb();
        transaction tr;
        int unsigned observed_index = 0;
        logic address_ack_error;
        logic register_ack_error;
        logic data_ack_error;

        forever begin
            tr = transaction::type_id::create("sccb_observed_tr", this);

            sccb_vif.wait_start();

            sample_byte_and_ack(tr.sccb_device_addr, address_ack_error);
            sample_byte_and_ack(tr.sccb_register_addr, register_ack_error);
            sample_byte_and_ack(tr.sccb_write_data, data_ack_error);

            sccb_vif.wait_stop();

            tr.mode             = SCCB_WRITE;
            tr.sccb_is_read     = tr.sccb_device_addr[0];
            tr.sccb_ack_error   = address_ack_error |
                                  register_ack_error |
                                  data_ack_error;
            tr.transaction_done = 1'b1;
            tr.sccb_index       = observed_index++;

            send.write(tr);

        end
    endtask

    task automatic monitor_buttons();
        transaction tr;

        forever begin
            @(posedge control_vif.btn_U or posedge control_vif.btn_D or
              posedge control_vif.btn_L or posedge control_vif.btn_R);

            tr = transaction::type_id::create("button_observed_tr", this);
            tr.mode             = BUTTON_PRESS;
            tr.btn_U            = control_vif.btn_U;
            tr.btn_D            = control_vif.btn_D;
            tr.btn_L            = control_vif.btn_L;
            tr.btn_R            = control_vif.btn_R;
            tr.auth_sw          = control_vif.auth_sw;
            tr.zoom_en          = control_vif.zoom_en;
            tr.effect_en        = control_vif.effect_en;
            tr.transaction_done = 1'b1;
            send.write(tr);


            wait ({control_vif.btn_U, control_vif.btn_D,
                   control_vif.btn_L, control_vif.btn_R} == 4'b0000);
        end
    endtask

    task automatic monitor_switches();
        transaction tr;

        forever begin
            @(control_vif.auth_sw or control_vif.zoom_en or
              control_vif.effect_en);
            #1;

            tr = transaction::type_id::create("switch_observed_tr", this);
            tr.mode             = SWITCH_SET;
            tr.auth_sw          = control_vif.auth_sw;
            tr.zoom_en          = control_vif.zoom_en;
            tr.effect_en        = control_vif.effect_en;
            tr.transaction_done = 1'b1;
            send.write(tr);

        end
    endtask

    task automatic monitor_uart();
        transaction tr;

        forever begin
            tr = transaction::type_id::create("uart_observed_tr", this);
            uart_vif.receive_byte(tr.uart_tx_data);
            tr.mode             = UART_TX;
            tr.uart_tx_valid    = 1'b1;
            tr.transaction_done = 1'b1;
            send.write(tr);

        end
    endtask

    task automatic monitor_camera();
        transaction tr;
        int unsigned active_byte_count;

        forever begin
            @(negedge camera_vif.vsync);
            active_byte_count = 0;

            while (camera_vif.vsync === 1'b0) begin
                @(posedge camera_vif.pclk);
                if (camera_vif.href)
                    active_byte_count++;
            end

            tr = transaction::type_id::create("camera_observed_tr", this);
            tr.mode               = CAMERA_FRAME;
            tr.camera_pixel_count = active_byte_count / 2;
            tr.camera_frame_valid = ((active_byte_count % 2) == 0) &&
                                    (active_byte_count != 0);
            tr.transaction_done   = 1'b1;
            send.write(tr);

        end
    endtask

    virtual task run_phase(uvm_phase phase);
        fork
            monitor_sccb();
            monitor_uart();
            monitor_camera();
            begin
                if (control_vif != null) monitor_buttons();
            end
            begin
                if (control_vif != null) monitor_switches();
            end
        join
    endtask
endclass
