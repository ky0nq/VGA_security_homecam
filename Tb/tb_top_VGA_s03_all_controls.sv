`timescale 1ns / 1ps

// Scenario 03:
// Verify switch status packets and all four button fields from Board 1 to
// Board 2, including Board 2 decoder outputs.
module tb_top_VGA_s03_all_controls;

    localparam integer EXPECTED_PACKET_COUNT = 9;

    top_VGA_tb_fixture FIXTURE();

    integer rx_count = 0;
    integer btn_l_count = 0;
    integer btn_r_count = 0;
    integer btn_d_count = 0;
    integer btn_u_count = 0;
    logic [7:0] rx_packets [0:EXPECTED_PACKET_COUNT-1];

    always @(posedge FIXTURE.clk) begin
        if (!FIXTURE.rst_n) begin
            rx_count    = 0;
            btn_l_count = 0;
            btn_r_count = 0;
            btn_d_count = 0;
            btn_u_count = 0;
        end else begin
            if (FIXTURE.board2_rx_done) begin
                if (rx_count < EXPECTED_PACKET_COUNT)
                    rx_packets[rx_count] = FIXTURE.board2_rx_data;
                rx_count = rx_count + 1;
            end

            if (FIXTURE.board2_btn_l_pulse)
                btn_l_count = btn_l_count + 1;
            if (FIXTURE.board2_btn_r_pulse)
                btn_r_count = btn_r_count + 1;
            if (FIXTURE.board2_btn_d_pulse)
                btn_d_count = btn_d_count + 1;
            if (FIXTURE.board2_btn_u_pulse)
                btn_u_count = btn_u_count + 1;
        end
    end

    task automatic wait_for_rx_count(input integer expected_count);
        integer timeout_cycles;
        begin
            timeout_cycles = 0;
            while ((rx_count < expected_count) && (timeout_cycles < 5000)) begin
                @(posedge FIXTURE.clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (rx_count < expected_count)
                $fatal(1, "Timed out waiting for RX packet %0d", expected_count);
        end
    endtask

    task automatic check_packet(
        input integer packet_index,
        input logic [7:0] expected_data
    );
        begin
            if (rx_packets[packet_index] !== expected_data)
                $fatal(1,
                       "Packet %0d: expected 0x%02h, got 0x%02h",
                       packet_index, expected_data, rx_packets[packet_index]);
        end
    endtask

    initial begin
        // Drive the initial reset and all control defaults directly from S03.
        FIXTURE.rst_n            = 1'b0;
        FIXTURE.board1_btn_R     = 1'b0;
        FIXTURE.board1_btn_L     = 1'b0;
        FIXTURE.board1_btn_D     = 1'b0;
        FIXTURE.board1_btn_U     = 1'b0;
        FIXTURE.board1_auth_sw   = 1'b0;
        FIXTURE.board1_zoom_en   = 1'b0;
        FIXTURE.board1_effect_en = 1'b0;

        repeat (10) @(posedge FIXTURE.clk);
        @(negedge FIXTURE.clk);
        FIXTURE.rst_n = 1'b1;

        FIXTURE.force_board1_unlocked();

        // Unlock state packet: bit 6.
        wait_for_rx_count(1);
        check_packet(0, 8'h40);

        // Zoom switch on: bits 6 and 0.
        @(negedge FIXTURE.clk);
        FIXTURE.board1_zoom_en = 1'b1;
        wait_for_rx_count(2);
        check_packet(1, 8'h41);
        repeat (2) @(posedge FIXTURE.clk);
        if (FIXTURE.board2_zoom_en !== 1'b1)
            $fatal(1, "Board 2 zoom_en did not assert");

        // Effect switch on: bits 6, 1 and 0.
        @(negedge FIXTURE.clk);
        FIXTURE.board1_effect_en = 1'b1;
        wait_for_rx_count(3);
        check_packet(2, 8'h43);
        repeat (2) @(posedge FIXTURE.clk);
        if (FIXTURE.board2_effect_sel !== 1'b1)
            $fatal(1, "Board 2 effect_sel did not assert");

        // L/R/D/U button packets retain both switch levels.
        FIXTURE.press_btn_l();
        wait_for_rx_count(4);
        check_packet(3, 8'h47);

        FIXTURE.press_btn_r();
        wait_for_rx_count(5);
        check_packet(4, 8'h4B);

        FIXTURE.press_btn_d();
        wait_for_rx_count(6);
        check_packet(5, 8'h53);

        FIXTURE.press_btn_u();
        wait_for_rx_count(7);
        check_packet(6, 8'h63);

        // Turn switches off and verify level updates.
        @(negedge FIXTURE.clk);
        FIXTURE.board1_zoom_en = 1'b0;
        wait_for_rx_count(8);
        check_packet(7, 8'h42);

        @(negedge FIXTURE.clk);
        FIXTURE.board1_effect_en = 1'b0;
        wait_for_rx_count(9);
        check_packet(8, 8'h40);

        repeat (3) @(posedge FIXTURE.clk);

        if (btn_l_count != 1 || btn_r_count != 1 ||
            btn_d_count != 1 || btn_u_count != 1)
            $fatal(1,
                   "Decoded button counts L/R/D/U = %0d/%0d/%0d/%0d",
                   btn_l_count, btn_r_count, btn_d_count, btn_u_count);

        if (FIXTURE.board2_zoom_en !== 1'b0 ||
            FIXTURE.board2_effect_sel !== 1'b0)
            $fatal(1, "Board 2 switch levels did not return low");

        FIXTURE.release_board1_unlock_force();

        // Final reset scenario: assert reset once after all controls have been
        // exercised, then verify both boards return to their idle values.
        @(negedge FIXTURE.clk);
        FIXTURE.rst_n = 1'b0;
        repeat (10) @(posedge FIXTURE.clk);
        #1;

        if (FIXTURE.board1_unlock_state !== 1'b0)
            $fatal(1, "Final reset did not lock Board 1");
        if (FIXTURE.board2_unlock_en !== 1'b0)
            $fatal(1, "Final reset did not lock Board 2");
        if (FIXTURE.board2_zoom_en !== 1'b0 ||
            FIXTURE.board2_effect_sel !== 1'b0)
            $fatal(1, "Final reset did not clear Board 2 switch state");
        if (FIXTURE.board1_tx_busy !== 1'b0 ||
            FIXTURE.board1_tx_start !== 1'b0)
            $fatal(1, "Final reset did not clear Board 1 UART control state");
        if (FIXTURE.board1_uart_tx !== 1'b1 ||
            FIXTURE.board2_uart_tx !== 1'b1)
            $fatal(1, "Final reset did not return UART lines to idle high");

        @(negedge FIXTURE.clk);
        FIXTURE.rst_n = 1'b1;
        repeat (5) @(posedge FIXTURE.clk);

        if (FIXTURE.board1_unlock_state !== 1'b0 ||
            FIXTURE.board2_unlock_en !== 1'b0)
            $fatal(1, "Boards did not remain locked after reset release");

        $display("PASS S03: controls transferred and final reset cleared both boards");
        $finish;
    end

    initial begin
        #2ms;
        $fatal(1, "S03 global timeout");
    end

endmodule
