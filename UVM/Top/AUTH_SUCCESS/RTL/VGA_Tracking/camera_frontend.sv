`timescale 1ns / 1ps

module camera_frontend #(
    parameter integer IMG_WIDTH = 320,
    parameter integer IMG_HEIGHT = 240,

    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer I2C_FREQ_HZ = 100_000,
    parameter integer POWERUP_DELAY_MS = 50,

    parameter integer ADDR_WIDTH =
        $clog2(IMG_WIDTH * IMG_HEIGHT)
)(
    // Clock / Reset
    input  logic                  clk,
    input  logic                  pclk,
    input  logic                  rst_n,

    // OV7670 Pixel Interface
    input  logic                  cam_href,
    input  logic                  cam_vsync,
    input  logic [7:0]            cam_data,

    // OV7670 Clock
    output logic                  xclk,

    // OV7670 SCCB Interface
    output logic                  cam_scl,
    inout  wire                   cam_sda,

    // OV7670 Setup Status
    output logic                  o_setup_busy,
    output logic                  o_setup_done,
    output logic                  o_setup_error,

    // RGB565 Capture Output
    output logic                  o_frame_we,
    output logic [ADDR_WIDTH-1:0] o_frame_waddr,
    output logic [15:0]           o_frame_rgb565
);

    // =========================================================
    // Power-up Delay
    // =========================================================
    localparam integer POWERUP_DELAY_CYCLES =
        (CLK_FREQ_HZ / 1000) * POWERUP_DELAY_MS;

    localparam integer POWERUP_COUNT_WIDTH =
        (POWERUP_DELAY_CYCLES <= 1)
        ? 1
        : $clog2(POWERUP_DELAY_CYCLES + 1);

    logic [POWERUP_COUNT_WIDTH-1:0] powerup_count;
    logic setup_start_auto;
    logic setup_started;

    // Wait for POWERUP_DELAY_MS after power-up,
    // then send one SCCB setup pulse.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            powerup_count    <= '0;
            setup_start_auto <= 1'b0;
            setup_started    <= 1'b0;
        end else begin
            // setup_start is a one-cycle pulse.
            setup_start_auto <= 1'b0;

            if (!setup_started) begin
                if (POWERUP_DELAY_CYCLES <= 1) begin
                    setup_start_auto <= 1'b1;
                    setup_started    <= 1'b1;
                end else if (
                    powerup_count >= POWERUP_DELAY_CYCLES - 1
                ) begin
                    setup_start_auto <= 1'b1;
                    setup_started    <= 1'b1;
                end else begin
                    powerup_count <= powerup_count + 1'b1;
                end
            end
        end
    end

    // =========================================================
    // OV7670 XCLK Generator
    //
    // camera_clk_gen converts 100 MHz to 25 MHz XCLK.
    // =========================================================
    camera_clk_gen U_CAMERA_CLK_GEN (
        .clk  (clk),
        .rst_n(rst_n),
        .xclk (xclk)
    );

    // =========================================================
    // OV7670 SCCB Configuration
    // =========================================================
    VGA_SCCB_setup_CNTL #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(I2C_FREQ_HZ)
    ) U_SCCB_SETUP_CNTL (
        .clk  (clk),
        .rst_n(rst_n),

        .setup_start(setup_start_auto),

        .setup_busy (o_setup_busy),
        .setup_done (o_setup_done),
        .setup_error(o_setup_error),

        .scl(cam_scl),
        .sda(cam_sda)
    );

    // =========================================================
    // OV7670 RGB565 Capture
    //
    // Combine two 8-bit camera samples into one RGB565 pixel.
    // =========================================================
    VGA_OV7670_MemCNTL #(
        .IMG_W(IMG_WIDTH),
        .IMG_H(IMG_HEIGHT),
        .DW   (16),
        .AW   (ADDR_WIDTH)
    ) U_OV7670_MEM_CNTL (
        .pclk (pclk),
        .rst_n(rst_n),

        .cam_href (cam_href),
        .cam_vsync(cam_vsync),
        .cam_data (cam_data),

        .we   (o_frame_we),
        .wAddr(o_frame_waddr),
        .wData(o_frame_rgb565)
    );

endmodule
