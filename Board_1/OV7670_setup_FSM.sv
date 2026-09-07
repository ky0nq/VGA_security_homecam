`timescale 1ns / 1ps

// Goes through the camera register list one by one and sends each one with the I2C master.

module OV7670_setup_CNTL #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic       clk,
    input  logic       rst_n,
    input  logic       setup_start,

    // status coming back from the I2C master
    input  logic       i2c_busy,
    input  logic       i2c_done,
    input  logic       i2c_ack_error,

    // request going out to the I2C master
    output logic       i2c_start,
    output logic [7:0] dev_addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data,

    // status for the top level
    output logic       setup_busy,
    output logic       setup_done,
    output logic       setup_error
);

    // OV7670 write address (7-bit address 0x21 shifted left + write bit)
    localparam logic [7:0] OV7670_DEV_ADDR = 8'h42;

    // how many registers we need to send in total
    localparam integer NUM_CONFIG = 67;
    localparam integer CONFIG_IDX_WIDTH = (NUM_CONFIG <= 1) ? 1 : $clog2(NUM_CONFIG);
    logic [CONFIG_IDX_WIDTH-1:0] config_idx;

    // after the reset register (0x12 = 0x80) the camera needs about 30ms before anything else
    localparam integer RESET_DELAY_CYCLES = CLK_FREQ_HZ / 1000 * 30;         // 30ms
    localparam integer DELAY_CNT_WIDTH    = $clog2(RESET_DELAY_CYCLES + 1);
    logic [DELAY_CNT_WIDTH-1:0] delay_cnt;

    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        SEND,
        WAIT,
        DELAY,
        NEXT,
        FINISH,
        ERROR
    } state_e;
    state_e state;

    // Synchronize the asynchronous push-button input and create one start pulse.
    logic setup_start_meta;
    logic setup_start_sync;
    logic setup_start_prev;
    wire  setup_start_pulse;

    assign setup_start_pulse = setup_start_sync & ~setup_start_prev;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            setup_start_meta <= 1'b0;
            setup_start_sync <= 1'b0;
            setup_start_prev <= 1'b0;
        end
        else begin
            setup_start_meta <= setup_start;
            setup_start_sync <= setup_start_meta;
            setup_start_prev <= setup_start_sync;
        end
    end

    assign dev_addr = OV7670_DEV_ADDR;

    // Register table, recorded with a logic analyzer while a known-good driver
    // ran the camera. reg_addr/reg_data just depend on config_idx.
    always_comb begin
        reg_addr = 8'h00;
        reg_data = 8'h00;
        case (config_idx)

             0 : begin reg_addr = 8'h12; reg_data = 8'h80; end  // software reset
             1 : begin reg_addr = 8'h3A; reg_data = 8'h04; end
             2 : begin reg_addr = 8'h12; reg_data = 8'h00; end
             3 : begin reg_addr = 8'h13; reg_data = 8'hE7; end
             4 : begin reg_addr = 8'h6F; reg_data = 8'h9F; end
             5 : begin reg_addr = 8'hB0; reg_data = 8'h84; end
             6 : begin reg_addr = 8'h70; reg_data = 8'h3A; end
             7 : begin reg_addr = 8'h71; reg_data = 8'h35; end
             8 : begin reg_addr = 8'h72; reg_data = 8'h11; end
             9 : begin reg_addr = 8'h73; reg_data = 8'hF0; end

            // gamma curve values
            10 : begin reg_addr = 8'h7A; reg_data = 8'h20; end
            11 : begin reg_addr = 8'h7B; reg_data = 8'h10; end
            12 : begin reg_addr = 8'h7C; reg_data = 8'h1E; end
            13 : begin reg_addr = 8'h7D; reg_data = 8'h35; end
            14 : begin reg_addr = 8'h7E; reg_data = 8'h5A; end
            15 : begin reg_addr = 8'h7F; reg_data = 8'h69; end
            16 : begin reg_addr = 8'h80; reg_data = 8'h76; end
            17 : begin reg_addr = 8'h81; reg_data = 8'h80; end
            18 : begin reg_addr = 8'h82; reg_data = 8'h88; end
            19 : begin reg_addr = 8'h83; reg_data = 8'h8F; end
            20 : begin reg_addr = 8'h84; reg_data = 8'h96; end
            21 : begin reg_addr = 8'h85; reg_data = 8'hA3; end
            22 : begin reg_addr = 8'h86; reg_data = 8'hAF; end
            23 : begin reg_addr = 8'h87; reg_data = 8'hC4; end
            24 : begin reg_addr = 8'h88; reg_data = 8'hD7; end
            25 : begin reg_addr = 8'h89; reg_data = 8'hE8; end

            // gain / AEC base values
            26 : begin reg_addr = 8'h00; reg_data = 8'h00; end
            27 : begin reg_addr = 8'h10; reg_data = 8'h00; end
            28 : begin reg_addr = 8'h0D; reg_data = 8'h40; end
            29 : begin reg_addr = 8'h14; reg_data = 8'h18; end
            30 : begin reg_addr = 8'hA5; reg_data = 8'h05; end
            31 : begin reg_addr = 8'hAB; reg_data = 8'h07; end
            32 : begin reg_addr = 8'h24; reg_data = 8'h95; end
            33 : begin reg_addr = 8'h25; reg_data = 8'h33; end
            34 : begin reg_addr = 8'h26; reg_data = 8'hE3; end

            // histogram based AEC/AGC settings
            35 : begin reg_addr = 8'h9F; reg_data = 8'h78; end
            36 : begin reg_addr = 8'hA0; reg_data = 8'h68; end
            37 : begin reg_addr = 8'hA1; reg_data = 8'h03; end
            38 : begin reg_addr = 8'hA6; reg_data = 8'hD8; end
            39 : begin reg_addr = 8'hA7; reg_data = 8'hD8; end
            40 : begin reg_addr = 8'hA8; reg_data = 8'hF0; end
            41 : begin reg_addr = 8'hA9; reg_data = 8'h90; end
            42 : begin reg_addr = 8'hAA; reg_data = 8'h94; end

            // switch to RGB output and QVGA scaling
            43 : begin reg_addr = 8'h12; reg_data = 8'h14; end
            44 : begin reg_addr = 8'h0C; reg_data = 8'h04; end
            45 : begin reg_addr = 8'h3E; reg_data = 8'h19; end
            46 : begin reg_addr = 8'h70; reg_data = 8'h3A; end
            47 : begin reg_addr = 8'h71; reg_data = 8'h35; end
            48 : begin reg_addr = 8'h72; reg_data = 8'h11; end
            49 : begin reg_addr = 8'h73; reg_data = 8'hF1; end
            50 : begin reg_addr = 8'hA2; reg_data = 8'h02; end

            // QVGA output window. HREF/VREF contain the low bits of
            // HSTART/HSTOP and VSTART/VSTOP, so these values are one set.
            51 : begin reg_addr = 8'h17; reg_data = 8'h16; end
            52 : begin reg_addr = 8'h18; reg_data = 8'h04; end
            53 : begin reg_addr = 8'h32; reg_data = 8'h24; end
            54 : begin reg_addr = 8'h19; reg_data = 8'h02; end
            55 : begin reg_addr = 8'h1A; reg_data = 8'h7A; end
            56 : begin reg_addr = 8'h03; reg_data = 8'h0A; end
            57 : begin reg_addr = 8'h40; reg_data = 8'hD0; end
            58 : begin reg_addr = 8'h8C; reg_data = 8'h00; end
            59 : begin reg_addr = 8'h3D; reg_data = 8'hC0; end

            // Color matrix (saturation). 0x4F~0x54 = MTX1~MTX6, 0x58 = MTXS.
            // Default reset values are tuned for YUV, so RGB565 looks washed
            // out unless we set these after picking RGB in COM7.
            60 : begin reg_addr = 8'h4F; reg_data = 8'hB3; end
            61 : begin reg_addr = 8'h50; reg_data = 8'hB3; end
            62 : begin reg_addr = 8'h51; reg_data = 8'h00; end
            63 : begin reg_addr = 8'h52; reg_data = 8'h3D; end
            64 : begin reg_addr = 8'h53; reg_data = 8'hA7; end
            65 : begin reg_addr = 8'h54; reg_data = 8'hE4; end
            66 : begin reg_addr = 8'h58; reg_data = 8'h9E; end

            default : begin
                reg_addr = 8'h00;
                reg_data = 8'h00;
            end

        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            config_idx  <= '0;
            delay_cnt   <= '0;
            i2c_start   <= 1'b0;
            setup_busy  <= 1'b0;
            setup_done  <= 1'b0;
            setup_error <= 1'b0;
        end
        else begin
            // i2c_start is only high for 1 clock
            i2c_start <= 1'b0;
            case (state)

                // wait for the start button before doing anything
                IDLE : begin
                    setup_busy <= 1'b0;
                    if (setup_start_pulse) begin
                        config_idx  <= '0;
                        delay_cnt   <= '0;
                        setup_busy  <= 1'b1;
                        setup_done  <= 1'b0;
                        setup_error <= 1'b0;
                        state <= LOAD;
                    end
                end

                // just move on, reg_addr/reg_data are already picked by config_idx
                LOAD : begin
                    state <= SEND;
                end

                // wait until the I2C master is free, then start it
                SEND : begin
                    if (!i2c_busy) begin
                        i2c_start <= 1'b1;
                        state <= WAIT;
                    end
                end

                // wait for the I2C master to finish this write
                WAIT : begin
                    if (i2c_done) begin
                        if (i2c_ack_error) begin
                            state <= ERROR;
                        end
                        // register 0 is the software reset, needs an extra delay after it
                        else if (config_idx == 0) begin
                            delay_cnt <= '0;
                            state     <= DELAY;
                        end
                        else begin
                            state <= NEXT;
                        end
                    end
                end

                // wait 30ms after the software reset before sending more registers
                DELAY : begin
                    if (delay_cnt == RESET_DELAY_CYCLES - 1) begin
                        delay_cnt <= '0;
                        state <= NEXT;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end

                // pick the next register, or finish if that was the last one
                NEXT : begin
                    if (config_idx == NUM_CONFIG - 1) begin
                        state <= FINISH;
                    end
                    else begin
                        config_idx <= config_idx + 1'b1;
                        state <= LOAD;
                    end
                end

                // all registers sent successfully
                FINISH : begin
                    setup_busy <= 1'b0;
                    // Hold until reset or the next setup request for LED visibility.
                    setup_done <= 1'b1;
                    state <= IDLE;
                end

                // the camera did not ack one of the writes
                ERROR : begin
                    setup_busy  <= 1'b0;
                    setup_error <= 1'b1;
                    if (setup_start_pulse) begin
                        config_idx  <= '0;
                        delay_cnt   <= '0;
                        setup_busy  <= 1'b1;
                        setup_done  <= 1'b0;
                        setup_error <= 1'b0;
                        state <= LOAD;
                    end
                end

                default : begin
                    state <= IDLE;
                    config_idx <= '0;
                    delay_cnt  <= '0;
                    i2c_start <= 1'b0;
                    setup_busy  <= 1'b0;
                    setup_done  <= 1'b0;
                    setup_error <= 1'b0;
                end
            endcase
        end
    end

endmodule
