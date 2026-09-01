`timescale 1ns / 1ps

module tracking_path_overlay #(
    parameter integer IMG_WIDTH          = 320,
    parameter integer IMG_HEIGHT         = 240,
    parameter integer ADDR_WIDTH         =
        $clog2(IMG_WIDTH * IMG_HEIGHT),

    // 좌표 이동량의 1/2^SMOOTH_SHIFT만 반영
    parameter integer SMOOTH_SHIFT       = 2,

    // 이 값 이하의 움직임은 떨림으로 판단
    parameter integer MOVE_MARGIN        = 2,

    // 프레임 사이에서 이 값보다 크게 이동하면 오검출로 판단
    parameter integer MAX_JUMP           = 80,

    // 선 반경: 실제 선 폭 = 2 * LINE_RADIUS + 1
    parameter integer LINE_RADIUS        = 1,

    // 이 프레임 수까지는 잠깐 검출이 끊겨도 기존 선 유지
    parameter integer LOST_FRAME_MARGIN  = 2,

    parameter logic [11:0] LINE_COLOR    = 12'hFF0
)(
    // Camera PCLK Domain
    input  logic        i_pclk,
    input  logic        i_rst_n,
    input  logic        i_cam_vsync,
    input  logic        i_clear,

    input  logic        i_marker_valid,
    input  logic [8:0]  i_center_x,
    input  logic [7:0]  i_center_y,

    // VGA Clock Domain
    input  logic        i_vga_clk,
    input  logic        i_de,
    input  logic        i_h_sync,
    input  logic        i_v_sync,
    input  logic [9:0]  i_vga_x,
    input  logic [9:0]  i_vga_y,
    input  logic [11:0] i_rgb,

    output logic        o_h_sync,
    output logic        o_v_sync,
    output logic [11:0] o_rgb,

    output logic        o_busy
);

    localparam integer PIXEL_COUNT =
        IMG_WIDTH * IMG_HEIGHT;

    localparam integer SMOOTH_ROUND =
        (SMOOTH_SHIFT == 0) ? 0 :
        (1 << (SMOOTH_SHIFT - 1));

    //============================================================
    // Trail Buffer
    // 320×240, 1bit Path Memory
    //============================================================

    logic path_memory [0:PIXEL_COUNT-1];

    logic                  memory_write_enable;
    logic                  memory_write_data;
    logic [ADDR_WIDTH-1:0] memory_write_address;

    logic [ADDR_WIDTH-1:0] path_read_address;
    logic                  path_read_data;

    //============================================================
    // State Machine
    //============================================================

    typedef enum logic [1:0] {
        STATE_IDLE,
        STATE_CLEAR,
        STATE_STAMP,
        STATE_ADVANCE
    } state_t;

    state_t state;

    //============================================================
    // Frame / Clear Edge Detection
    //============================================================

    logic cam_vsync_d;
    logic clear_d;

    logic frame_sample;
    logic clear_pulse;

    assign frame_sample =
        cam_vsync_d & ~i_cam_vsync;

    assign clear_pulse =
        i_clear & ~clear_d;

    //============================================================
    // Previous Point / Detection State
    //============================================================

    logic   previous_valid;
    integer previous_x;
    integer previous_y;
    integer lost_frame_count;

    //============================================================
    // Smoothed Target Coordinate
    //============================================================

    integer raw_x_calc;
    integer raw_y_calc;

    integer delta_x_calc;
    integer delta_y_calc;

    integer target_x_calc;
    integer target_y_calc;

    integer move_x_calc;
    integer move_y_calc;

    //============================================================
    // Bresenham Line State
    //============================================================

    integer line_x;
    integer line_y;

    integer line_end_x;
    integer line_end_y;

    integer line_dx;
    integer line_dy;

    integer line_step_x;
    integer line_step_y;

    integer line_error;
    integer line_error_x2;

    //============================================================
    // Line Thickness Stamp
    //============================================================

    integer stamp_offset_x;
    integer stamp_offset_y;

    integer stamp_x_calc;
    integer stamp_y_calc;

    //============================================================
    // Clear Address
    //============================================================

    logic [ADDR_WIDTH-1:0] clear_address;

    //============================================================
    // Utility Function
    //============================================================

    function automatic integer abs_integer(
        input integer value
    );
        begin
            if (value < 0)
                abs_integer = -value;
            else
                abs_integer = value;
        end
    endfunction

    function automatic integer smooth_delta(
        input integer value
    );
        integer magnitude;
        begin
            if (SMOOTH_SHIFT == 0) begin
                smooth_delta = value;
            end else if (value >= 0) begin
                smooth_delta =
                    (value + SMOOTH_ROUND) >>> SMOOTH_SHIFT;
            end else begin
                magnitude = -value;

                smooth_delta = -(
                    (magnitude + SMOOTH_ROUND)
                    >>> SMOOTH_SHIFT
                );
            end
        end
    endfunction

    //============================================================
    // Target Coordinate Calculation
    //============================================================

    always_comb begin
        raw_x_calc = i_center_x;
        raw_y_calc = i_center_y;

        delta_x_calc = raw_x_calc - previous_x;
        delta_y_calc = raw_y_calc - previous_y;

        if (previous_valid) begin
            target_x_calc =
                previous_x + smooth_delta(delta_x_calc);

            target_y_calc =
                previous_y + smooth_delta(delta_y_calc);
        end else begin
            target_x_calc = raw_x_calc;
            target_y_calc = raw_y_calc;
        end

        // 유효 영상 영역으로 좌표 제한
        if (target_x_calc < 0)
            target_x_calc = 0;
        else if (target_x_calc >= IMG_WIDTH)
            target_x_calc = IMG_WIDTH - 1;

        if (target_y_calc < 0)
            target_y_calc = 0;
        else if (target_y_calc >= IMG_HEIGHT)
            target_y_calc = IMG_HEIGHT - 1;

        move_x_calc =
            abs_integer(target_x_calc - previous_x);

        move_y_calc =
            abs_integer(target_y_calc - previous_y);

        line_error_x2 = line_error <<< 1;
    end

    //============================================================
    // Path Drawing State Machine
    //============================================================

    always_ff @(posedge i_pclk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state <= STATE_CLEAR;

            cam_vsync_d <= 1'b0;
            clear_d     <= 1'b0;

            previous_valid  <= 1'b0;
            previous_x      <= 0;
            previous_y      <= 0;
            lost_frame_count <= 0;

            line_x      <= 0;
            line_y      <= 0;
            line_end_x  <= 0;
            line_end_y  <= 0;
            line_dx     <= 0;
            line_dy     <= 0;
            line_step_x <= 1;
            line_step_y <= 1;
            line_error  <= 0;

            stamp_offset_x <= -LINE_RADIUS;
            stamp_offset_y <= -LINE_RADIUS;

            clear_address <= '0;
        end else begin
            cam_vsync_d <= i_cam_vsync;
            clear_d     <= i_clear;

            // 새로운 패턴 입력 시작
            if (clear_pulse) begin
                state <= STATE_CLEAR;

                clear_address <= '0;

                previous_valid   <= 1'b0;
                previous_x       <= 0;
                previous_y       <= 0;
                lost_frame_count <= 0;

                stamp_offset_x <= -LINE_RADIUS;
                stamp_offset_y <= -LINE_RADIUS;
            end else begin
                case (state)
                    //================================================
                    // Trail Buffer 전체 초기화
                    //================================================
                    STATE_CLEAR: begin
                        previous_valid   <= 1'b0;
                        lost_frame_count <= 0;

                        if (clear_address == PIXEL_COUNT - 1) begin
                            clear_address <= '0;
                            state         <= STATE_IDLE;
                        end else begin
                            clear_address <=
                                clear_address + 1'b1;
                        end
                    end

                    //================================================
                    // 새로운 중심 좌표 대기
                    //================================================
                    STATE_IDLE: begin
                        if (frame_sample) begin
                            if (i_marker_valid) begin
                                // 첫 번째 위치
                                if (!previous_valid) begin
                                    previous_valid <= 1'b1;
                                    previous_x     <= raw_x_calc;
                                    previous_y     <= raw_y_calc;

                                    lost_frame_count <= 0;

                                    // 시작점을 원으로 표시하기 위해
                                    // 시작점과 끝점을 동일하게 설정
                                    line_x     <= raw_x_calc;
                                    line_y     <= raw_y_calc;
                                    line_end_x <= raw_x_calc;
                                    line_end_y <= raw_y_calc;

                                    line_dx     <= 0;
                                    line_dy     <= 0;
                                    line_step_x <= 1;
                                    line_step_y <= 1;
                                    line_error  <= 0;

                                    stamp_offset_x <= -LINE_RADIUS;
                                    stamp_offset_y <= -LINE_RADIUS;

                                    state <= STATE_STAMP;
                                end

                                // 이동량이 너무 작은 경우
                                else if (
                                    (move_x_calc <= MOVE_MARGIN) &&
                                    (move_y_calc <= MOVE_MARGIN)
                                ) begin
                                    lost_frame_count <= 0;
                                end

                                // 비정상적으로 큰 위치 이동
                                else if (
                                    (move_x_calc > MAX_JUMP) ||
                                    (move_y_calc > MAX_JUMP)
                                ) begin
                                    if (
                                        lost_frame_count + 1 >=
                                        LOST_FRAME_MARGIN
                                    ) begin
                                        previous_valid   <= 1'b0;
                                        lost_frame_count <=
                                            LOST_FRAME_MARGIN;
                                    end else begin
                                        lost_frame_count <=
                                            lost_frame_count + 1;
                                    end
                                end

                                // 정상적인 위치 이동
                                else begin
                                    line_x     <= previous_x;
                                    line_y     <= previous_y;
                                    line_end_x <= target_x_calc;
                                    line_end_y <= target_y_calc;

                                    line_dx <= move_x_calc;
                                    line_dy <= move_y_calc;

                                    if (previous_x < target_x_calc)
                                        line_step_x <= 1;
                                    else
                                        line_step_x <= -1;

                                    if (previous_y < target_y_calc)
                                        line_step_y <= 1;
                                    else
                                        line_step_y <= -1;

                                    line_error <=
                                        move_x_calc - move_y_calc;

                                    previous_x <= target_x_calc;
                                    previous_y <= target_y_calc;

                                    previous_valid   <= 1'b1;
                                    lost_frame_count <= 0;

                                    stamp_offset_x <= -LINE_RADIUS;
                                    stamp_offset_y <= -LINE_RADIUS;

                                    state <= STATE_STAMP;
                                end
                            end else begin
                                // 파란색 객체가 잠깐 사라진 경우
                                if (
                                    lost_frame_count + 1 >=
                                    LOST_FRAME_MARGIN
                                ) begin
                                    previous_valid   <= 1'b0;
                                    lost_frame_count <=
                                        LOST_FRAME_MARGIN;
                                end else begin
                                    lost_frame_count <=
                                        lost_frame_count + 1;
                                end
                            end
                        end
                    end

                    //================================================
                    // 현재 Line Pixel 주변에 두께 적용
                    //================================================
                    STATE_STAMP: begin
                        if (stamp_offset_x == LINE_RADIUS) begin
                            stamp_offset_x <= -LINE_RADIUS;

                            if (stamp_offset_y == LINE_RADIUS) begin
                                stamp_offset_y <= -LINE_RADIUS;
                                state          <= STATE_ADVANCE;
                            end else begin
                                stamp_offset_y <=
                                    stamp_offset_y + 1;
                            end
                        end else begin
                            stamp_offset_x <=
                                stamp_offset_x + 1;
                        end
                    end

                    //================================================
                    // Bresenham 다음 Line Pixel 계산
                    //================================================
                    STATE_ADVANCE: begin
                        // 끝점까지 그렸으면 완료
                        if (
                            (line_x == line_end_x) &&
                            (line_y == line_end_y)
                        ) begin
                            state <= STATE_IDLE;
                        end else begin
                            if (
                                (line_error_x2 > -line_dy) &&
                                (line_error_x2 < line_dx)
                            ) begin
                                line_error <=
                                    line_error - line_dy + line_dx;

                                line_x <= line_x + line_step_x;
                                line_y <= line_y + line_step_y;
                            end else if (
                                line_error_x2 > -line_dy
                            ) begin
                                line_error <=
                                    line_error - line_dy;

                                line_x <= line_x + line_step_x;
                            end else if (
                                line_error_x2 < line_dx
                            ) begin
                                line_error <=
                                    line_error + line_dx;

                                line_y <= line_y + line_step_y;
                            end

                            stamp_offset_x <= -LINE_RADIUS;
                            stamp_offset_y <= -LINE_RADIUS;

                            state <= STATE_STAMP;
                        end
                    end

                    default: begin
                        state         <= STATE_CLEAR;
                        clear_address <= '0;
                    end
                endcase
            end
        end
    end

    //============================================================
    // Trail Buffer Write Control
    //============================================================

    always_comb begin
        memory_write_enable  = 1'b0;
        memory_write_address = '0;
        memory_write_data    = 1'b0;

        stamp_x_calc = line_x + stamp_offset_x;
        stamp_y_calc = line_y + stamp_offset_y;

        if (state == STATE_CLEAR) begin
            memory_write_enable  = 1'b1;
            memory_write_address = clear_address;
            memory_write_data    = 1'b0;
        end else if (state == STATE_STAMP) begin
            if (
                (stamp_x_calc >= 0) &&
                (stamp_x_calc < IMG_WIDTH) &&
                (stamp_y_calc >= 0) &&
                (stamp_y_calc < IMG_HEIGHT)
            ) begin
                memory_write_enable = 1'b1;

                memory_write_address =
                    (stamp_y_calc * IMG_WIDTH) +
                    stamp_x_calc;

                memory_write_data = 1'b1;
            end
        end
    end

    always_ff @(posedge i_pclk) begin
        if (memory_write_enable)
            path_memory[memory_write_address]
                <= memory_write_data;
    end

    //============================================================
    // VGA Trail Buffer Read
    // 640×480 좌표를 320×240 좌표로 변환
    //============================================================

    always_comb begin
        path_read_address = '0;

        if (
            i_de &&
            (i_vga_x < IMG_WIDTH * 2) &&
            (i_vga_y < IMG_HEIGHT * 2)
        ) begin
            path_read_address =
                (i_vga_y[9:1] * IMG_WIDTH) +
                i_vga_x[9:1];
        end
    end

    always_ff @(posedge i_vga_clk) begin
        path_read_data <=
            path_memory[path_read_address];
    end

    //============================================================
    // VGA Pipeline
    // Trail Buffer BRAM Read Latency와 영상 신호 정렬
    //============================================================

    logic        de_delay;
    logic        h_sync_delay;
    logic        v_sync_delay;
    logic [11:0] rgb_delay;

    logic clear_busy_meta;
    logic clear_busy_vga;

    wire clear_busy_pclk =
        (state == STATE_CLEAR);

    always_ff @(posedge i_vga_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            de_delay       <= 1'b0;
            h_sync_delay   <= 1'b1;
            v_sync_delay   <= 1'b1;
            rgb_delay      <= 12'h000;

            clear_busy_meta <= 1'b1;
            clear_busy_vga  <= 1'b1;
        end else begin
            de_delay     <= i_de;
            h_sync_delay <= i_h_sync;
            v_sync_delay <= i_v_sync;
            rgb_delay    <= i_rgb;

            clear_busy_meta <= clear_busy_pclk;
            clear_busy_vga  <= clear_busy_meta;
        end
    end

    //============================================================
    // Final Path Overlay
    //============================================================

    always_comb begin
        o_h_sync = h_sync_delay;
        o_v_sync = v_sync_delay;
        o_rgb    = rgb_delay;

        if (
            de_delay &&
            path_read_data &&
            !clear_busy_vga
        ) begin
            o_rgb = LINE_COLOR;
        end
    end

    assign o_busy =
        (state != STATE_IDLE);

endmodule