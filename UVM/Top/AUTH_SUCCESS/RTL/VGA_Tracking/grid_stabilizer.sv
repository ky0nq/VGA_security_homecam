`timescale 1ns / 1ps

module grid_stabilizer #(
    parameter integer STABLE_FRAMES = 3,
    parameter integer COUNT_WIDTH   =
        (STABLE_FRAMES <= 1) ? 1 : $clog2(STABLE_FRAMES + 1)
)(
    input  logic       i_pclk,
    input  logic       i_rst_n,

    input  logic       i_frame_sync,
    input  logic       i_clear,

    input  logic       i_grid_valid,
    input  logic [3:0] i_grid_id,

    output logic       o_stable_valid,
    output logic [3:0] o_stable_grid_id,
    output logic       o_grid_enter_pulse
);

    logic       frame_sync_d;
    logic       frame_sample;

    logic       candidate_valid;
    logic [3:0] candidate_grid_id;
    logic [COUNT_WIDTH-1:0] stable_count;

    logic       last_grid_valid;
    logic [3:0] last_grid_id;

    // Check the frame grid result at the end of VSYNC.
    assign frame_sample = frame_sync_d & ~i_frame_sync;

    always_ff @(posedge i_pclk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            frame_sync_d <= 1'b0;

            candidate_valid   <= 1'b0;
            candidate_grid_id <= 4'd0;
            stable_count      <= '0;

            last_grid_valid <= 1'b0;
            last_grid_id    <= 4'd0;

            o_stable_valid    <= 1'b0;
            o_stable_grid_id  <= 4'd0;
            o_grid_enter_pulse <= 1'b0;
        end else begin
            frame_sync_d <= i_frame_sync;

            // The grid-entry pulse lasts one cycle.
            o_grid_enter_pulse <= 1'b0;

            // Clear the previous grid when a new pattern starts.
            if (i_clear) begin
                candidate_valid   <= 1'b0;
                candidate_grid_id <= 4'd0;
                stable_count      <= '0;

                last_grid_valid <= 1'b0;
                last_grid_id    <= 4'd0;

                o_stable_valid   <= 1'b0;
                o_stable_grid_id <= 4'd0;
            end else if (frame_sample) begin
                // No grid detected
                if (!i_grid_valid ||
                    (i_grid_id < 4'd1) ||
                    (i_grid_id > 4'd9)) begin

                    candidate_valid   <= 1'b0;
                    candidate_grid_id <= 4'd0;
                    stable_count      <= '0;

                    o_stable_valid   <= 1'b0;
                    o_stable_grid_id <= 4'd0;
                end

                // New grid candidate
                else if (!candidate_valid ||
                         (i_grid_id != candidate_grid_id)) begin

                    candidate_valid   <= 1'b1;
                    candidate_grid_id <= i_grid_id;
                    stable_count      <= 1;

                    o_stable_valid   <= 1'b0;
                    o_stable_grid_id <= 4'd0;

                    // Confirm immediately when one frame is enough.
                    if (STABLE_FRAMES <= 1) begin
                        o_stable_valid   <= 1'b1;
                        o_stable_grid_id <= i_grid_id;

                        if (!last_grid_valid ||
                            (i_grid_id != last_grid_id)) begin

                            o_grid_enter_pulse <= 1'b1;
                            last_grid_valid    <= 1'b1;
                            last_grid_id       <= i_grid_id;
                        end
                    end
                end

                // Same grid as the previous frame
                else begin
                    if (stable_count < STABLE_FRAMES)
                        stable_count <= stable_count + 1'b1;

                    // Confirm after the required number of frames.
                    if (stable_count >= STABLE_FRAMES - 1) begin
                        o_stable_valid   <= 1'b1;
                        o_stable_grid_id <= candidate_grid_id;

                        // Do not pulse again for the same grid.
                        if (!last_grid_valid ||
                            (candidate_grid_id != last_grid_id)) begin

                            o_grid_enter_pulse <= 1'b1;
                            last_grid_valid    <= 1'b1;
                            last_grid_id       <= candidate_grid_id;
                        end
                    end else begin
                        o_stable_valid   <= 1'b0;
                        o_stable_grid_id <= 4'd0;
                    end
                end
            end
        end
    end

endmodule
