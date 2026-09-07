`timescale 1ns / 1ps

// =================================================================================
// Module: pixel_counter
// Description: Tracks horizontal (h_count) and vertical (v_count) pixel locations
//              for VGA display timing driven by pixel clock tick enable (pclk).
// Parameters:
//   - Horizontal Max (H_MAX): 800 pixels (0 to 799)
//   - Vertical Max   (V_MAX): 525 lines  (0 to 524)
// =================================================================================

module pixel_counter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        pclk,      // Pixel clock enable pulse

    output logic [9:0]  h_count,   // Horizontal pixel index (0 ~ 799)
    output logic [9:0]  v_count    // Vertical line index    (0 ~ 524)
);

    localparam int H_MAX = 800;
    localparam int V_MAX = 525;

    // Horizontal Pixel Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 10'd0;
        end else if (pclk) begin
            if (h_count == H_MAX - 1) begin
                h_count <= 10'd0;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // Vertical Line Counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_count <= 10'd0;
        end else if (pclk) begin
            if (h_count == H_MAX - 1) begin
                if (v_count == V_MAX - 1) begin
                    v_count <= 10'd0;
                end else begin
                    v_count <= v_count + 1'b1;
                end
            end
        end
    end

endmodule
