`timescale 1ns / 1ps

// =================================================================================
// Module: I2C_master
// Send configuration settings (address and data) to the OV7670 camera.
// =================================================================================

module I2C_master #(
    parameter integer CLK_FREQ_HZ = 100_000_000,  // FPGA main clock speed
    parameter integer I2C_FREQ_HZ = 100_000       // Target I2C communication speed
)(
    input  logic       clk,
    input  logic       rst_n,

    // Start signal: 1-clock pulse to begin sending data
    input  logic       start,

    // 8-bit camera device address
    input  logic [7:0] dev_addr,

    // Camera register address and setting value
    input  logic [7:0] reg_addr,
    input  logic [7:0] reg_data,

    // Status signals sent back to main controller
    output logic       busy,
    output logic       done,
    output logic       ack_error,

    // Hardware pin connections to camera
    output logic       scl,
    inout  wire        sda
);

    // Calculate timing: divide 1 I2C cycle into 4 small steps
    localparam integer TICK_DIV_CALC = CLK_FREQ_HZ / (I2C_FREQ_HZ * 4);
    localparam integer TICK_DIV      = (TICK_DIV_CALC < 1) ? 1 : TICK_DIV_CALC;
    localparam integer CLK_CNT_WIDTH = (TICK_DIV <= 1) ? 1 : $clog2(TICK_DIV);

    logic [CLK_CNT_WIDTH-1:0] clk_cnt;

    // States for I2C data transfer
    typedef enum logic [3:0] {
        IDLE,
        START,      // Send START signal (SDA goes Low while SCL is High)
        DEV_ADDR,   // Send 8-bit device address
        DEV_ACK,    // Check camera answer for device address
        REG_ADDR,   // Send 8-bit register address
        REG_ACK,    // Check camera answer for register address
        REG_DATA,   // Send 8-bit setting data
        DATA_ACK,   // Check camera answer for setting data
        STOP,       // Send STOP signal (SDA goes High while SCL is High)
        DONE        // Finish transmission
    } state_e;
    state_e state;

    logic [1:0] step;          // 4-step phase counter (0: change data, 1-2: SCL High, 3: SCL Low)
    logic [2:0] bit_cnt;       // Count transmitted bits (7 down to 0)
    logic [7:0] tx_shift_r;    // Shift register to output bits one by one
    logic [7:0] dev_addr_r;    // Saved device address
    logic [7:0] reg_addr_r;    // Saved register address
    logic [7:0] reg_data_r;    // Saved setting data

    // Output pin control: Drive line Low (0) or release line (High-Z)
    logic sda_drive_low;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            ack_error     <= 1'b0;
            scl           <= 1'b1;
            sda_drive_low <= 1'b0; // Release data line
            clk_cnt       <= '0;
            step          <= 2'd0;
            bit_cnt       <= 3'd0;
            tx_shift_r    <= 8'd0;
            dev_addr_r    <= 8'd0;
            reg_addr_r    <= 8'd0;
            reg_data_r    <= 8'd0;
        end
        else begin
            done <= 1'b0; // Keep done signal High for only 1 clock cycle

            case (state)
                IDLE: begin
                    busy          <= 1'b0;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt       <= '0;
                    step          <= 2'd0;
                    bit_cnt       <= 3'd0;

                    // Save inputs and start working when start signal comes
                    if (start) begin
                        ack_error  <= 1'b0;
                        dev_addr_r <= dev_addr;
                        reg_addr_r <= reg_addr;
                        reg_data_r <= reg_data;
                        busy       <= 1'b1;
                        state      <= START;
                    end
                end

                // Step 1: Create I2C START signal
                START: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0; // Keep SDA High
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b1; // Pull SDA Low (START signal)
                                step          <= 2'd2;
                            end
                            2'd2: begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b1;
                                step          <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;    // Pull SCL Low to prepare data
                                tx_shift_r <= dev_addr_r;
                                bit_cnt    <= 3'd0;
                                step       <= 2'd0;
                                state      <= DEV_ADDR;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Step 2: Send device address bit by bit (from bit 7 to bit 0)
                DEV_ADDR: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7]; // Set SDA data bit
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1; // Set clock High to show data is valid
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl  <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0}; // Shift next bit
                                step       <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state   <= DEV_ACK;
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

                // Step 3: Read camera response (ACK) for device address
                DEV_ACK: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b0; // Release line for camera answer
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl <= 1'b1;
                                // Read response: High means error (no answer)
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;
                                tx_shift_r <= reg_addr_r; // Load register address
                                bit_cnt    <= 3'd0;
                                step       <= 2'd0;
                                state      <= REG_ADDR;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Step 4: Send register address bit by bit
                REG_ADDR: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7];
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl  <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0};
                                step       <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state   <= REG_ACK;
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

                // Step 5: Read camera response (ACK) for register address
                REG_ACK: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b0;
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl <= 1'b1;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;
                                tx_shift_r <= reg_data_r; // Load setting value
                                bit_cnt    <= 3'd0;
                                step       <= 2'd0;
                                state      <= REG_DATA;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Step 6: Send setting value bit by bit
                REG_DATA: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= ~tx_shift_r[7];
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl  <= 1'b1;
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl        <= 1'b0;
                                tx_shift_r <= {tx_shift_r[6:0], 1'b0};
                                step       <= 2'd0;
                                if (bit_cnt == 3'd7) begin
                                    bit_cnt <= 3'd0;
                                    state   <= DATA_ACK;
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

                // Step 7: Read camera response (ACK) for setting value
                DATA_ACK: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b0;
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl  <= 1'b1;
                                step <= 2'd2;
                            end
                            2'd2: begin
                                scl <= 1'b1;
                                if (sda == 1'b1) begin
                                    ack_error <= 1'b1;
                                end
                                step <= 2'd3;
                            end
                            2'd3: begin
                                scl   <= 1'b0;
                                step  <= 2'd0;
                                state <= STOP;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Step 8: Create I2C STOP signal
                STOP: begin
                    if (clk_cnt == TICK_DIV - 1) begin
                        clk_cnt <= '0;
                        case (step)
                            2'd0: begin
                                scl           <= 1'b0;
                                sda_drive_low <= 1'b1; // Pull SDA Low first
                                step          <= 2'd1;
                            end
                            2'd1: begin
                                scl           <= 1'b1; // Set SCL High
                                sda_drive_low <= 1'b1;
                                step          <= 2'd2;
                            end
                            2'd2: begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0; // Release SDA High (STOP signal)
                                step          <= 2'd3;
                            end
                            2'd3: begin
                                scl           <= 1'b1;
                                sda_drive_low <= 1'b0;
                                step          <= 2'd0;
                                state         <= DONE;
                            end
                        endcase
                    end
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                // Step 9: Tell main controller that transfer is complete
                DONE: begin
                    busy          <= 1'b0;
                    done          <= 1'b1;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt       <= '0;
                    step          <= 2'd0;
                    state         <= IDLE;
                end

                // Safety reset if state goes wrong
                default: begin
                    state         <= IDLE;
                    busy          <= 1'b0;
                    done          <= 1'b0;
                    scl           <= 1'b1;
                    sda_drive_low <= 1'b0;
                    clk_cnt       <= '0;
                    step          <= 2'd0;
                    bit_cnt       <= 3'd0;
                end
            endcase
        end
    end
endmodule
