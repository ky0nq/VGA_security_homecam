`ifndef SERIAL_INTERFACES_SV
`define SERIAL_INTERFACES_SV

interface uart_if #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
) (input logic clk);
    localparam int CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    wire  rx;
    wire  tx;
    wire  peer_tx;
    logic rx_drive       = 1'b1;
    logic rx_drive_enable = 1'b0;

    // Forward peer TX to RX unless the BFM is injecting a byte.
    assign rx = rx_drive_enable ? rx_drive : peer_tx;

    task automatic init();
        rx_drive        = 1'b1;
        rx_drive_enable = 1'b0;
    endtask

    task automatic send_byte(input logic [7:0] data);
        rx_drive_enable = 1'b1;
        rx_drive = 1'b0;
        repeat (CLKS_PER_BIT) @(posedge clk);
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            rx_drive = data[bit_index];
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
        rx_drive = 1'b1;
        repeat (CLKS_PER_BIT) @(posedge clk);
        rx_drive_enable = 1'b0;
    endtask

    task automatic receive_byte(output logic [7:0] data);
        @(negedge tx);
        repeat (CLKS_PER_BIT + (CLKS_PER_BIT / 2)) @(posedge clk);
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            data[bit_index] = tx;
            repeat (CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    modport DUT (input rx, output tx);
    modport BFM (input clk, rx, tx, peer_tx,
                 output rx_drive, rx_drive_enable);
    modport MON (input clk, rx, tx, peer_tx, rx_drive_enable);
endinterface

interface control_if(input logic clk);
    logic btn_R     = 1'b0;
    logic btn_L     = 1'b0;
    logic btn_D     = 1'b0;
    logic btn_U     = 1'b0;
    logic auth_sw   = 1'b0;
    logic zoom_en   = 1'b0;
    logic effect_en = 1'b0;

    task automatic init();
        @(negedge clk);
        btn_R     = 1'b0;
        btn_L     = 1'b0;
        btn_D     = 1'b0;
        btn_U     = 1'b0;
        auth_sw   = 1'b0;
        zoom_en   = 1'b0;
        effect_en = 1'b0;
    endtask

    task automatic drive(
        input logic drive_btn_R,
        input logic drive_btn_L,
        input logic drive_btn_D,
        input logic drive_btn_U,
        input logic drive_auth_sw,
        input logic drive_zoom_en,
        input logic drive_effect_en
    );
        @(negedge clk);
        btn_R     = drive_btn_R;
        btn_L     = drive_btn_L;
        btn_D     = drive_btn_D;
        btn_U     = drive_btn_U;
        auth_sw   = drive_auth_sw;
        zoom_en   = drive_zoom_en;
        effect_en = drive_effect_en;
    endtask

    task automatic sample(
        output logic sample_btn_R,
        output logic sample_btn_L,
        output logic sample_btn_D,
        output logic sample_btn_U,
        output logic sample_auth_sw,
        output logic sample_zoom_en,
        output logic sample_effect_en
    );
        @(posedge clk);
        sample_btn_R     = btn_R;
        sample_btn_L     = btn_L;
        sample_btn_D     = btn_D;
        sample_btn_U     = btn_U;
        sample_auth_sw   = auth_sw;
        sample_zoom_en   = zoom_en;
        sample_effect_en = effect_en;
    endtask

    modport DUT (input clk, btn_R, btn_L, btn_D, btn_U,
                 auth_sw, zoom_en, effect_en);
    modport BFM (input clk, output btn_R, btn_L, btn_D, btn_U,
                 auth_sw, zoom_en, effect_en);
    modport MON (input clk, btn_R, btn_L, btn_D, btn_U,
                 auth_sw, zoom_en, effect_en);
endinterface

interface camera_if(input logic pclk);
    logic       href  = 1'b0;
    logic       vsync = 1'b1;
    logic [7:0] data  = 8'h00;

    task automatic init();
        @(negedge pclk);
        href  = 1'b0;
        vsync = 1'b1;
        data  = 8'h00;
    endtask

    task automatic drive(
        input logic       drive_href,
        input logic       drive_vsync,
        input logic [7:0] drive_data
    );
        @(negedge pclk);
        href  = drive_href;
        vsync = drive_vsync;
        data  = drive_data;
    endtask

    task automatic send_frame(
        input int unsigned width,
        input int unsigned height,
        input logic [15:0] rgb565,
        input logic        use_image,
        input int unsigned line_blank_cycles = 2
    );
        logic [11:0] image_rgb444 [0:320*240-1];
        logic [15:0] pixel_rgb565;

        if (use_image) begin
            if ((width != 320) || (height != 240))
                $fatal(1, "photo_input.hex requires a 320x240 camera frame");
            $readmemh("../TB/image_hex/photo_input.hex", image_rgb444);
        end

        drive(1'b0, 1'b1, 8'h00);
        drive(1'b0, 1'b0, 8'h00);
        for (int y = 0; y < height; y++) begin
            for (int x = 0; x < width; x++) begin
                if (use_image) begin
                    // Convert RGB444 into the RGB565 byte stream used by the camera.
                    pixel_rgb565 = {
                        image_rgb444[y*width+x][11:8], image_rgb444[y*width+x][11],
                        image_rgb444[y*width+x][7:4],  image_rgb444[y*width+x][7:6],
                        image_rgb444[y*width+x][3:0],  image_rgb444[y*width+x][3]
                    };
                end else begin
                    pixel_rgb565 = rgb565;
                end
                drive(1'b1, 1'b0, pixel_rgb565[15:8]);
                drive(1'b1, 1'b0, pixel_rgb565[7:0]);
            end
            repeat (line_blank_cycles)
                drive(1'b0, 1'b0, 8'h00);
        end
        drive(1'b0, 1'b1, 8'h00);
    endtask

    // Place a 10x10 blue marker at the requested grid center on a black frame.
    // The DUT must derive the grid from pixels rather than an injected grid event.
    task automatic send_auth_grid_frame(input logic [3:0] grid_id);
        logic [15:0] pixel_rgb565;
        int center_x;
        int center_y;

        center_x = ((grid_id - 1) % 3) * 106 + 53;
        center_y = ((grid_id - 1) / 3) * 80  + 40;
        drive(1'b0, 1'b1, 8'h00);
        drive(1'b0, 1'b0, 8'h00);
        for (int y = 0; y < 240; y++) begin
            for (int x = 0; x < 320; x++) begin
                pixel_rgb565 = ((x >= center_x-5) && (x < center_x+5) &&
                                (y >= center_y-5) && (y < center_y+5)) ?
                               16'h001f : 16'h0000;
                drive(1'b1, 1'b0, pixel_rgb565[15:8]);
                drive(1'b1, 1'b0, pixel_rgb565[7:0]);
            end
            repeat (2) drive(1'b0, 1'b0, 8'h00);
        end
        drive(1'b0, 1'b1, 8'h00);
    endtask

    task automatic sample(
        output logic       sample_href,
        output logic       sample_vsync,
        output logic [7:0] sample_data
    );
        @(posedge pclk);
        sample_href  = href;
        sample_vsync = vsync;
        sample_data  = data;
    endtask

    modport DUT (input pclk, href, vsync, data);
    modport BFM (input pclk, output href, vsync, data);
    modport MON (input pclk, href, vsync, data);
endinterface

interface vga_if(input logic clk, input logic rst_n);
    wire        h_sync;
    wire        v_sync;
    wire [11:0] rgb;
    wire        de;
    wire [9:0]  x_pixel;
    wire [9:0]  y_pixel;
    wire [16:0] source_addr;
    wire [15:0] source_data;
    wire        pixel_tick;
    wire [11:0] gaussian_rgb;
    wire        unlock_state;
    wire        zoom_en;
    wire [1:0]  zoom_in;
    wire        unlock_fail;
    wire        alarm;
    wire [3:0]  grid_id;
    wire        grid_enter_pulse;
    wire [2:0]  pattern_index;
    wire [1:0]  fail_count;
    wire [1:0]  control_state;
    wire        effect_sel;
    wire [3:0]  button_pulse;
    wire [7:0]  uart_rx_data;
    wire        uart_rx_done;
    wire [7:0]  uart_tx_data;
    wire        uart_tx_start;
    wire        timeout_done;

    // Align to active-low VSYNC, then wait for the requested frame periods.
    task automatic wait_frames(input int unsigned frame_count);
        @(negedge v_sync);
        repeat (frame_count)
            @(negedge v_sync);
    endtask

    modport MON (input clk, rst_n, h_sync, v_sync, rgb, de, x_pixel, y_pixel,
                 source_addr, source_data, pixel_tick, gaussian_rgb,
                 unlock_state, zoom_en, zoom_in);
endinterface

interface sccb_if;
    wire cam_scl;
    tri1 cam_sda;

    logic sda_drive_low = 1'b0;
    logic [6:0] write_count = 7'd0;
    assign cam_sda = sda_drive_low ? 1'b0 : 1'bz;

    task automatic init();
        sda_drive_low = 1'b0;
        write_count   = 7'd0;
    endtask

    task automatic release_bus();
        sda_drive_low = 1'b0;
    endtask

    task automatic wait_start();
        forever begin
            @(negedge cam_sda);
            if (cam_scl === 1'b1) return;
        end
    endtask

    task automatic wait_stop();
        forever begin
            @(posedge cam_sda);
            if (cam_scl === 1'b1) return;
        end
    endtask

    // Called after the driver observes STOP for a three-byte write; saturates at 127.
    task automatic count_write();
        if (write_count < 7'd127)
            write_count = write_count + 1'b1;
    endtask

    task automatic receive_byte(output logic [7:0] data);
        data = '0;
        repeat (8) begin
            @(posedge cam_scl);
            data = {data[6:0], cam_sda};
        end
    endtask

    task automatic send_ack();
        @(negedge cam_scl);
        sda_drive_low = 1'b1;
        @(posedge cam_scl);
        @(negedge cam_scl);
        sda_drive_low = 1'b0;
    endtask

    task automatic send_nack();
        @(negedge cam_scl);
        sda_drive_low = 1'b0;
        @(posedge cam_scl);
        @(negedge cam_scl);
    endtask

    task automatic send_byte(
        input  logic [7:0] data,
        output logic       ack
    );
        for (int bit_index = 7; bit_index >= 0; bit_index--) begin
            @(negedge cam_scl);
            sda_drive_low = ~data[bit_index];
            @(posedge cam_scl);
        end
        @(negedge cam_scl);
        sda_drive_low = 1'b0;
        @(posedge cam_scl);
        ack = (cam_sda === 1'b0);
        @(negedge cam_scl);
    endtask

    modport DUT (output cam_scl, inout cam_sda);
    modport BFM (input cam_scl, cam_sda, output sda_drive_low);
    modport MON (input cam_scl, cam_sda);
endinterface

`endif
