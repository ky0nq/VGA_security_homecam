`timescale 1ns / 1ps

// Scenario 04:
// Demonstrate the current one-deep pending bitmap limitation. With UART made
// intentionally slower than the button repetition rate, three valid BTN_U
// presses produce only two received BTN_U packets.
module tb_top_VGA_s04_fast_repeat_merge;

    top_VGA_tb_fixture #(
        .CLK_FREQ_HZ(100_000),
        .BAUD_RATE  (1_000),
        .DEBOUNCE_MS(1),
        .I2C_FREQ_HZ(1_000)
    ) FIXTURE();

    integer board1_btn_u_count = 0;
    integer board2_rx_count    = 0;
    integer board2_btn_u_count = 0;

    always @(posedge FIXTURE.clk) begin
        if (!FIXTURE.rst_n) begin
            board1_btn_u_count = 0;
            board2_rx_count    = 0;
            board2_btn_u_count = 0;
        end else begin
            if (FIXTURE.board1_btn_u_pulse)
                board1_btn_u_count = board1_btn_u_count + 1;
            if (FIXTURE.board2_rx_done)
                board2_rx_count = board2_rx_count + 1;
            if (FIXTURE.board2_btn_u_pulse)
                board2_btn_u_count = board2_btn_u_count + 1;
        end
    end

    task automatic wait_for_rx_count(input integer expected_count);
        integer timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((board2_rx_count < expected_count) &&
                   (timeout_cycles < 10000)) begin
                @(posedge FIXTURE.clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (board2_rx_count < expected_count)
                $fatal(1, "Timed out waiting for RX count %0d", expected_count);
        end
    endtask

    initial begin
        FIXTURE.reset_dut();
        FIXTURE.force_board1_unlocked();

        // Wait for the slow initial 0x40 unlock packet.
        wait_for_rx_count(1);

        // Each is a valid debounced press, but all three occur faster than one
        // UART frame. The second and third pending bits collapse into one bit.
        FIXTURE.press_btn_u();
        FIXTURE.press_btn_u();
        FIXTURE.press_btn_u();

        // Initial unlock + first BTN_U + one merged pending BTN_U.
        wait_for_rx_count(3);
        repeat (1500) @(posedge FIXTURE.clk);

        if (board1_btn_u_count != 3)
            $fatal(1, "Expected three Board 1 button pulses, got %0d",
                   board1_btn_u_count);
        if (board2_btn_u_count != 2)
            $fatal(1,
                   "Expected current RTL to merge into two packets, got %0d",
                   board2_btn_u_count);
        if (board2_rx_count != 3)
            $fatal(1, "Unexpected total Board 2 RX count %0d", board2_rx_count);

        FIXTURE.release_board1_unlock_force();

        $display("PASS S04: reproduced pending bitmap merge (3 presses -> 2 packets)");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "S04 global timeout");
    end

endmodule
