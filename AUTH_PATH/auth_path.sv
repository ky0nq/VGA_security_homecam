`timescale 1ns / 1ps

module auth_path #(
    parameter integer IMG_WIDTH = 320,
    parameter integer IMG_HEIGHT = 240,
    parameter logic [4:0] BLUE_B_MIN = 5'd20,
    parameter logic [5:0] BLUE_BR_MARGIN = 6'd10,
    parameter logic [5:0] BLUE_BG_MARGIN = 6'd10,
    parameter integer MIN_BLUE_PIXELS = 50,
    parameter integer STABLE_FRAMES = 3,
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input  logic        clk,
    input  logic        pclk,
    input  logic        rst_n,

    input  logic        i_auth_start,
    input  logic        i_pattern_clear,

    input  logic        i_cam_vsync,
    input  logic        i_frame_we,
    input  logic [15:0] i_frame_rgb565,

    output logic        o_unlock_pass,
    output logic        o_unlock_fail,
    output logic        o_auth_active,

    output logic        o_path_clear_pclk,
    output logic        o_track_update_pulse,
    output logic        o_marker_valid,
    output logic [8:0]  o_center_x,
    output logic [7:0]  o_center_y,

    output logic        o_grid_valid,
    output logic [3:0]  o_grid_id,
    output logic        o_grid_enter_pulse,

    output logic [1:0]  o_auth_state,
    output logic [2:0]  o_pattern_index
);

    // =========================================================
    // Auth Control Unit 신호: clk 도메인
    // =========================================================
    logic auth_active_clk;
    logic path_clear_clk;
    logic analysis_clear_clk;

    assign o_auth_active = auth_active_clk;
    logic       control_grid_valid;
    logic [3:0] control_grid_id;

    // Grid Enter 이벤트 순간에는 이벤트와 함께 저장한 Grid ID 사용
    // 그 외에는 현재 안정화된 Grid 상태 사용
    assign control_grid_valid =
        grid_enter_clk ? 1'b1 : current_grid_valid_clk;

    assign control_grid_id =
        grid_enter_clk ? grid_event_id_sync : current_grid_id_clk;

    // Grid Stabilizer는 인증 시작, 외부 Clear, 인증 성공 시 초기화
    // 일반 패턴 실패 시에는 초기화하지 않음
    assign analysis_clear_clk =
        i_auth_start |
        i_pattern_clear |
        o_unlock_pass;

    // =========================================================
    // auth_active: clk → pclk
    // =========================================================
    (* ASYNC_REG = "TRUE" *) logic auth_active_pclk_meta;
    (* ASYNC_REG = "TRUE" *) logic auth_active_pclk;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            auth_active_pclk_meta <= 1'b0;
            auth_active_pclk      <= 1'b0;
        end else begin
            auth_active_pclk_meta <= auth_active_clk;
            auth_active_pclk      <= auth_active_pclk_meta;
        end
    end

    // =========================================================
    // Clear Pulse CDC: clk → pclk
    // =========================================================
    logic path_clear_toggle_clk;
    logic analysis_clear_toggle_clk;

    (* ASYNC_REG = "TRUE" *) logic path_clear_toggle_meta;
    (* ASYNC_REG = "TRUE" *) logic path_clear_toggle_sync;
    logic path_clear_toggle_d;

    (* ASYNC_REG = "TRUE" *) logic analysis_clear_toggle_meta;
    (* ASYNC_REG = "TRUE" *) logic analysis_clear_toggle_sync;
    logic analysis_clear_toggle_d;

    logic analysis_clear_pclk;

    // clk 도메인 펄스를 Toggle 신호로 변환
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            path_clear_toggle_clk     <= 1'b0;
            analysis_clear_toggle_clk <= 1'b0;
        end else begin
            if (path_clear_clk) begin
                path_clear_toggle_clk <= ~path_clear_toggle_clk;
            end

            if (analysis_clear_clk) begin
                analysis_clear_toggle_clk <= ~analysis_clear_toggle_clk;
            end
        end
    end

    // Toggle 신호를 pclk 도메인 펄스로 복원
    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            path_clear_toggle_meta     <= 1'b0;
            path_clear_toggle_sync     <= 1'b0;
            path_clear_toggle_d        <= 1'b0;

            analysis_clear_toggle_meta <= 1'b0;
            analysis_clear_toggle_sync <= 1'b0;
            analysis_clear_toggle_d    <= 1'b0;

            o_path_clear_pclk   <= 1'b0;
            analysis_clear_pclk <= 1'b0;
        end else begin
            path_clear_toggle_meta <= path_clear_toggle_clk;
            path_clear_toggle_sync <= path_clear_toggle_meta;
            path_clear_toggle_d    <= path_clear_toggle_sync;

            analysis_clear_toggle_meta <= analysis_clear_toggle_clk;
            analysis_clear_toggle_sync <= analysis_clear_toggle_meta;
            analysis_clear_toggle_d    <= analysis_clear_toggle_sync;

            o_path_clear_pclk <=
                path_clear_toggle_sync ^ path_clear_toggle_d;

            analysis_clear_pclk <=
                analysis_clear_toggle_sync ^ analysis_clear_toggle_d;
        end
    end

    // =========================================================
    // 파란색 픽셀 검출
    // =========================================================
    logic is_blue_pixel;

    blue_threshold #(
        .B_MIN    (BLUE_B_MIN),
        .BR_MARGIN(BLUE_BR_MARGIN),
        .BG_MARGIN(BLUE_BG_MARGIN)
    ) U_BLUE_THRESHOLD (
        .i_valid  (i_frame_we & auth_active_pclk),
        .i_rgb565 (i_frame_rgb565),
        .o_is_blue(is_blue_pixel)
    );

    // =========================================================
    // 파란색 Blob 추적
    // =========================================================
    logic       blob_valid_raw;
    logic [8:0] center_x_raw;
    logic [7:0] center_y_raw;

    blue_blob_tracker #(
        .IMG_WIDTH      (IMG_WIDTH),
        .IMG_HEIGHT     (IMG_HEIGHT),
        .MIN_BLUE_PIXELS(MIN_BLUE_PIXELS)
    ) U_BLUE_BLOB_TRACKER (
        .i_pclk       (pclk),
        .i_rst_n      (rst_n),

        .i_frame_sync (i_cam_vsync),
        .i_pixel_valid(i_frame_we & auth_active_pclk),
        .i_is_blue    (is_blue_pixel),

        .o_blob_valid (blob_valid_raw),
        .o_center_x   (center_x_raw),
        .o_center_y   (center_y_raw),

        .o_min_x      (),
        .o_max_x      (),
        .o_min_y      (),
        .o_max_y      (),
        .o_blue_count ()
    );

    assign o_marker_valid = blob_valid_raw & auth_active_pclk;
    assign o_center_x     = center_x_raw;
    assign o_center_y     = center_y_raw;

    // =========================================================
    // 새로운 Tracking 결과 갱신 펄스
    // =========================================================
    logic cam_vsync_d_pclk;
    logic frame_result_pending_pclk;
    logic frame_start_pclk;

    assign frame_start_pclk =
        i_cam_vsync & ~cam_vsync_d_pclk;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            cam_vsync_d_pclk          <= 1'b0;
            frame_result_pending_pclk <= 1'b0;
            o_track_update_pulse      <= 1'b0;
        end else begin
            cam_vsync_d_pclk <= i_cam_vsync;
            frame_result_pending_pclk <= frame_start_pclk;

            o_track_update_pulse <=
                frame_result_pending_pclk & auth_active_pclk;
        end
    end

    // =========================================================
    // 중심 좌표 → 3×3 Grid
    // =========================================================
    logic       mapped_grid_valid;
    logic [3:0] mapped_grid_id;

    grid_mapper #(
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) U_GRID_MAPPER (
        .i_blob_valid(blob_valid_raw & auth_active_pclk),
        .i_center_x  (center_x_raw),
        .i_center_y  (center_y_raw),

        .o_grid_valid(mapped_grid_valid),
        .o_grid_id   (mapped_grid_id)
    );

    // =========================================================
    // Grid 안정화
    // =========================================================
    logic       stable_grid_valid_pclk;
    logic [3:0] stable_grid_id_pclk;
    logic       stable_grid_enter_pclk;

    grid_stabilizer #(
        .STABLE_FRAMES(STABLE_FRAMES)
    ) U_GRID_STABILIZER (
        .i_pclk      (pclk),
        .i_rst_n     (rst_n),

        .i_frame_sync(i_cam_vsync),

        .i_clear(
            analysis_clear_pclk |
            ~auth_active_pclk
        ),

        .i_grid_valid(
            mapped_grid_valid &
            auth_active_pclk
        ),
        .i_grid_id(mapped_grid_id),

        .o_stable_valid    (stable_grid_valid_pclk),
        .o_stable_grid_id  (stable_grid_id_pclk),
        .o_grid_enter_pulse(stable_grid_enter_pclk)
    );

    assign o_grid_valid       = stable_grid_valid_pclk;
    assign o_grid_id          = stable_grid_id_pclk;
    assign o_grid_enter_pulse = stable_grid_enter_pclk;

    // =========================================================
    // Grid Enter Event: pclk → clk
    //
    // Grid ID와 진입 이벤트를 Toggle 방식으로 전달
    // =========================================================
    logic       grid_event_toggle_pclk;
    logic [3:0] grid_event_id_pclk;

    always_ff @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            grid_event_toggle_pclk <= 1'b0;
            grid_event_id_pclk     <= 4'd0;
        end else if (
            stable_grid_enter_pclk &&
            auth_active_pclk
        ) begin
            grid_event_toggle_pclk <=
                ~grid_event_toggle_pclk;

            grid_event_id_pclk <=
                stable_grid_id_pclk;
        end
    end

    (* ASYNC_REG = "TRUE" *) logic grid_event_toggle_meta;
    (* ASYNC_REG = "TRUE" *) logic grid_event_toggle_sync;
    logic grid_event_toggle_d;
    logic grid_enter_clk;

    (* ASYNC_REG = "TRUE" *) logic [3:0] grid_event_id_meta;
    (* ASYNC_REG = "TRUE" *) logic [3:0] grid_event_id_sync;

    // =========================================================
    // 현재 Marker/Grid 상태: pclk → clk
    // =========================================================
    (* ASYNC_REG = "TRUE" *) logic marker_valid_meta;
    (* ASYNC_REG = "TRUE" *) logic marker_valid_clk;

    (* ASYNC_REG = "TRUE" *) logic current_grid_valid_meta;
    (* ASYNC_REG = "TRUE" *) logic current_grid_valid_clk;

    (* ASYNC_REG = "TRUE" *) logic [3:0] current_grid_id_meta;
    (* ASYNC_REG = "TRUE" *) logic [3:0] current_grid_id_clk;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grid_event_toggle_meta <= 1'b0;
            grid_event_toggle_sync <= 1'b0;
            grid_event_toggle_d    <= 1'b0;
            grid_enter_clk         <= 1'b0;

            grid_event_id_meta <= 4'd0;
            grid_event_id_sync <= 4'd0;

            marker_valid_meta <= 1'b0;
            marker_valid_clk  <= 1'b0;

            current_grid_valid_meta <= 1'b0;
            current_grid_valid_clk  <= 1'b0;

            current_grid_id_meta <= 4'd0;
            current_grid_id_clk  <= 4'd0;
        end else begin
            grid_event_toggle_meta <=
                grid_event_toggle_pclk;

            grid_event_toggle_sync <=
                grid_event_toggle_meta;

            grid_event_toggle_d <=
                grid_event_toggle_sync;

            grid_enter_clk <=
                grid_event_toggle_sync ^
                grid_event_toggle_d;

            grid_event_id_meta <=
                grid_event_id_pclk;

            grid_event_id_sync <=
                grid_event_id_meta;

            marker_valid_meta <=
                blob_valid_raw &
                auth_active_pclk;

            marker_valid_clk <=
                marker_valid_meta;

            current_grid_valid_meta <=
                stable_grid_valid_pclk;

            current_grid_valid_clk <=
                current_grid_valid_meta;

            current_grid_id_meta <=
                stable_grid_id_pclk;

            current_grid_id_clk <=
                current_grid_id_meta;
        end
    end

    // =========================================================
    // Auth Control Unit
    //
    // auth_control_unit.sv는 별도 파일
    // clk/rst_n에는 i_를 사용하지 않음
    // =========================================================
    auth_control_unit #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ)
    ) U_AUTH_CONTROL_UNIT (
        .clk               (clk),
        .rst_n             (rst_n),
    
        .i_auth_start      (i_auth_start),
        .i_pattern_clear   (i_pattern_clear),
    
        .i_grid_enter_pulse(grid_enter_clk),
        .i_grid_valid      (control_grid_valid),
        .i_grid_id         (control_grid_id),
        .i_marker_valid    (marker_valid_clk),
    
        .o_unlock_pass     (o_unlock_pass),
        .o_unlock_fail     (o_unlock_fail),
    
        .o_auth_active     (auth_active_clk),
        .o_path_clear      (path_clear_clk),
    
        .o_state           (o_auth_state),
        .o_pattern_index   (o_pattern_index)
    );

endmodule
