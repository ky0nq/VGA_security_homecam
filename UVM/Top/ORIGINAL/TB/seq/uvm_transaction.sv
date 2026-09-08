class transaction extends uvm_sequence_item;
    rand c_mode mode;

    // Sequences set button and switch inputs for the interfaces to drive.
    rand logic btn_R;
    rand logic btn_L;
    rand logic btn_D;
    rand logic btn_U;
    rand logic auth_sw;
    rand logic zoom_en;
    rand logic effect_en;
    rand int unsigned button_hold_cycles;
    rand int unsigned switch_hold_cycles;

    // Camera stimulus settings; tb_top supplies clocks and wiring.
    rand logic       cam_href;
    rand logic       cam_vsync;
    rand logic [7:0] cam_data;
    rand logic [15:0] camera_rgb565;
    rand logic        camera_use_image;
    rand logic        camera_use_auth_grid;
    rand logic [3:0]  camera_grid_id;
    rand int unsigned camera_width;
    rand int unsigned camera_height;
    rand int unsigned camera_line_blank_cycles;
         int unsigned camera_pixel_count;
         logic        camera_frame_valid;

    // UART RX is stimulus; TX fields are monitor observations.
    rand logic [7:0] uart_rx_data;
         logic [7:0] uart_tx_data;
         logic       uart_tx_valid;
         logic       uart_frame_error;

    // SCCB response data and observations of DUT-initiated transfers.
    rand logic [7:0] sccb_read_data;
         logic [7:0] sccb_device_addr;
         logic [7:0] sccb_register_addr;
         logic [7:0] sccb_write_data;
         logic       sccb_is_read;
         logic       sccb_ack_error;
         int unsigned sccb_index;
         logic       sccb_order_match;

    // Transaction completion flag set by the monitor.
    logic transaction_done;

    constraint valid_mode_c {
        mode inside {TEST_START, TEST_END, RESET, BUTTON_PRESS, SWITCH_SET,
                     CAMERA_FRAME,
                     UART_RX, UART_TX,
                     SCCB_WRITE, SCCB_READ};
    }

    // Default constraints that sequences may override.
    constraint protocol_default_c {
        soft sccb_read_data == 8'h00;
    }

    constraint input_default_c {
        soft btn_R     == 1'b0;
        soft btn_L     == 1'b0;
        soft btn_D     == 1'b0;
        soft btn_U     == 1'b0;
        soft auth_sw   == 1'b0;
        soft zoom_en   == 1'b0;
        soft effect_en == 1'b0;
        soft button_hold_cycles == 10_010;
        soft switch_hold_cycles == 100;
        soft cam_href  == 1'b0;
        soft cam_vsync == 1'b1;
        soft cam_data  == 8'h00;
        soft camera_rgb565 == 16'h001f;
        soft camera_use_image == 1'b0;
        soft camera_use_auth_grid == 1'b0;
        soft camera_grid_id inside {[1:9]};
        soft camera_width == 320;
        soft camera_height == 240;
        soft camera_line_blank_cycles == 2;
    }

    function new(string name = "transaction");
        super.new(name);
        btn_R     = 1'b0;
        btn_L     = 1'b0;
        btn_D     = 1'b0;
        btn_U     = 1'b0;
        auth_sw   = 1'b0;
        zoom_en   = 1'b0;
        effect_en = 1'b0;
        button_hold_cycles = 10_010;
        switch_hold_cycles = 100;
        cam_href  = 1'b0;
        cam_vsync = 1'b1;
        cam_data  = 8'h00;
        camera_rgb565 = 16'h001f;
        camera_use_image = 1'b0;
        camera_use_auth_grid = 1'b0;
        camera_grid_id = 4'd1;
        camera_width = 320;
        camera_height = 240;
        camera_line_blank_cycles = 2;
    endfunction

    `uvm_object_utils_begin(transaction)
        `uvm_field_enum(c_mode, mode, UVM_DEFAULT)
        `uvm_field_int(btn_R,              UVM_DEFAULT)
        `uvm_field_int(btn_L,              UVM_DEFAULT)
        `uvm_field_int(btn_D,              UVM_DEFAULT)
        `uvm_field_int(btn_U,              UVM_DEFAULT)
        `uvm_field_int(auth_sw,            UVM_DEFAULT)
        `uvm_field_int(zoom_en,            UVM_DEFAULT)
        `uvm_field_int(effect_en,          UVM_DEFAULT)
        `uvm_field_int(button_hold_cycles, UVM_DEFAULT)
        `uvm_field_int(switch_hold_cycles, UVM_DEFAULT)
        `uvm_field_int(cam_href,           UVM_DEFAULT)
        `uvm_field_int(cam_vsync,          UVM_DEFAULT)
        `uvm_field_int(cam_data,           UVM_DEFAULT)
        `uvm_field_int(camera_rgb565,      UVM_DEFAULT)
        `uvm_field_int(camera_use_image,   UVM_DEFAULT)
        `uvm_field_int(camera_use_auth_grid, UVM_DEFAULT)
        `uvm_field_int(camera_grid_id,     UVM_DEFAULT)
        `uvm_field_int(camera_width,       UVM_DEFAULT)
        `uvm_field_int(camera_height,      UVM_DEFAULT)
        `uvm_field_int(camera_line_blank_cycles, UVM_DEFAULT)
        `uvm_field_int(camera_pixel_count, UVM_DEFAULT)
        `uvm_field_int(camera_frame_valid, UVM_DEFAULT)
        `uvm_field_int(uart_rx_data,       UVM_DEFAULT)
        `uvm_field_int(uart_tx_data,       UVM_DEFAULT)
        `uvm_field_int(uart_tx_valid,      UVM_DEFAULT)
        `uvm_field_int(uart_frame_error,   UVM_DEFAULT)
        `uvm_field_int(sccb_read_data,     UVM_DEFAULT)
        `uvm_field_int(sccb_device_addr,   UVM_DEFAULT)
        `uvm_field_int(sccb_register_addr, UVM_DEFAULT)
        `uvm_field_int(sccb_write_data,    UVM_DEFAULT)
        `uvm_field_int(sccb_is_read,       UVM_DEFAULT)
        `uvm_field_int(sccb_ack_error,     UVM_DEFAULT)
        `uvm_field_int(sccb_index,         UVM_DEFAULT)
        `uvm_field_int(sccb_order_match,   UVM_DEFAULT)
        `uvm_field_int(transaction_done,   UVM_DEFAULT)
    `uvm_object_utils_end
endclass
