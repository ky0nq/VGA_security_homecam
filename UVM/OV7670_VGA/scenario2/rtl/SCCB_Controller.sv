`timescale 1ns / 1ps

module I2C_Master #(
    parameter int         CLK_HZ  = 100_000_000,
    parameter int         SCL_HZ  = 100_000,
    parameter logic [7:0] ID_ADDR = 8'h42     // OV7670 = 0x42
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       exec,       
    input  logic [7:0] sub_addr,   
    input  logic [7:0] wdata,      
    output logic       busy,
    output logic       done,      
    output logic       sioc,      
    inout  wire        siod       
);

    localparam int PHASE_DIV = CLK_HZ / (4*SCL_HZ);   // 100MHz/100kHz -> 250

    logic [$clog2(PHASE_DIV)-1:0] div_cnt;
    logic                         tick;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end else if (div_cnt == PHASE_DIV-1) begin
            div_cnt <= '0;
            tick    <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 1'b1;
            tick    <= 1'b0;
        end
    end

    typedef enum logic [3:0] {
        S_IDLE, S_START1, S_START2, S_LOAD, S_BIT, S_ACK,
        S_NEXTB, S_STOP1, S_STOP2, S_STOP3, S_DONE
    } state_t;

    state_t      state;
    logic [1:0]  phase;      
    logic [2:0]  bit_idx;  
    logic [1:0]  byte_idx;  
    logic [7:0]  shifter;
    logic [7:0]  sa_r, wd_r;
    logic        sda_oe;     
    logic        scl_r;

    assign siod = sda_oe ? 1'b0 : 1'bz;
    assign sioc = scl_r;
    assign busy = (state != S_IDLE);
    assign done = (state == S_DONE);

    // 지금 내보낼 바이트
    logic [7:0] sel_byte;
    always_comb begin
        case (byte_idx)
            2'd0:    sel_byte = ID_ADDR;
            2'd1:    sel_byte = sa_r;
            default: sel_byte = wd_r;
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state    <= S_IDLE;
            phase    <= 2'd0;
            bit_idx  <= 3'd0;
            byte_idx <= 2'd0;
            shifter  <= 8'd0;
            sa_r     <= 8'd0;
            wd_r     <= 8'd0;
            sda_oe   <= 1'b0;    // idle : SDA high
            scl_r    <= 1'b1;    // idle : SCL high
        end else begin
            case (state)
                // 요청 대기
                S_IDLE: begin
                    sda_oe <= 1'b0;
                    scl_r  <= 1'b1;
                    phase  <= 2'd0;
                    if (exec) begin
                        sa_r  <= sub_addr;
                        wd_r  <= wdata;
                        state <= S_START1;
                    end
                end

                S_START1: if (tick) begin
                    sda_oe <= 1'b0;  scl_r <= 1'b1;
                    state  <= S_START2;
                end
                S_START2: if (tick) begin
                    sda_oe   <= 1'b1;  scl_r <= 1'b1;
                    byte_idx <= 2'd0;
                    state    <= S_LOAD;
                end

                S_LOAD: if (tick) begin
                    shifter <= sel_byte;
                    bit_idx <= 3'd0;
                    phase   <= 2'd0;
                    scl_r   <= 1'b0;
                    state   <= S_BIT;
                end

                S_BIT: if (tick) begin
                    phase <= phase + 1'b1;
                    case (phase)
                        2'd0: begin sda_oe <= ~shifter[7]; scl_r <= 1'b0; end
                        2'd1:       scl_r <= 1'b1;
                        2'd2:       scl_r <= 1'b1;
                        2'd3: begin
                            scl_r   <= 1'b0;
                            shifter <= {shifter[6:0], 1'b0};
                            if (bit_idx == 3'd7) state <= S_ACK;
                            else                 bit_idx <= bit_idx + 1'b1;
                        end
                    endcase
                end

                S_ACK: if (tick) begin
                    phase <= phase + 1'b1;
                    case (phase)
                        2'd0: begin sda_oe <= 1'b0; scl_r <= 1'b0; end
                        2'd1:       scl_r <= 1'b1;
                        2'd2:       scl_r <= 1'b1;
                        2'd3: begin scl_r <= 1'b0; state <= S_NEXTB; end
                    endcase
                end

                S_NEXTB: begin
                    if (byte_idx == 2'd2) begin
                        sda_oe <= 1'b1;  scl_r <= 1'b0;
                        state  <= S_STOP1;
                    end else begin
                        byte_idx <= byte_idx + 1'b1;
                        state    <= S_LOAD;
                    end
                end

                S_STOP1: if (tick) begin sda_oe <= 1'b1; scl_r <= 1'b1; state <= S_STOP2; end
                S_STOP2: if (tick) begin sda_oe <= 1'b0; scl_r <= 1'b1; state <= S_STOP3; end
                S_STOP3: if (tick) begin sda_oe <= 1'b0; scl_r <= 1'b1; state <= S_DONE;  end
                S_DONE:  state <= S_IDLE;          
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

module SCCB_Controller #(
    parameter int CLK_HZ           = 100_000_000,
    parameter int SCL_HZ           = 100_000,
    parameter int NUM_REGS         = 78,
    parameter int START_DELAY      = 100_000,   
    parameter int POST_RESET_DELAY = 200_000, 
    parameter     ROM_FILE         = "ov7670_qvga_rgb565.mem"
)(
    input  logic clk,
    input  logic reset,
    output logic o_busy,
    output logic o_done,        

    output logic sioc,          // OV7670 SIO_C
    inout  wire  siod           // OV7670 SIO_D
);

    localparam logic [7:0] OV7670_ID_W = 8'h42;   // 0x21 << 1, write

    // reg table, one word = {reg addr[15:8], value[7:0]}
    logic [15:0] init_rom [0:NUM_REGS-1];
    initial $readmemh(ROM_FILE, init_rom);

    logic       m_exec, m_busy, m_done;
    logic [7:0] m_sub, m_dat;

    I2C_Master #(.CLK_HZ(CLK_HZ), .SCL_HZ(SCL_HZ), .ID_ADDR(OV7670_ID_W)) u_i2c (
        .clk     (clk),
        .reset   (reset),
        .exec    (m_exec),
        .sub_addr(m_sub),
        .wdata   (m_dat),
        .busy    (m_busy),
        .done    (m_done),
        .sioc    (sioc),
        .siod    (siod)
    );

    typedef enum logic [2:0] {
        F_POR, F_REQ, F_WAIT, F_RDELAY, F_DONE, F_IDLE
    } fstate_t;

    fstate_t                        fstate;
    logic [$clog2(NUM_REGS)-1:0]    reg_idx;
    logic [$clog2((START_DELAY > POST_RESET_DELAY ? START_DELAY : POST_RESET_DELAY)+1)-1:0] dcnt;

    assign m_sub  = init_rom[reg_idx][15:8];
    assign m_dat  = init_rom[reg_idx][7:0];
    assign m_exec = (fstate == F_REQ);           
    assign o_busy = (fstate != F_IDLE) || m_busy;
    assign o_done = (fstate == F_DONE) || (fstate == F_IDLE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            fstate  <= F_POR;
            reg_idx <= '0;
            dcnt    <= '0;
        end else begin
            case (fstate)
                F_POR: begin
                    if (dcnt == START_DELAY-1) begin
                        dcnt   <= '0;
                        fstate <= F_REQ;
                    end else dcnt <= dcnt + 1'b1;
                end

                F_REQ: fstate <= F_WAIT;

                F_WAIT: if (m_done) begin
                    if (reg_idx == NUM_REGS-1) begin
                        fstate <= F_DONE;
                    end else if (reg_idx == 0) begin
                        dcnt   <= '0;
                        fstate <= F_RDELAY;      
                    end else begin
                        reg_idx <= reg_idx + 1'b1;
                        fstate  <= F_REQ;
                    end
                end
                
                F_RDELAY: begin
                    if (dcnt == POST_RESET_DELAY-1) begin
                        dcnt    <= '0;
                        reg_idx <= reg_idx + 1'b1;  
                        fstate  <= F_REQ;
                    end else dcnt <= dcnt + 1'b1;
                end
                F_DONE: fstate <= F_IDLE;
                F_IDLE: fstate <= F_IDLE;

                default: fstate <= F_IDLE;
            endcase
        end
    end
endmodule
