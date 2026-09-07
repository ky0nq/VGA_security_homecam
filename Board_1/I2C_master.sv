`timescale 1ns / 1ps

// Simple I2C/SCCB master. Sends one register write (address + data) to the camera.

module I2C_master #(
    parameter integer CLK_FREQ_HZ = 100_000_000,  // FPGA clock
    parameter integer I2C_FREQ_HZ = 100_000       // SCCB SCL frequency
)(
    input  logic       clk,
    input  logic       rst_n,

    // 1-clock pulse from the setup controller, tells us to start a write
    input  logic       start,

    // 8-bit device address (OV7670 write address = 8'h42)
    input  logic [7:0] dev_addr,

    // register address / data to write
    input  logic [7:0] reg_addr,
    input  logic [7:0] reg_data,

    // status back to the setup controller
    output logic       busy,
    output logic       done,
    output logic       ack_error,

    // SCCB pins
    output logic       scl,
    inout  wire        sda
);

    // divide the clock down so scl toggles at I2C_FREQ_HZ, 4 steps per bit
    localparam integer TICK_DIV_CALC = CLK_FREQ_HZ / (I2C_FREQ_HZ * 4);
    localparam integer TICK_DIV = (TICK_DIV_CALC < 1) ? 1 : TICK_DIV_CALC;
    localparam integer CLK_CNT_WIDTH = (TICK_DIV <= 1) ? 1 : $clog2(TICK_DIV);

    logic [CLK_CNT_WIDTH-1:0] clk_cnt;

    // one state per byte-phase of a standard I2C write transaction
    typedef enum logic [3:0] {
        IDLE,
        START,
        DEV_ADDR,
        DEV_ACK,
        REG_ADDR,
        REG_ACK,
        REG_DATA,
        DATA_ACK,
        STOP,
        DONE
    } state_e;
    state_e state;

    logic [1:0] step;      // 4 sub-steps inside one bit period
    logic [2:0] bit_cnt;   // which bit (0-7) we are sending
    logic [7:0] tx_shift_r;
    logic [7:0] dev_addr_r;
    logic [7:0] reg_addr_r;
    logic [7:0] reg_data_r;

    // sda is open-drain: we only ever pull it low or let it float
    logic sda_drive_low;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state         <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            ack_error       <= 1'b0;
            scl           <= 1'b1;
            sda_drive_low <= 1'b0;
            clk_cnt       <= '0;
            step          <= 2'd0;
            bit_cnt       <= 3'd0;
            tx_shift_r    <= 8'd0;
            dev_addr_r    <= 8'd0;
            reg_addr_r    <= 8'd0;
            reg_data_r    <= 8'd0;

        end

        else begin
            done <= 1'b0;  // done is only high for 1 clock
            case (state)
                // wait here until the setup controller asks for a write
                IDLE : begin
                    busy          <= 1'b0;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt       <= '0;
                    step          <= 2'd0;
                    bit_cnt       <= 3'd0;

                    if (start) begin
                        ack_error  <= 1'b0;
                        dev_addr_r <= dev_addr;
                        reg_addr_r <= reg_addr;
                        reg_data_r <= reg_data;
                        busy       <= 1'b1;
                        state      <= START;
                    end
                end

                // start condition: pull sda low while scl is still high
                START : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0;
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b1;
                                tx_shift_r <= dev_addr_r;
                                bit_cnt <= 3'd0;
                                step    <= 2'd0;
                                state <= DEV_ADDR;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // send the 8-bit device address, MSB first
                DEV_ADDR : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7];
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0};
                                step <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state <= DEV_ACK;
                                end
                                else begin
                                    bit_cnt <= bit_cnt + 1'b1;
                                end
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // check the ack bit from the camera after the device address
                DEV_ACK : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= 1'b0;
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;   // camera did not pull sda low
                                end
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                tx_shift_r <= reg_addr_r;
                                bit_cnt <= 3'd0;
                                step    <= 2'd0;
                                state <= REG_ADDR;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // send the register address byte
                REG_ADDR : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7];
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0};
                                step <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state <= REG_ACK;
                                end
                                else begin
                                    bit_cnt <= bit_cnt + 1'b1;
                                end
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // ack after the register address
                REG_ACK : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= 1'b0;
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                tx_shift_r <= reg_data_r;
                                bit_cnt <= 3'd0;
                                step    <= 2'd0;
                                state <= REG_DATA;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // send the data byte
                REG_DATA : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7];
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0};
                                step <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state <= DATA_ACK;
                                end
                                else begin
                                    bit_cnt <= bit_cnt + 1'b1;
                                end
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // ack after the data byte, last one for this write
                DATA_ACK : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl <= 1'b0;
                                sda_drive_low <= 1'b0;
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl <= 1'b1;
                                if (sda == 1'b1) begin
                                        ack_error <= 1'b1;
                                end
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl <= 1'b0;
                                step <= 2'd0;
                                state <= STOP;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // stop condition: let sda go high while scl is high
                STOP : begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0 : begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b1;
                                step <= 2'd1;
                            end
                            2'd1 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0;
                                step <= 2'd3;
                            end
                            2'd3 : begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0;
                                step <= 2'd0;
                                state <= DONE;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // one write is finished, tell the setup controller and go back to idle
                DONE : begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt <= '0;
                    step    <= 2'd0;
                    state <= IDLE;
                end

                default : begin
                    state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt <= '0;
                    step    <= 2'd0;
                    bit_cnt <= 3'd0;
                end
            endcase
        end
    end
endmodule
