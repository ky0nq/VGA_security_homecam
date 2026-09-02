`timescale 1ns / 1ps

// Prof - Upscale
// 줌 버튼(zoom_r/zoom_l/zoom_d)은 이제 레벨이 아니라 1클럭짜리 펄스로 들어옴.
// zoom_en 스위치를 올리면 기본으로 1영역(zoom_in=00)이 선택되고,
// 버튼 펄스가 들어올 때만 그 버튼에 해당하는 영역으로 바뀌어서 계속 유지됨
// (다음 버튼이 올 때까지 유지 - "눌렀다 뗀 뒤에도 그 영역 고정")
module rom_reader_upscale (
    input logic clk,
    input logic rst_n,
    input logic zoom_en,
    input logic zoom_r,   // 1클럭 펄스
    input logic zoom_l,   // 1클럭 펄스
    input logic zoom_d,   // 1클럭 펄스
    input logic de,
    input logic [ 9:0] x_pixel,
    input logic [ 9:0] y_pixel,
    output logic [16:0] addr,
    input logic [15:0] px_data,
    output logic [11:0] o_rgb
);
	logic [1:0] zoom_in;
    logic dispArea, dispArea_d;

    //============================================================
    // 선택된 영역 레지스터
    //   zoom_en이 꺼지면(또는 리셋) 기본 영역(00)으로 복귀
    //   버튼 펄스가 오면 그 영역으로 전환, 안 오면 유지
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            zoom_in <= 2'b00;
        end else if (!zoom_en) begin
            zoom_in <= 2'b00;          // 줌 끄면 기본 영역으로 리셋
        end else if (zoom_l) begin
            zoom_in <= 2'b10;
        end else if (zoom_r) begin
            zoom_in <= 2'b01;
        end else if (zoom_d) begin
            zoom_in <= 2'b11;
        end
        // 그 외에는 그대로 유지
    end

    assign dispArea = de;
    //assign addr = dispArea ? (y_pixel[9:1] * 320 + x_pixel[9:1]) : 0;
	assign addr = dispArea ? ( (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 8)  
							+  (((y_pixel[9:1] >> zoom_en)+zoom_in[1]*120) << 6)
							+  ((x_pixel[9:1]>> zoom_en)+zoom_in[0]*160)) : 0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dispArea_d <= 1'b0;
        end else begin
            dispArea_d <= dispArea;
        end
    end

    assign o_rgb = dispArea_d ? {px_data[15:12], px_data[10:7], px_data[4:1]} : 0;

endmodule