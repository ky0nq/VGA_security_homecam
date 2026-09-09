`timescale 1ns / 1ps

// =================================================================================
// Module: vga_cam
// Description: Integrated camera pipeline block containing OV7670 initialization,
//              frame capture (320x240 RGB565), dual-clock BRAM buffering,
//              VGA timing generation, 2x upscaling, pan/zoom readout, and RGB444 output.
//
// Internal Modules:
//   - pclk_gen            : Generates 25 MHz system clock for OV7670 XCLK.
//   - SCCB_setup_CNTL     : Automatic power-on SCCB/I2C camera configuration.
//   - OV7670_MemCNTL      : Capture camera pixels (pclk domain) to frame buffer.
//   - framebuffer         : Dual-clock 320x240 RGB565 BRAM storage.
//   - VGA_Decoder         : VGA display timing and pixel coordinate generation.
//   - rom_reader_upscale  : 2x Upscaling, pan/zoom addressing, RGB565 to RGB444 conversion.
// =================================================================================

module vga_cam #(
    parameter int CLK_FREQ_HZ       = 100_000_000, // System Clock Frequency
    parameter int I2C_FREQ_HZ       = 100_000,     // SCCB/I2C Clock Frequency
    parameter int POWERUP_DELAY_MS  = 50           // Delay before auto-configuring camera
) (
    input  logic        clk,         // System Clock (VGA, Framebuffer Read, SCCB)
    input  logic        pclk,        // OV7670 Pixel Clock (Framebuffer Write)
    input  logic        rst_n,

    // Pan & Zoom Control Inputs
    input  logic        zoom_en,
    input  logic        zoom_r,
    input  logic        zoom_l,
    input  logic        zoom_d,

    // SCCB Initialization / Status Interface
    output logic        setup_busy,
    output logic        setup_done,
    output logic        setup_error,
    output logic        cam_scl,
    inout  wire         cam_sda,

    // OV7670 Camera Hardware Capture Interface
    input  logic        cam_href,
    input  logic        cam_vsync,
    input  logic [7:0]  cam_data,

    // Video Output Stream & Camera Clock Output
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb,
    output logic        xclk         // Master Clock driving OV7670 (25 MHz)
);

    // Image & Framebuffer Dimensions
    localparam int IMG_W = 320;
    localparam int IMG_H = 240;
    localparam int DW    = 16;                           // RGB565 data width
    localparam int AW    = $clog2(IMG_W * IMG_H);        // Address width (17-bit for 76,800 pixels)

    // Power-on Reset Delay Calculation
    localparam int POWERUP_DELAY_CYCLES = (CLK_FREQ_HZ / 1000) * POWERUP_DELAY_MS;
    localparam int POWERUP_CNT_WIDTH    = $clog2(POWERUP_DELAY_CYCLES);

    //==============================================================================
    // 1. Camera XCLK Generation (100 MHz -> 25 MHz Output)
    //==============================================================================
    pclk_gen U_CAM_CLK_GEN (
        .clk  (clk),
        .rst_n(rst_n),
        .pclk (xclk)
    );

    //==============================================================================
    // 2. Power-up Delay & Automatic SCCB Initialization Trigger
    //==============================================================================
    logic [POWERUP_CNT_WIDTH-1:0] powerup_cnt;
    logic                         setup_start_auto;
    logic                         setup_started;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            powerup_cnt      <= '0;
            setup_start_auto <= 1'b0;
            setup_started    <= 1'b0;
        end else begin
            setup_start_auto <= 1'b0;
            if (!setup_started) begin
                if (powerup_cnt == POWERUP_DELAY_CYCLES - 1) begin
                    setup_start_auto <= 1'b1;
                    setup_started    <= 1'b1;
                end else begin
                    powerup_cnt <= powerup_cnt + 1'b1;
                end
            end
        end
    end

    SCCB_setup_CNTL #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .I2C_FREQ_HZ(I2C_FREQ_HZ)
    ) U_SCCB_SETUP_CNTL (
        .clk        (clk),
        .rst_n      (rst_n),
        .setup_start(setup_start_auto),
        .setup_busy (setup_busy),
        .setup_done (setup_done),
        .setup_error(setup_error),
        .scl        (cam_scl),
        .sda        (cam_sda)
    );

    //==============================================================================
    // 3. Internal Data Pipeline Signals
    //==============================================================================
    logic          we;
    logic [AW-1:0] wAddr;
    logic [DW-1:0] wData;
    logic [AW-1:0] rAddr;
    logic [DW-1:0] rData;

    logic          de;
    logic [  9:0]  x_pixel;
    logic [  9:0]  y_pixel;
    logic          w_h_sync;
    logic          w_v_sync;

    //==============================================================================
    // 4. Camera Memory Controller (Capture Logic - pclk Domain)
    //==============================================================================
    OV7670_MemCNTL #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DW   (DW)
    ) U_MEM_CNTL (
        .pclk     (pclk),
        .rst_n    (rst_n),
        .cam_href (cam_href),
        .cam_vsync(cam_vsync),
        .cam_data (cam_data),
        .we       (we),
        .wAddr    (wAddr),
        .wData    (wData)
    );

    //==============================================================================
    // 5. Dual-Clock Frame Buffer (CDC Bridge: Write on pclk, Read on clk)
    //==============================================================================
    framebuffer #(
        .IMG_W(IMG_W),
        .IMG_H(IMG_H),
        .DW   (DW)
    ) U_FRAMEBUFFER (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (clk),
        .rAddr(rAddr),
        .rData(rData)
    );

    //==============================================================================
    // 6. VGA Display Timing & Coordinate Generator (clk Domain)
    //==============================================================================
    VGA_Decoder U_VGA_DEC (
        .clk    (clk),
        .rst_n  (rst_n),
        .h_sync (w_h_sync),
        .v_sync (w_v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    //==============================================================================
    // 7. Upscaler & Pan/Zoom Frame Reader (clk Domain)
    //==============================================================================
    rom_reader_upscale U_READER_UPSCALE (
        .clk    (clk),
        .rst_n  (rst_n),
        .zoom_en(zoom_en),
        .zoom_r (zoom_r),
        .zoom_l (zoom_l),
        .zoom_d (zoom_d),
        .de     (de),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr   (rAddr),
        .px_data(rData),
        .o_rgb  (o_rgb)
    );

    //==============================================================================
    // 8. Sync Signal Pipeline Matching (1 Clock Delay to Match Reader Latency)
    //==============================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_h_sync <= 1'b1;
            o_v_sync <= 1'b1;
        end else begin
            o_h_sync <= w_h_sync;
            o_v_sync <= w_v_sync;
        end
    end

endmodule
