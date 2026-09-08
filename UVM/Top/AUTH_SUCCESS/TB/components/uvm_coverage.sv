// SCCB transfer coverage.
covergroup sccb_cg_t with function sample(
    int unsigned sccb_index,
    bit          sccb_order_match,
    bit          repeated_register,
    bit          sccb_ack_error,
    bit          sccb_is_read
);
    option.per_instance = 1;

    cp_index : coverpoint sccb_index {
        bins all_entries[] = {[0:66]};
        illegal_bins outside = default;
    }

    cp_order_match : coverpoint sccb_order_match {
        bins match = {1'b1};
        illegal_bins mismatch = {1'b0};
    }

    cp_repeated_register : coverpoint repeated_register;

    cp_ack : coverpoint sccb_ack_error {
        bins ack_ok = {1'b0};
        illegal_bins ack_error = {1'b1};
    }

    cp_direction : coverpoint sccb_is_read {
        bins write = {1'b0};
        ignore_bins read = {1'b1};
    }

endgroup

// Cover each internal setup entry and its reference match.
// This complements bus coverage by observing the values driving the transfer.
covergroup internal_sccb_cg_t with function sample(int unsigned idx,
                                                    bit match);
    option.per_instance = 1;
    cp_index: coverpoint idx {
        bins entries[] = {[0:66]};
        illegal_bins outside = default;
    }
    cp_match: coverpoint match {
        bins pass={1'b1};
        illegal_bins fail={1'b0};
    }
    index_by_match: cross cp_index, cp_match;
endgroup


// Authentication, zoom, and effect switch values and combinations.
covergroup control_cg_t with function sample(
    bit auth_sw,
    bit zoom_en,
    bit effect_en
);
    option.per_instance = 1;

    cp_auth : coverpoint auth_sw {
        bins off = {1'b0};
        bins on  = {1'b1};
    }
    cp_zoom : coverpoint zoom_en {
        bins off = {1'b0};
        bins on  = {1'b1};
    }
    cp_effect : coverpoint effect_en {
        bins off = {1'b0};
        bins on  = {1'b1};
    }

    switch_combinations :
        cross cp_auth, cp_zoom, cp_effect;

endgroup


// Camera frame coverage.
covergroup camera_cg_t with function sample(
    bit          camera_frame_valid,
    int unsigned camera_pixel_count
);
    option.per_instance = 1;

    cp_valid : coverpoint camera_frame_valid {
        bins valid = {1'b1};
        illegal_bins invalid = {1'b0};
    }

    cp_pixels : coverpoint camera_pixel_count {
        bins full_frame = {320 * 240};
        illegal_bins other = default;
    }

endgroup


// Collect coverage from observed transactions.
class Coverage extends uvm_subscriber #(transaction);

    `uvm_component_utils(Coverage)

    transaction tr;

    bit    control_enable = 1'b1;
    string test_mode;
    string internal_sccb_path;

    logic [15:0] sccb_reference [0:66];

    bit register_seen [0:255];
    bit repeated_register;


    sccb_cg_t    sccb_cg;
    control_cg_t control_cg;
    camera_cg_t  camera_cg;
    internal_sccb_cg_t internal_sccb_cg;


    function new(
        string name = "Coverage",
        uvm_component parent = null
    );
        super.new(name, parent);
    endfunction


    virtual function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        void'(
            uvm_config_db#(string)::get(
                this,
                "",
                "test_mode",
                test_mode
            )
        );

        void'(
            uvm_config_db#(bit)::get(
                this,
                "",
                "control_enable",
                control_enable
            )
        );


        // Collect SCCB coverage in every test mode.
        sccb_cg = new();
        internal_sccb_cg = new();
        if (!uvm_config_db#(string)::get(this,"","internal_sccb_path",
                                         internal_sccb_path))
            `uvm_fatal("COV_HDL","Missing internal SCCB hierarchy path")


        // Skip general control and camera covergroups in authentication-only tests.
        // They send no camera frames; AuthCoverage handles their control scenarios.
        if ((test_mode == "AUTH_SUCCESS") ||
            (test_mode == "AUTH_LOCKOUT")) begin

            control_enable = 1'b0;

            control_cg = null;
            camera_cg  = null;

        end
        else begin

            control_cg = new();
            camera_cg  = new();

        end


        // Load the SCCB reference data.
        $readmemh(
            "../TB/ref/ov7670_67.hex",
            sccb_reference
        );


        // Clear the register observation history.
        foreach (register_seen[i]) begin
            register_seen[i] = 1'b0;
        end

    endfunction


    virtual function void write(transaction t);

        tr = t;


        // Sample SCCB write results.
        if (tr.mode == SCCB_WRITE) begin

            tr.sccb_order_match =
                (tr.sccb_index < 67) &&
                (
                    {
                        tr.sccb_register_addr,
                        tr.sccb_write_data
                    }
                    ===
                    sccb_reference[tr.sccb_index]
                );


            repeated_register =
                register_seen[tr.sccb_register_addr];

            register_seen[tr.sccb_register_addr] = 1'b1;


            sccb_cg.sample(
                tr.sccb_index,
                tr.sccb_order_match,
                repeated_register,
                tr.sccb_ack_error,
                tr.sccb_is_read
            );

            begin
                uvm_hdl_data_t idx_value, dev_value, reg_value, data_value;
                int unsigned internal_idx;
                bit internal_match;
                internal_match =
                    uvm_hdl_read({internal_sccb_path,".config_idx"},idx_value) &&
                    uvm_hdl_read({internal_sccb_path,".dev_addr"},dev_value) &&
                    uvm_hdl_read({internal_sccb_path,".reg_addr"},reg_value) &&
                    uvm_hdl_read({internal_sccb_path,".reg_data"},data_value);
                internal_idx = int'(idx_value);
                internal_match &= (internal_idx == tr.sccb_index) &&
                    (internal_idx < 67) && (dev_value[7:0] === 8'h42) &&
                    ({reg_value[7:0],data_value[7:0]} ===
                     sccb_reference[internal_idx]);
                internal_sccb_cg.sample(internal_idx,internal_match);
            end

        end


        // Sample switch settings.
        else if ((tr.mode == SWITCH_SET) &&
                 control_enable &&
                 (control_cg != null)) begin

            control_cg.sample(
                tr.auth_sw,
                tr.zoom_en,
                tr.effect_en
            );

        end


        // Sample camera frame results.
        else if ((tr.mode == CAMERA_FRAME) &&
                 (camera_cg != null)) begin

            camera_cg.sample(
                tr.camera_frame_valid,
                tr.camera_pixel_count
            );

        end

    endfunction


    // Report collected coverage.
    virtual function void report_phase(uvm_phase phase);

        super.report_phase(phase);


        if ((control_cg != null) &&
            (camera_cg  != null)) begin

            `uvm_info(
                "COVERAGE",
                $sformatf(
                    {
                        "SCCB coverage=%0.2f%% ",
                        "control coverage=%0.2f%% ",
                        "camera coverage=%0.2f%%"
                    },
                    sccb_cg.get_inst_coverage(),
                    control_cg.get_inst_coverage(),
                    camera_cg.get_inst_coverage()
                ),
                UVM_LOW
            )

        end
        else begin

            `uvm_info(
                "COVERAGE",
                $sformatf(
                    {
                        "SCCB coverage=%0.2f%% ",
                        "(AUTH camera/control groups waived)"
                    },
                    sccb_cg.get_inst_coverage()
                ),
                UVM_LOW
            )

        end

    endfunction

endclass
