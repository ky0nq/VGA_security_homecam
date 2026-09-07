`timescale 1ns / 1ps

// Scenario 01:
// A valid, debounced BTN_U press must be blocked while Board 1 is locked.
module tb_top_VGA_s01_locked_button;

    top_VGA_tb_fixture FIXTURE();

    bit saw_button_pulse = 1'b0;
    bit saw_tx_event     = 1'b0;
    bit saw_tx_start     = 1'b0;
    bit saw_rx_done      = 1'b0;

    always @(posedge FIXTURE.clk) begin
        if (!FIXTURE.rst_n) begin
            saw_button_pulse <= 1'b0;
            saw_tx_event     <= 1'b0;
            saw_tx_start     <= 1'b0;
            saw_rx_done      <= 1'b0;
        end else begin
            if (FIXTURE.board1_btn_u_pulse)
                saw_button_pulse <= 1'b1;
            if (FIXTURE.board1_tx_event_valid)
                saw_tx_event <= 1'b1;
            if (FIXTURE.board1_tx_start)
                saw_tx_start <= 1'b1;
            if (FIXTURE.board2_rx_done)
                saw_rx_done <= 1'b1;
        end
    end

    initial begin
        // S01 is an UART test, so show an idle black screen.
        FIXTURE.init_video_black();
        FIXTURE.reset_dut();

        if (FIXTURE.board1_unlock_state !== 1'b0)
            $fatal(1, "Board 1 must start locked");

        FIXTURE.press_btn_u();
        repeat (300) @(posedge FIXTURE.clk);

        if (!saw_button_pulse)
            $fatal(1, "BTN_U pulse was not generated");
        if (saw_tx_event)
            $fatal(1, "Locked BTN_U unexpectedly created tx_event_valid");
        if (saw_tx_start)
            $fatal(1, "Locked BTN_U unexpectedly started UART TX");
        if (saw_rx_done)
            $fatal(1, "Board 2 unexpectedly received a locked BTN_U packet");

        if ({FIXTURE.board1_red, FIXTURE.board1_green,
             FIXTURE.board1_blue} !== 12'h000)
            $fatal(1, "Board 1 RGB must be known black in this UART test");
        if ({FIXTURE.board2_red, FIXTURE.board2_green,
             FIXTURE.board2_blue} !== 12'h000)
            $fatal(1, "Board 2 RGB must be known black in this UART test");

        $display("PASS S01: locked BTN_U was blocked before UART TX");
        $finish;
    end

    initial begin
        #1ms;
        $fatal(1, "S01 global timeout");
    end

endmodule
