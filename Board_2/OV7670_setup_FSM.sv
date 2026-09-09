`timescale 1ns / 1ps

// =================================================================================
// Module: OV7670_setup_CNTL
// Purpose: Send a sequence of configuration settings (67 registers) to the OV7670
//          camera through the I2C Master module.
// =================================================================================

module OV7670_setup_CNTL #(
    parameter integer CLK_FREQ_HZ = 100_000_000 // System clock frequency (100 MHz)
)(
    input  logic        clk,                    // System clock
    input  logic        rst_n,                  // Active-low reset signal
    input  logic        setup_start,            // Start button / trigger signal

    // ============================================================
    // I2C Master -> OV7670 Setup Controller
    // ============================================================
    input  logic        i2c_busy,               // High when I2C is sending data
    input  logic        i2c_done,               // High when I2C finishes sending
    input  logic        i2c_ack_error,          // High if camera does not acknowledge

    // ============================================================
    // OV7670 Setup Controller -> I2C Master
    // ============================================================
    output logic        i2c_start,              // Pulse to start I2C transmission
    output logic [7:0]  dev_addr,               // Camera I2C slave address
    output logic [7:0]  reg_addr,               // Register address to write
    output logic [7:0]  reg_data,               // Data value to write

    // ============================================================
    // Setup Status Outputs
    // ============================================================
    output logic        setup_busy,             // High while setting up the camera
    output logic        setup_done,             // High when all settings are sent
    output logic        setup_error             // High if camera communication fails
);

    // ============================================================
    // Camera Device Address (0x42 for Write)
    // ============================================================
    localparam logic [7:0] OV7670_DEV_ADDR = 8'h42;

    // ============================================================
    // Total Number of Settings (Registers)
    // ============================================================
    localparam integer NUM_CONFIG = 67;
    localparam integer CONFIG_IDX_WIDTH = (NUM_CONFIG <= 1) ? 1 : $clog2(NUM_CONFIG);
    logic [CONFIG_IDX_WIDTH-1:0] config_idx;    // Index of the current setting

    // ============================================================
    // Camera Reset Delay (30ms wait time after soft reset)
    // ============================================================
    localparam integer RESET_DELAY_CYCLES = CLK_FREQ_HZ / 1000 * 30; // 30ms counter value
    localparam integer DELAY_CNT_WIDTH    = $clog2(RESET_DELAY_CYCLES + 1); 
    logic [DELAY_CNT_WIDTH-1:0] delay_cnt;      // Delay counter variable

    // State machine states
    typedef enum logic [2:0] {
        IDLE,   // Waiting for start signal
        LOAD,   // Load register address and data
        SEND,   // Trigger I2C transfer
        WAIT,   // Wait for I2C transfer to finish
        DELAY,  // Wait 30ms after soft reset
        NEXT,   // Move to next register setting
        FINISH, // All settings successfully sent
        ERROR   // Failed to communicate with camera
    } state_e;
    state_e state;

    // ------------------------------------------------------------
    // Clean up external button input (Synchronize and detect press)
    // ------------------------------------------------------------
    logic setup_start_meta;
    logic setup_start_sync;
    logic setup_start_prev;
    wire  setup_start_pulse;

    // Detect when button is newly pressed (1-clock pulse)
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

    // ============================================================
    // Camera Configuration List (Lookup Table)
    // Register Address and Data table based on index
    // ============================================================
    always_comb begin
        reg_addr = 8'h00;
        reg_data = 8'h00;
        case (config_idx)

             0 : begin reg_addr = 8'h12; reg_data = 8'h80; end // Soft Reset
             1 : begin reg_addr = 8'h3A; reg_data = 8'h04; end // Output format options
             2 : begin reg_addr = 8'h12; reg_data = 8'h00; end // Clear reset
             3 : begin reg_addr = 8'h13; reg_data = 8'hE7; end // Enable AGC / AEC / AWB
             4 : begin reg_addr = 8'h6F; reg_data = 8'h9F; end // AWB control
             5 : begin reg_addr = 8'hB0; reg_data = 8'h84; end // Color mode setting
             6 : begin reg_addr = 8'h70; reg_data = 8'h3A; end // Clock divider settings
             7 : begin reg_addr = 8'h71; reg_data = 8'h35; end // Clock divider settings
             8 : begin reg_addr = 8'h72; reg_data = 8'h11; end // Clock divider settings
             9 : begin reg_addr = 8'h73; reg_data = 8'hF0; end // Clock divider settings

            10 : begin reg_addr = 8'h7A; reg_data = 8'h20; end // Gamma curve 1
            11 : begin reg_addr = 8'h7B; reg_data = 8'h10; end // Gamma curve 2
            12 : begin reg_addr = 8'h7C; reg_data = 8'h1E; end // Gamma curve 3
            13 : begin reg_addr = 8'h7D; reg_data = 8'h35; end // Gamma curve 4
            14 : begin reg_addr = 8'h7E; reg_data = 8'h5A; end // Gamma curve 5
            15 : begin reg_addr = 8'h7F; reg_data = 8'h69; end // Gamma curve 6
            16 : begin reg_addr = 8'h80; reg_data = 8'h76; end // Gamma curve 7
            17 : begin reg_addr = 8'h81; reg_data = 8'h80; end // Gamma curve 8
            18 : begin reg_addr = 8'h82; reg_data = 8'h88; end // Gamma curve 9
            19 : begin reg_addr = 8'h83; reg_data = 8'h8F; end // Gamma curve 10
            20 : begin reg_addr = 8'h84; reg_data = 8'h96; end // Gamma curve 11
            21 : begin reg_addr = 8'h85; reg_data = 8'hA3; end // Gamma curve 12
            22 : begin reg_addr = 8'h86; reg_data = 8'hAF; end // Gamma curve 13
            23 : begin reg_addr = 8'h87; reg_data = 8'hC4; end // Gamma curve 14
            24 : begin reg_addr = 8'h88; reg_data = 8'hD7; end // Gamma curve 15
            25 : begin reg_addr = 8'h89; reg_data = 8'hE8; end // Gamma curve 16

            26 : begin reg_addr = 8'h00; reg_data = 8'h00; end // Gain control
            27 : begin reg_addr = 8'h10; reg_data = 8'h00; end // Exposure control
            28 : begin reg_addr = 8'h0D; reg_data = 8'h40; end // Reserved control
            29 : begin reg_addr = 8'h14; reg_data = 8'h18; end // Gain limit
            30 : begin reg_addr = 8'hA5; reg_data = 8'h05; end // 50Hz band filter
            31 : begin reg_addr = 8'hAB; reg_data = 8'h07; end // 60Hz band filter
            32 : begin reg_addr = 8'h24; reg_data = 8'h95; end // AGC upper limit
            33 : begin reg_addr = 8'h25; reg_data = 8'h33; end // AGC lower limit
            34 : begin reg_addr = 8'h26; reg_data = 8'hE3; end // AGC fast window

            35 : begin reg_addr = 8'h9F; reg_data = 8'h78; end // Auto exposure high threshold
            36 : begin reg_addr = 8'hA0; reg_data = 8'h68; end // Auto exposure low threshold
            37 : begin reg_addr = 8'hA1; reg_data = 8'h03; end // Auto exposure options
            38 : begin reg_addr = 8'hA6; reg_data = 8'hD8; end // Gain step size 1
            39 : begin reg_addr = 8'hA7; reg_data = 8'hD8; end // Gain step size 2
            40 : begin reg_addr = 8'hA8; reg_data = 8'hF0; end // Gain step size 3
            41 : begin reg_addr = 8'hA9; reg_data = 8'h90; end // Gain step size 4
            42 : begin reg_addr = 8'hAA; reg_data = 8'h94; end // AWB green gain

            43 : begin reg_addr = 8'h12; reg_data = 8'h14; end // Set output format (QVGA, RGB)
            44 : begin reg_addr = 8'h0C; reg_data = 8'h04; end // Output format adjustment
            45 : begin reg_addr = 8'h3E; reg_data = 8'h19; end // Pixel clock scaling
            46 : begin reg_addr = 8'h70; reg_data = 8'h3A; end // Scaling control 1
            47 : begin reg_addr = 8'h71; reg_data = 8'h35; end // Scaling control 2
            48 : begin reg_addr = 8'h72; reg_data = 8'h11; end // Scaling control 3
            49 : begin reg_addr = 8'h73; reg_data = 8'hF1; end // Scaling control 4
            50 : begin reg_addr = 8'hA2; reg_data = 8'h02; end // Pixel clock delay

            // QVGA Output Window Settings (Image frame start / stop coordinates)
            51 : begin reg_addr = 8'h17; reg_data = 8'h16; end // Horizontal start high bits
            52 : begin reg_addr = 8'h18; reg_data = 8'h04; end // Horizontal stop high bits
            53 : begin reg_addr = 8'h32; reg_data = 8'h24; end // HREF edge adjustment
            54 : begin reg_addr = 8'h19; reg_data = 8'h02; end // Vertical start high bits
            55 : begin reg_addr = 8'h1A; reg_data = 8'h7A; end // Vertical stop high bits
            56 : begin reg_addr = 8'h03; reg_data = 8'h0A; end // VREF edge adjustment
            57 : begin reg_addr = 8'h40; reg_data = 8'hD0; end // Color matrix enable (RGB565)
            58 : begin reg_addr = 8'h8C; reg_data = 8'h00; end // Disable color bar pattern
            59 : begin reg_addr = 8'h3D; reg_data = 8'hC0; end // Gamma option enable

            // RGB565 colour matrix supplied for the OV7670 RGB output mode.
            60 : begin reg_addr = 8'h4F; reg_data = 8'hB3; end // MTX1
            61 : begin reg_addr = 8'h50; reg_data = 8'hB3; end // MTX2
            62 : begin reg_addr = 8'h51; reg_data = 8'h00; end // MTX3
            63 : begin reg_addr = 8'h52; reg_data = 8'h3D; end // MTX4
            64 : begin reg_addr = 8'h53; reg_data = 8'hA7; end // MTX5
            65 : begin reg_addr = 8'h54; reg_data = 8'hE4; end // MTX6
            66 : begin reg_addr = 8'h58; reg_data = 8'h9E; end // MTXS signs / auto contrast center

            default : begin
                reg_addr = 8'h00;
                reg_data = 8'h00;
            end

        endcase
    end

    // ============================================================
    // Controller State Machine Sequential Logic
    // ============================================================
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
            i2c_start <= 1'b0;                  // Default: I2C pulse lasts for 1 clock cycle

            case (state)

                // State 1: Wait for start command
                IDLE : begin
                    setup_busy <= 1'b0;
                    if (setup_start_pulse) begin
                        config_idx  <= '0;
                        delay_cnt   <= '0;
                        setup_busy  <= 1'b1;
                        setup_done  <= 1'b0;
                        setup_error <= 1'b0;
                        state       <= LOAD;
                    end
                end

                // State 2: Select register address and data from table
                LOAD : begin
                    state <= SEND;
                end

                // State 3: Send start pulse to I2C Master when it is free
                SEND : begin
                    if (!i2c_busy) begin
                        i2c_start <= 1'b1;
                        state     <= WAIT;
                    end
                end

                // State 4: Wait until I2C transfer finishes
                WAIT : begin
                    if (i2c_done) begin
                        // Check if camera failed to respond (ACK error)
                        if (i2c_ack_error) begin
                            state <= ERROR;
                        end
                        // Special case: Wait 30ms after soft reset (Register index 0)
                        else if (config_idx == 0) begin
                            delay_cnt <= '0;
                            state     <= DELAY;
                        end
                        // Move to next register if write was successful
                        else begin
                            state <= NEXT;
                        end
                    end
                end

                // State 5: Wait 30ms for the camera to finish internal reset
                DELAY : begin
                    if (delay_cnt == RESET_DELAY_CYCLES - 1) begin
                        delay_cnt <= '0;
                        state     <= NEXT;
                    end
                    else begin
                        delay_cnt <= delay_cnt + 1'b1;
                    end
                end

                // State 6: Update index to the next register setting
                NEXT : begin
                    // Finish if all 67 registers are configured
                    if (config_idx == NUM_CONFIG - 1) begin
                        state <= FINISH;
                    end
                    // Load the next register
                    else begin
                        config_idx <= config_idx + 1'b1;
                        state      <= LOAD;
                    end
                end

                // State 7: Setup complete
                FINISH : begin
                    setup_busy <= 1'b0;
                    setup_done <= 1'b1;         // Keep done signal high for status LED
                    state      <= IDLE;
                end

                // State 8: Communication error state
                ERROR : begin
                    setup_busy  <= 1'b0;
                    setup_error <= 1'b1;        // Keep error signal high
                    // Allow retry if start pulse is received again
                    if (setup_start_pulse) begin
                        config_idx  <= '0;
                        delay_cnt   <= '0;
                        setup_busy  <= 1'b1;
                        setup_done  <= 1'b0;
                        setup_error <= 1'b0;
                        state       <= LOAD;
                    end
                end

                default : begin
                    state       <= IDLE;
                    config_idx  <= '0;
                    delay_cnt   <= '0;
                    i2c_start   <= 1'b0;
                    setup_busy  <= 1'b0;
                    setup_done  <= 1'b0;
                    setup_error <= 1'b0;
                end
            endcase
        end
    end

endmodule
