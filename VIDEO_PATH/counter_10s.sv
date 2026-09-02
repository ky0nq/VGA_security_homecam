`timescale 1ns / 1ps

// ============================================================
// counter_10s
//   1초에 한 번 틱을 만들어서 0~10까지 세는 카운터.
//   data_10s는 그 펄스가 뜨는 클럭에만 8'b1000_0000, 그 외엔 8'b0
// ============================================================
module counter_10s #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic clk,
    input  logic rst_n,

    input  logic rx_done,      // uart의 rx_done - 새 데이터 오면 카운터 리셋

    output logic        done_10s,     // 10초 도달 시 1클럭 펄스 -> lock_force/tx_start 둘 다로
    output logic [7:0] data_10s      // 10초 도달 시 8'h80, 그 외 8'h00 -> uart의 tx_data로
);

    localparam integer TICK_CYCLES = CLK_FREQ_HZ;      // 1초 = clk 주파수만큼의 사이클
    localparam int      TICK_WIDTH  = $clog2(TICK_CYCLES);

    //============================================================
    // 1Hz 틱 생성
    //============================================================
    logic [TICK_WIDTH-1:0] tick_cnt;
    logic                   tick;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_cnt <= '0;
            tick     <= 1'b0;
        end else if (tick_cnt == TICK_CYCLES - 1) begin
            tick_cnt <= '0;
            tick     <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick     <= 1'b0;
        end
    end

    //============================================================
    // 초 카운터 (0~10, rx_done 오면 리셋, 10에서 멈춤)
    //============================================================
    logic [3:0] sec_cnt;
    logic        reach_10; // 이번 틱에 9->10으로 막 넘어가는 그 순간(조합)

    assign reach_10 = tick && (sec_cnt == 4'd9);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_cnt <= 4'd0;
        end else if (rx_done) begin
            sec_cnt <= 4'd0;            // 새 데이터 오면 리셋
        end else if (tick && sec_cnt < 4'd10) begin
            sec_cnt <= sec_cnt + 4'd1;  // 10에서 더 안 올라가고 멈춤
        end
    end

    //============================================================
    // 10초 도달 순간 : done_10s 1클럭 펄스, data_10s=8'h80
    //============================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_10s <= 1'b0;
            data_10s <= 8'h00;
        end else begin
            done_10s <= reach_10;
            data_10s <= reach_10 ? 8'h80 : 8'h00;
        end
    end

endmodule