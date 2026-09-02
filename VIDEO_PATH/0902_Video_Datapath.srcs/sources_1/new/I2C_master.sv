`timescale 1ns / 1ps

module I2C_master #(
    parameter integer CLK_FREQ_HZ = 100_000_000,  // FPGA Clock
    parameter integer I2C_FREQ_HZ = 100_000       // SCCB SCL Frequency
)(
    input  logic       clk,
    input  logic       rst_n,

    // OV7670 Setup Controller에서 1-clock pulse
    input  logic       start,

    // 8-bit Device Address
    // OV7670 Write = 8'h42
    input  logic [7:0] dev_addr,

    // Register Address / Data
    input  logic [7:0] reg_addr,
    input  logic [7:0] reg_data,

    // I2C Master -> OV7670 Setup Controller
    output logic       busy,
    output logic       done,
    output logic       ack_error,

    // SCCB Interface
    output logic       scl,
    inout  wire        sda
);

    localparam integer TICK_DIV_CALC = CLK_FREQ_HZ / (I2C_FREQ_HZ * 4);
    localparam integer TICK_DIV = (TICK_DIV_CALC < 1) ? 1 : TICK_DIV_CALC;
    localparam integer CLK_CNT_WIDTH = (TICK_DIV <= 1) ? 1 : $clog2(TICK_DIV);

    logic [CLK_CNT_WIDTH-1:0] clk_cnt;

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

    logic [1:0] step;
    logic [2:0] bit_cnt;
    logic [7:0] tx_shift_r;
    logic [7:0] dev_addr_r;
    logic [7:0] reg_addr_r;
    logic [7:0] reg_data_r;

    // SDA open-drain
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
            done <= 1'b0;
            case (state)
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
                                    ack_error <= 1'b1;
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