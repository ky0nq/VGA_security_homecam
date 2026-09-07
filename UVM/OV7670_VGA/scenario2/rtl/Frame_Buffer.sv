`timescale 1ns / 1ps

module Frame_Buffer #(
	parameter IMG_W = 320,
	parameter IMG_H = 240,
    parameter int DATA_WIDTH = 16,
    parameter int ADDR_WIDTH = $clog2(IMG_W * IMG_H),
    parameter int DEPTH      = 320*240
)(
    // write port (pclk)
    input  logic                    wclk,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   waddr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    // read port (clk)
    input  logic                    rclk,
    input  logic [ADDR_WIDTH-1:0]   raddr,
    output logic [DATA_WIDTH-1:0]   rdata
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = '0;
    end
  
    always @(posedge wclk) begin
        if (we) mem[waddr] <= wdata;
    end

    always_ff @(posedge rclk) begin
        rdata <= mem[raddr];
    end
endmodule
