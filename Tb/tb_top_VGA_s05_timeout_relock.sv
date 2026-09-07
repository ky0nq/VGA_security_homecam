`timescale 1ns / 1ps

// Scenario 05:
// Unlock Board 1, then send no traffic for Board 2's ten-second interval.
// Board 2 must transmit 0x80 back to Board 1 and both boards must relock.
module tb_top_VGA_s05_timeout_relock;

    localparam integer CLK_FREQ_HZ = 10_000;

    top_VGA_tb_fixture #(
        .CLK_FREQ_HZ      (CLK_FREQ_HZ),
        .BAUD_RATE        (1_000),
        .DEBOUNCE_MS      (1),
        .I2C_FREQ_HZ      (1_000),
        .POWERUP_DELAY_MS (100_000)
    ) FIXTURE();

    integer board1_rx_80_count = 0;
    integer board2_rx_40_count = 0;

    always @(posedge FIXTURE.clk) begin
        if (!FIXTURE.rst_n) begin
            board1_rx_80_count = 0;
            board2_rx_40_count = 0;
        end else begin
            if (FIXTURE.board1_rx_done && FIXTURE.board1_rx_data == 8'h80)
                board1_rx_80_count = board1_rx_80_count + 1;

            if (FIXTURE.board2_rx_done && FIXTURE.board2_rx_data == 8'h40)
                board2_rx_40_count = board2_rx_40_count + 1;
        end
    end

    task automatic wait_for_level(
        input integer signal_select,
        input logic expected_level,
        input integer max_cycles
    );
        integer elapsed_cycles;
        logic observed_level;
        begin
            elapsed_cycles = 0;
            observed_level = 1'b0;

            while (elapsed_cycles < max_cycles) begin
                case (signal_select)
                    0: observed_level = FIXTURE.board1_unlock_state;
                    1: observed_level = FIXTURE.board2_unlock_en;
                    default: observed_level = 1'bx;
                endcase

                if (observed_level === expected_level)
                    elapsed_cycles = max_cycles;
                else begin
                    @(posedge FIXTURE.clk);
                    elapsed_cycles = elapsed_cycles + 1;
                end
            end

            case (signal_select)
                0: observed_level = FIXTURE.board1_unlock_state;
                1: observed_level = FIXTURE.board2_unlock_en;
                default: observed_level = 1'bx;
            endcase

            if (observed_level !== expected_level)
                $fatal(1,
                       "Timed out waiting for signal %0d to become %0b",
                       signal_select, expected_level);
        end
    endtask

    integer timeout_cycles;

    initial begin
        FIXTURE.reset_dut();

        // Enter authentication tracking through the real auth switch path.
        @(negedge FIXTURE.clk);
        FIXTURE.board1_auth_sw = 1'b1;
        repeat (10) @(posedge FIXTURE.clk);

        // Camera-pattern generation is outside this timeout test. Inject one
        // valid authentication-pass pulse into the Board 1 control path.
        force FIXTURE.DUT.U_BOARD1_SYSTEM.unlock_pass = 1'b1;
        @(posedge FIXTURE.clk);
        #1;
        release FIXTURE.DUT.U_BOARD1_SYSTEM.unlock_pass;

        wait_for_level(0, 1'b1, 100);
        wait_for_level(1, 1'b1, 1000);

        if (board2_rx_40_count != 1)
            $fatal(1, "Board 2 did not receive exactly one unlock packet");

        // counter_10s uses ten CLK_FREQ_HZ intervals. Allow UART transfer
        // latency in addition to the nominal 100,000 clock cycles.
        timeout_cycles = 0;
        while ((board1_rx_80_count == 0) &&
               (timeout_cycles < (11 * CLK_FREQ_HZ))) begin
            @(posedge FIXTURE.clk);
            timeout_cycles = timeout_cycles + 1;
        end

        if (board1_rx_80_count != 1)
            $fatal(1, "Board 1 did not receive Board 2 timeout byte 0x80");

        wait_for_level(0, 1'b0, 100);
        wait_for_level(1, 1'b0, 1000);

        if (!FIXTURE.board1_remote_relock &&
            FIXTURE.board1_unlock_state !== 1'b0)
            $fatal(1, "Board 1 remote relock did not complete");

        $display("PASS S05: Board 2 timeout 0x80 relocked both boards");
        $finish;
    end

    initial begin
        #5ms;
        $fatal(1, "S05 global timeout");
    end

endmodule
