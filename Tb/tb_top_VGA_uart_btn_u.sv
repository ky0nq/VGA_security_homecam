`timescale 1ns / 1ps

module tb_top_VGA_uart_btn_u;

    // Reduced frequencies keep the test fast while preserving UART and
    // debounce timing ratios in clock cycles.
    localparam integer CLK_FREQ_HZ       = 1_000_000;
    localparam integer BAUD_RATE         = 100_000;
    localparam integer DEBOUNCE_MS       = 1;
    localparam integer DEBOUNCE_CYCLES   =
        (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer BUTTON_PRESS_COUNT = 3;

    logic clk   = 1'b0;
    logic rst_n = 1'b0;

    logic board1_btn_R     = 1'b0;
    logic board1_btn_L     = 1'b0;
    logic board1_btn_D     = 1'b0;
    logic board1_btn_U     = 1'b0;
    logic board1_auth_sw   = 1'b0;
    logic board1_zoom_en   = 1'b0;
    logic board1_effect_en = 1'b0;

    logic       board1_pclk     = 1'b0;
    logic       board1_cam_href = 1'b0;
    logic       board1_cam_vsync = 1'b0;
    logic [7:0] board1_cam_data = 8'h00;

    logic       board2_pclk     = 1'b0;
    logic       board2_cam_href = 1'b0;
    logic       board2_cam_vsync = 1'b0;
    logic [7:0] board2_cam_data = 8'h00;

    wire board1_uart_tx;
    wire board2_uart_tx;

    tri board1_cam_sda;
    tri board2_cam_sda;

    integer board2_rx_done_count = 0;
    integer board2_btn_u_count   = 0;
    logic [7:0] board2_rx_packets [0:BUTTON_PRESS_COUNT];

    always #5 clk = ~clk;

    top_VGA #(
        .CLK_FREQ_HZ      (CLK_FREQ_HZ),
        .BAUD_RATE        (BAUD_RATE),
        .BUTTON_DEBOUNCE_MS(DEBOUNCE_MS),
        .POWERUP_DELAY_MS (50)
    ) DUT (
        .clk              (clk),
        .rst_n            (rst_n),

        .board1_btn_R     (board1_btn_R),
        .board1_btn_L     (board1_btn_L),
        .board1_btn_D     (board1_btn_D),
        .board1_btn_U     (board1_btn_U),
        .board1_auth_sw   (board1_auth_sw),
        .board1_zoom_en   (board1_zoom_en),
        .board1_effect_en (board1_effect_en),

        .board1_pclk      (board1_pclk),
        .board1_cam_href  (board1_cam_href),
        .board1_cam_vsync (board1_cam_vsync),
        .board1_cam_data  (board1_cam_data),
        .board1_cam_sda   (board1_cam_sda),

        .board2_pclk      (board2_pclk),
        .board2_cam_href  (board2_cam_href),
        .board2_cam_vsync (board2_cam_vsync),
        .board2_cam_data  (board2_cam_data),
        .board2_cam_sda   (board2_cam_sda),

        .board1_uart_tx   (board1_uart_tx),
        .board2_uart_tx   (board2_uart_tx)
    );

    // Board 2 receive-side signals are intentionally observed through the
    // hierarchy so production RTL does not need test-only debug ports.
    wire       board2_rx_done = DUT.U_BOARD2_SYSTEM.U_UART_LINK.rx_done;
    wire [7:0] board2_rx_data = DUT.U_BOARD2_SYSTEM.U_UART_LINK.rx_data;
    wire       board2_btn_u_pulse =
        DUT.U_BOARD2_SYSTEM.U_UART_LINK.btn_u_pulse;

    always @(posedge clk) begin
        if (!rst_n) begin
            board2_rx_done_count = 0;
            board2_btn_u_count   = 0;
        end else begin
            if (board2_rx_done) begin
                if (board2_rx_done_count <= BUTTON_PRESS_COUNT) begin
                    board2_rx_packets[board2_rx_done_count] = board2_rx_data;
                end

                board2_rx_done_count = board2_rx_done_count + 1;
                $display("[%0t] Board 2 RX done: data=0x%02h, count=%0d",
                         $time, board2_rx_data, board2_rx_done_count);
            end

            if (board2_btn_u_pulse) begin
                board2_btn_u_count = board2_btn_u_count + 1;
                $display("[%0t] Board 2 BTN_U pulse, count=%0d",
                         $time, board2_btn_u_count);
            end
        end
    end

    task automatic wait_for_rx_count(input integer expected_count);
        integer timeout_cycles;
        begin
            timeout_cycles = 0;

            while ((board2_rx_done_count < expected_count) &&
                   (timeout_cycles < 5000)) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (board2_rx_done_count < expected_count) begin
                $fatal(1, "Timed out waiting for Board 2 rx_done count %0d",
                       expected_count);
            end
        end
    endtask

    task automatic press_and_release_btn_u;
        begin
            // High must remain stable long enough to pass the debouncer.
            @(negedge clk);
            board1_btn_U = 1'b1;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);

            // Low must also remain stable so the next press can be detected.
            @(negedge clk);
            board1_btn_U = 1'b0;
            repeat (DEBOUNCE_CYCLES + 10) @(posedge clk);
        end
    endtask

    integer press_index;

    initial begin
        repeat (10) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        // Authentication is outside this focused UART test. Force only the
        // Board 1 authorization state so button packets are permitted.
        force DUT.U_BOARD1_SYSTEM.unlock_state = 1'b1;

        // The unlock transition itself sends one 0x40 status packet.
        wait_for_rx_count(1);

        if (board2_rx_packets[0] !== 8'h40) begin
            $fatal(1, "Expected initial unlock packet 0x40, got 0x%02h",
                   board2_rx_packets[0]);
        end

        for (press_index = 0;
             press_index < BUTTON_PRESS_COUNT;
             press_index = press_index + 1) begin
            press_and_release_btn_u();
            wait_for_rx_count(press_index + 2);

            if (board2_rx_packets[press_index + 1] !== 8'h60) begin
                $fatal(1,
                       "BTN_U packet %0d: expected 0x60, got 0x%02h",
                       press_index + 1,
                       board2_rx_packets[press_index + 1]);
            end
        end

        if (board2_rx_done_count != BUTTON_PRESS_COUNT + 1) begin
            $fatal(1, "Expected %0d total rx_done pulses, got %0d",
                   BUTTON_PRESS_COUNT + 1, board2_rx_done_count);
        end

        if (board2_btn_u_count != BUTTON_PRESS_COUNT) begin
            $fatal(1, "Expected %0d Board 2 BTN_U pulses, got %0d",
                   BUTTON_PRESS_COUNT, board2_btn_u_count);
        end

        release DUT.U_BOARD1_SYSTEM.unlock_state;

        $display("==================================================");
        $display("PASS: repeated Board 1 BTN_U reached Board 2");
        $display("      rx_done pulses = %0d", board2_rx_done_count);
        $display("      BTN_U pulses   = %0d", board2_btn_u_count);
        $display("==================================================");
        $finish;
    end

    initial begin
        #1ms;
        $fatal(1, "Global simulation timeout");
    end

endmodule
