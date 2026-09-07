`timescale 1ns / 1ps

// Puts camera setup, capture, frame buffer, and the zoom reader all together.

module vga_cam #(
    parameter CLK_FREQ_HZ       = 100_000_000,
    parameter I2C_FREQ_HZ       = 100_000,
    parameter POWERUP_DELAY_MS  = 50
) (
    input logic clk,      // system clock, used for VGA timing, frame buffer read, and SCCB
    input logic pclk,     // real OV7670 pixel clock, used for the frame buffer write side
    input logic rst_n,

    // zoom control
    input logic zoom_en,
    input logic zoom_r,
    input logic zoom_l,
    input logic zoom_d,

    // SCCB pins for setting up the camera registers
    output logic setup_busy,
    output logic setup_done,
    output logic setup_error,
    output logic cam_scl,
    inout  wire  cam_sda,

    // OV7670 capture pins
    input logic       cam_href,
    input logic       cam_vsync,
    input logic [7:0] cam_data,

    // output
    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb,
    output logic        xclk       // clock we send to the camera's XCLK pin
);

    localparam IMG_W = 320;
    localparam IMG_H = 240;
    localparam DW    = 16;
    localparam AW    = $clog2(IMG_W * IMG_H);

    localparam integer POWERUP_DELAY_CYCLES =
        (CLK_FREQ_HZ / 1000) * POWERUP_DELAY_MS;
    localparam integer POWERUP_CNT_WIDTH = $clog2(POWERUP_DELAY_CYCLES);

    //============================================================
    // Camera XCLK, made from clk divided down to 25MHz
    //============================================================
    pclk_gen U_CAM_CLK_GEN (
        .clk  (clk),
        .rst_n(rst_n),
        .pclk (xclk)
    );

    //============================================================
    // wait a bit after power on, then start the SCCB setup once
    //============================================================
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

    //============================================================
    // wires used between the blocks below
    //============================================================
    logic              we;
    logic [    AW-1:0] wAddr;
    logic [    DW-1:0] wData;
    logic [    AW-1:0] rAddr;
    logic [    DW-1:0] rData;

    logic              de;
    logic [       9:0] x_pixel;
    logic [       9:0] y_pixel;
    logic              w_h_sync;
    logic              w_v_sync;

    //============================================================
    // writes camera pixels into the frame buffer (pclk domain)
    //============================================================
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

    //============================================================
    // the frame buffer itself (write side pclk, read side clk)
    //============================================================
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

    //============================================================
    // VGA timing generator (clk domain)
    //============================================================
    VGA_Decoder U_VGA_DEC (
        .clk    (clk),
        .rst_n  (rst_n),
        .h_sync (w_h_sync),
        .v_sync (w_v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .de     (de)
    );

    //============================================================
    // reads the frame buffer at 2x size and applies the zoom area
    //============================================================
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

    //============================================================
    // delay h_sync/v_sync by 1 clock to line up with rom_reader_upscale's own delay
    //============================================================
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
