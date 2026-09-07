`timescale 1ns / 1ps

// rom_reader 와 같은 역할. VGA 좌표로 frame buffer read 주소를 만들고
// 읽어온 RGB565 를 VGA 출력용 12bit(4:4:4) 로 변환한다.
//   scale2x = 0 : 원본 320x240 을 좌상단에 표시
//   scale2x = 1 : 2배 확대해서 640x480 화면을 채움
// frame buffer read 가 1클럭 지연되므로 disp 도 한 클럭 늦춰서 색을 뽑는다.
module Frame_Reader #(
    parameter int H_ACT      = 320,
    parameter int V_ACT      = 240,
    parameter int ADDR_WIDTH = 17
)(
    input  logic                    clk,       // VGA(system) clock, frame buffer rclk 과 동일
    input  logic                    reset,
    input  logic                    scale2x,
    input  logic                    de,
    input  logic [9:0]              x_pixel,
    input  logic [9:0]              y_pixel,
    output logic [ADDR_WIDTH-1:0]   rd_addr,
    input  logic [15:0]             rd_data,   // frame buffer 에서 온 RGB565 (1클럭 늦음)
    output logic [11:0]             o_rgb
);

    logic [9:0] src_x, src_y;
    logic       disp, disp_d;

    always_comb begin
        if (scale2x) begin
            src_x = x_pixel >> 1;
            src_y = y_pixel >> 1;
        end else begin
            src_x = x_pixel;
            src_y = y_pixel;
        end
    end

    assign disp    = de && (src_x < H_ACT) && (src_y < V_ACT);
    assign rd_addr = disp ? (src_y * H_ACT + src_x) : '0;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) disp_d <= 1'b0;
        else       disp_d <= disp;
    end

    // RGB565 -> RGB444 (LENA 와 동일하게 상위 4bit 씩)
    assign o_rgb = disp_d ? {rd_data[15:12], rd_data[10:7], rd_data[4:1]} : 12'd0;
endmodule
